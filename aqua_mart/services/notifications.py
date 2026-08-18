"""In-app feed + FCM push (API_SPEC 5.6, 9).

One helper, `notify()`, writes the Aqua Notification row, emits it over the
socket and queues the push. Call sites never do two of the three and forget
the third.

Two rules from 9.3 are enforced here rather than at call sites:
* never push a status change to the person who caused it
* `kind` and `deep_link` use exactly the values in 5.6
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.realtime import emit_notification


def notify(user, kind, title, body=None, deep_link=None, actor=None, push=True):
	"""Write, emit and push one notification.

	:param actor: the user who caused this. If they are the recipient, the
	        notification is skipped entirely - nobody wants a push telling
	        them what they just did (9.3).
	"""
	if not user or user == "Guest":
		return None
	if actor and actor == user:
		return None
	if kind not in C.NOTIFICATION_KINDS:
		frappe.log_error(f"Unknown notification kind: {kind}", "Aqua Mart")
		return None

	doc = frappe.get_doc(
		{
			"doctype": "Aqua Notification",
			"user": user,
			"kind": kind,
			"title": title,
			"body": body,
			"deep_link": deep_link,
			"is_read": 0,
		}
	).insert(ignore_permissions=True)

	emit_notification(doc)

	if push:
		frappe.enqueue(
			"aqua_mart.services.notifications.send_push",
			queue="short",
			enqueue_after_commit=True,
			user=user,
			kind=kind,
			title=title,
			body=body,
			deep_link=deep_link,
			notification_id=doc.name,
		)

	return doc


def send_push(user, kind, title, body, deep_link, notification_id):
	"""Deliver a DATA message to every device this user has registered (9.2).

	Data messages, not notification messages, so the app controls
	presentation and the tap routes correctly in every app state.

	The actual FCM transport is deliberately pluggable: set `aqua_fcm_key`
	(legacy) or wire a service-account sender in site config. Without
	credentials this no-ops rather than raising - a missing push must never
	fail the request that triggered it.
	"""
	tokens = frappe.get_all(
		"Aqua Device", filters={"user": user}, pluck="fcm_token"
	)
	if not tokens:
		return

	payload = {
		"data": {
			"kind": kind,
			"title": title,
			"body": body or "",
			"deep_link": deep_link or "",
			"notification_id": notification_id,
		},
		"android": {"priority": "high"},
		"apns": {"headers": {"apns-priority": "10"}},
	}

	sender = frappe.get_hooks("aqua_push_sender")
	if sender:
		frappe.get_attr(sender[-1])(tokens, payload)
		return

	server_key = frappe.conf.get("aqua_fcm_key")
	if not server_key:
		# No credentials configured yet - the in-app feed and socket still work.
		return

	import json

	import requests

	for token in tokens:
		try:
			requests.post(
				"https://fcm.googleapis.com/fcm/send",
				headers={
					"Authorization": f"key={server_key}",
					"Content-Type": "application/json",
				},
				data=json.dumps({"to": token, **payload}),
				timeout=10,
			)
		except Exception:
			frappe.log_error(title="Aqua Mart push failed")


# --- ready-made notifications for the events that matter ------------------


def notify_order_status(order, actor=None):
	"""Customer-facing order updates. Only the steps worth a buzz (9.3)."""
	messages = {
		C.ACCEPTED: ("Order confirmed", f"{order.seller_name} is preparing your order."),
		C.ON_THE_WAY: (
			f"{order.rider_name or 'Your rider'} is on the way",
			_on_the_way_body(order),
		),
		C.DELIVERED: ("Delivered", "Tap to rate your order."),
		C.REJECTED_BY_SELLER: (
			"Seller could not take this order",
			order.rejection_reason or "Please try another seller.",
		),
	}
	if order.status not in messages:
		return

	title, body = messages[order.status]
	kind = "riderOnTheWay" if order.status == C.ON_THE_WAY else "orderUpdate"
	link = (
		f"/customer/order/{order.name}/rate"
		if order.status == C.DELIVERED
		else f"/customer/order/{order.name}/track"
	)

	notify(order.customer, kind, title, body, link, actor=actor)


def _on_the_way_body(order):
	from aqua_mart.services.serializers import stops_before

	before = stops_before(order)
	parts = []
	if before:
		parts.append(f"{before} stops before you")
	if order.payment_method == "cash":
		total = sum(int(l.unit_price) * int(l.quantity) for l in order.lines)
		parts.append(f"Rs {total + int(order.delivery_fee or 0)} cash ready")
	return " · ".join(parts) or "Your order is on its way."


def notify_seller_new_order(order):
	"""The most important notification in the product (9.3).

	A missed order is lost revenue and a customer who waited for nothing.
	"""
	seller_user = frappe.db.get_value("Aqua Seller Profile", order.seller, "user")
	notify(
		seller_user,
		"orderUpdate",
		"New order",
		f"{order.reference} · {order.customer_name or 'A customer'}",
		"/seller/orders",
		actor=order.customer,
	)
