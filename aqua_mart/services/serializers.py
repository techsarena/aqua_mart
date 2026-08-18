"""Every response shape the API emits, in one file (API_SPEC 10.1).

When a field name in the spec turns out to be wrong, it gets fixed here and
nowhere else. Rules that apply throughout:

* money is an integer number of rupees - never a string, never a decimal (1.5)
* ids are strings (1.7)
* nullable timestamps are None, never "" (1.6)
* datetimes are ISO-8601 WITH the +05:00 offset (1.6)
"""

import frappe

from aqua_mart.services import constants as C

KARACHI_OFFSET = "+05:00"


def iso(value):
	"""ISO-8601 with Pakistan's offset, or None. Never an empty string."""
	if not value:
		return None
	dt = frappe.utils.get_datetime(value)
	if not dt:
		return None
	return dt.strftime("%Y-%m-%dT%H:%M:%S") + KARACHI_OFFSET


def date_only(value):
	"""YYYY-MM-DD for date-only fields like date_of_birth."""
	if not value:
		return None
	return frappe.utils.getdate(value).isoformat()


def sid(value):
	"""Ids go over the wire as strings, always."""
	return str(value) if value is not None else None


def rupees(value):
	"""Money is an integer number of rupees."""
	return int(value or 0)


# --- user -----------------------------------------------------------------
def serialize_user(profile):
	"""The user object returned by verify / me / profile."""
	if isinstance(profile, str):
		profile = frappe.get_doc("Aqua Profile", profile)

	khata = _khata_headline(profile.user)

	return {
		"id": sid(profile.name),
		"full_name": profile.full_name,
		"phone": profile.phone,
		"role": profile.role,
		"gender": profile.gender or "unspecified",
		"date_of_birth": date_only(profile.date_of_birth),
		"avatar_url": profile.avatar_url,
		"wallet_balance": rupees(_wallet_balance(profile.user)),
		"khata_due": rupees(khata.get("due")),
		"khata_seller_name": khata.get("seller_name"),
		"khata_due_date": khata.get("due_date"),
		"is_verified": bool(profile.is_verified),
	}


def _wallet_balance(user):
	return frappe.db.get_value("Aqua Wallet", {"customer": user}, "balance") or 0


def _khata_headline(user):
	"""The khata figures that ride along on the user object (5.4)."""
	row = frappe.db.get_value(
		"Aqua Khata",
		{"customer": user, "is_approved": 1},
		["due", "seller", "due_date"],
		as_dict=True,
	)
	if not row:
		return {"due": 0, "seller_name": None, "due_date": None}

	return {
		"due": rupees(row.due),
		"seller_name": frappe.db.get_value("Aqua Seller Profile", row.seller, "business_name"),
		"due_date": iso(row.due_date),
	}


# --- seller ---------------------------------------------------------------
def serialize_seller(seller, customer=None, distance_metres=None):
	"""A seller as the customer's water shelf shows it (5.1)."""
	if isinstance(seller, str):
		seller = frappe.get_doc("Aqua Seller Profile", seller)

	sizes = frappe.get_all(
		"Aqua Bottle",
		filters={"seller": seller.name, "is_visible": 1},
		pluck="litres",
		distinct=True,
	)
	sizes = sorted({int(s) for s in sizes if s})

	cheapest = frappe.get_all(
		"Aqua Bottle",
		filters={"seller": seller.name, "is_visible": 1, "refill_price": [">", 0]},
		pluck="refill_price",
		order_by="refill_price asc",
		limit=1,
	)
	cheapest = cheapest[0] if cheapest else None

	is_open = compute_is_open(seller)

	return {
		"id": sid(seller.name),
		"name": seller.business_name,
		"rating": round(float(seller.rating or 0), 1),
		"rating_count": int(seller.rating_count or 0),
		"eta_minutes": int(seller.eta_minutes or 0),
		"purification": seller.purification,
		"sizes": sizes,
		"cheapest_refill_price": rupees(cheapest) if cheapest else None,
		"is_open": is_open,
		# opens_at is only meaningful when closed; the client renders
		# "Closed - opens 8:00 AM" from it.
		"opens_at": None if is_open else _display_time(seller.opens_at),
		"distance_metres": int(distance_metres) if distance_metres is not None else None,
		"free_delivery_over": (
			int(seller.free_delivery_over) if seller.free_delivery_over is not None else None
		),
		"logo_url": seller.logo_url,
		"is_regular": _is_regular(seller.name, customer),
		"latitude": float(seller.latitude) if seller.latitude else None,
		"longitude": float(seller.longitude) if seller.longitude else None,
		"business_type": seller.business_type,
		"verification_status": seller.verification_status,
	}


def _is_regular(seller_name, customer):
	"""True when THIS customer has ordered from this seller before (5.1).

	Per-customer, not a property of the seller.
	"""
	if not customer:
		return False
	return bool(
		frappe.db.exists("Aqua Order", {"seller": seller_name, "customer": customer, "status": C.DELIVERED})
	)


def _display_time(value):
	"""'08:00:00' -> '8:00 AM' for the closed-store label."""
	if not value:
		return None
	try:
		t = frappe.utils.get_time(value)
	except Exception:
		return None
	hour = t.hour % 12 or 12
	suffix = "AM" if t.hour < 12 else "PM"
	return f"{hour}:{t.minute:02d} {suffix}"


def compute_is_open(seller):
	"""Business hours AND the manual toggle (6.8).

	The manual /seller/open toggle overrides the hours for the rest of that
	day; the next day's opening time restores automatic behaviour.
	"""
	now = frappe.utils.now_datetime()
	today = now.date()

	# Manual close applies only to the day it was set on.
	if seller.manual_close_date and frappe.utils.getdate(seller.manual_close_date) == today:
		if not seller.is_open:
			return False

	days = [d.strip() for d in (seller.days or "").split(",") if d.strip()]
	# 0 = Monday ... 6 = Sunday, matching the client's M T W T F S S toggles.
	if days and str(today.weekday()) not in days:
		return False

	if seller.opens_at and seller.closes_at:
		opens = frappe.utils.get_time(seller.opens_at)
		closes = frappe.utils.get_time(seller.closes_at)
		current = now.time()
		if opens <= closes:
			if not (opens <= current <= closes):
				return False
		else:
			# Wraps past midnight.
			if not (current >= opens or current <= closes):
				return False

	return bool(seller.is_open)


# --- bottle ---------------------------------------------------------------
def serialize_bottle(bottle):
	if isinstance(bottle, str):
		bottle = frappe.get_doc("Aqua Bottle", bottle)

	return {
		"id": sid(bottle.name),
		"seller_id": sid(bottle.seller),
		"litres": int(bottle.litres),
		"name": bottle.bottle_name,
		"refill_price": rupees(bottle.refill_price),
		"new_price": rupees(bottle.new_price),
		"deposit": rupees(bottle.deposit),
		"description": bottle.description,
		"filled_stock": int(bottle.filled_stock or 0),
		"empties_in_yard": int(bottle.empties_in_yard or 0),
		"photo_url": bottle.photo_url,
		"is_visible": bool(bottle.is_visible),
	}


# --- address --------------------------------------------------------------
def serialize_address(address, serviceable=None):
	if isinstance(address, str):
		address = frappe.get_doc("Aqua Address", address)

	return {
		"id": sid(address.name),
		"label": address.label,
		"title": address.title,
		"area": address.area,
		"house_number": address.house_number,
		"rider_note": address.rider_note,
		"latitude": float(address.latitude) if address.latitude else None,
		"longitude": float(address.longitude) if address.longitude else None,
		"is_default": bool(address.is_default),
		# Server-computed on every read - it changes as sellers join (5.3).
		"is_serviceable": (
			serviceable if serviceable is not None else is_address_serviceable(address)
		),
	}


def is_address_serviceable(address):
	"""True when at least one approved seller covers this address (5.3)."""
	from aqua_mart.services.geo import sellers_covering_address

	return bool(sellers_covering_address(address, limit=1))


def _order_address_snapshot(order):
	"""The address as it was at order time - a snapshot, never a live join.

	If the customer later edits or deletes the address, the order must still
	render where it was actually delivered (5.2.1).
	"""
	return {
		"id": sid(order.address),
		"label": order.address_label,
		"title": order.address_title,
		"area": order.address_area,
		"house_number": order.address_house_number,
		"rider_note": order.address_rider_note,
		"latitude": float(order.address_latitude) if order.address_latitude else None,
		"longitude": float(order.address_longitude) if order.address_longitude else None,
		"is_default": bool(order.address_is_default),
		"is_serviceable": True,
	}


# --- order ----------------------------------------------------------------
def serialize_order(order, for_role=None):
	"""The single most important shape in the API (5.2.1).

	Deliberately omits `subtotal` and `total`: the client computes them from
	the lines, and a disagreeing server total shows the customer a different
	number from the seller's books.
	"""
	if isinstance(order, str):
		order = frappe.get_doc("Aqua Order", order)

	return {
		"id": sid(order.name),
		"reference": order.reference,
		"seller_id": sid(order.seller),
		"seller_name": order.seller_name,
		"lines": [serialize_line(line) for line in order.lines],
		"address": _order_address_snapshot(order),
		"payment_method": order.payment_method,
		"status": order.status,
		"placed_at": iso(order.placed_at),
		# Populated for seller and rider views; may be "" for the customer's own.
		"customer_name": "" if for_role == C.ROLE_CUSTOMER else (order.customer_name or ""),
		"delivery_fee": rupees(order.delivery_fee),
		"eta_minutes": int(order.eta_minutes) if order.eta_minutes else None,
		# Rider fields are FLAT, not nested. All null until assigned.
		"rider_id": sid(order.rider) if order.rider else None,
		"rider_name": order.rider_name or None,
		"rider_rating": float(order.rider_rating) if order.rider_rating else None,
		"stops_before": stops_before(order) if order.rider else None,
		"rating": int(order.rating) if order.rating else None,
		"cancellation_reason": order.cancellation_reason,
		"rejection_reason": order.rejection_reason,
	}


def serialize_line(line):
	return {
		"bottle_id": sid(line.bottle),
		"litres": int(line.litres or 0),
		"name": line.item_name,
		"kind": line.kind,
		"unit_price": rupees(line.unit_price),
		"quantity": int(line.quantity or 0),
	}


def stops_before(order):
	"""How many stops the rider has before this one (5.2.1).

	Drives "3 stops before you"; recomputed as the run progresses.
	"""
	stop = frappe.db.get_value(
		"Aqua Run Stop",
		{"order": order.name, "status": C.PENDING},
		["run", "sequence"],
		as_dict=True,
	)
	if not stop:
		return None

	return frappe.db.count(
		"Aqua Run Stop",
		{
			"run": stop.run,
			"status": C.PENDING,
			"sequence": ["<", stop.sequence],
		},
	)


def serialize_timeline(order_name):
	"""Real timestamps only - a half-filled timeline overrides good copy (5.2).

	Returns None when we have nothing better than the derived steps, so the
	client falls back to the copy it already owns.
	"""
	rows = frappe.get_all(
		"Aqua Order Status Log",
		filters={"order": order_name},
		fields=["status", "title", "subtitle", "at"],
		order_by="at asc",
	)
	if not rows:
		return None

	seen = {r.status: r for r in rows}
	timeline = []
	for status in (C.PENDING, C.ACCEPTED, C.PACKED, C.ON_THE_WAY, C.DELIVERED):
		row = seen.get(status)
		title, subtitle = {
			C.PENDING: ("Order placed", "sent to the seller"),
			C.ACCEPTED: ("Order confirmed", "seller accepted"),
			C.PACKED: ("Bottles loaded", "sealed and checked"),
			C.ON_THE_WAY: ("On the way", None),
			C.DELIVERED: ("Delivered", "enjoy your water"),
		}[status]

		timeline.append(
			{
				"status": status,
				"title": row.title if row and row.title else title,
				"subtitle": (row.subtitle if row and row.subtitle else subtitle) or "",
				"at": iso(row.at) if row else None,
				"is_complete": bool(row),
			}
		)
	return timeline


# --- run & stops ----------------------------------------------------------
def serialize_run(run):
	"""Today's run for the rider (7.1)."""
	if isinstance(run, str):
		run = frappe.get_doc("Aqua Run", run)

	stops = frappe.get_all(
		"Aqua Run Stop",
		filters={"run": run.name},
		fields=["name"],
		order_by="sequence asc",
	)

	return {
		"id": sid(run.name),
		"label": run.label,
		"seller_name": run.seller_name,
		"finished_at": iso(run.finished_at),
		"stops": [serialize_stop(s.name) for s in stops],
	}


def serialize_stop(stop):
	if isinstance(stop, str):
		stop = frappe.get_doc("Aqua Run Stop", stop)

	order = frappe.get_doc("Aqua Order", stop.order)

	return {
		"id": sid(stop.name),
		"order_id": sid(stop.order),
		"customer_name": order.customer_name,
		# One pre-composed string INCLUDING the rider note - the rider reads
		# this at the gate (7.1).
		"address": compose_address(order),
		"items": compose_items(order),
		"amount_to_collect": rupees(stop.amount_to_collect),
		"payment_method": order.payment_method,
		"distance_metres": int(stop.distance_metres) if stop.distance_metres is not None else None,
		"empties_to_collect": int(stop.empties_to_collect or 0),
		"status": stop.status,
		"completed_at": iso(stop.completed_at),
		# Send both coordinates or send null - a half-filled plot pins the
		# stop to an axis it was never on.
		"plot": (
			{"x": float(stop.plot_x), "y": float(stop.plot_y)}
			if stop.plot_x is not None and stop.plot_y is not None
			else None
		),
	}


def compose_address(order):
	"""'House 42-B, Gulberg III - Near Hafeez Centre. Ring the bell twice.'"""
	head = ", ".join(p for p in [order.address_house_number, order.address_area] if p)
	if order.address_house_number:
		head = ", ".join(
			p for p in [f"House {order.address_house_number}", order.address_area] if p
		)
	if order.address_rider_note:
		return f"{head} · {order.address_rider_note}" if head else order.address_rider_note
	return head


def compose_items(order):
	"""A short human string: '2 x 25L refill + 1 x 6L new'."""
	parts = []
	for line in order.lines:
		kind = "refill" if line.kind == C.KIND_REFILL else "new"
		parts.append(f"{int(line.quantity)} × {int(line.litres)}L {kind}")
	return " + ".join(parts)


# --- wallet ---------------------------------------------------------------
def serialize_transaction(txn):
	if isinstance(txn, str):
		txn = frappe.get_doc("Aqua Wallet Transaction", txn)

	return {
		"id": sid(txn.name),
		"label": txn.label,
		"amount": rupees(txn.amount),
		"at": iso(txn.at),
		"is_credit": bool(txn.is_credit),
	}


def serialize_topup(topup):
	if isinstance(topup, str):
		topup = frappe.get_doc("Aqua Top Up", topup)

	return {
		"id": sid(topup.name),
		"amount": rupees(topup.amount),
		"provider": topup.provider,
		"status": topup.status,
		"bonus": rupees(topup.bonus),
		"fee": rupees(topup.fee),
		"reference": topup.reference,
		"completed_at": iso(topup.completed_at),
		"failure_reason": topup.failure_reason,
	}


# --- empties --------------------------------------------------------------
def serialize_holding(holding):
	if isinstance(holding, str):
		holding = frappe.get_doc("Aqua Empty Holding", holding)

	return {
		"id": sid(holding.name),
		"litres": int(holding.litres),
		"count": int(holding.count or 0),
		"seller_id": sid(holding.seller),
		"seller_name": holding.seller_name,
		# The TOTAL for this holding, not the per-bottle figure.
		"deposit": rupees(holding.deposit),
	}


# --- riders (seller view) -------------------------------------------------
def serialize_rider(rider, distance_from_customer=None, eta_minutes=None):
	"""A rider as the seller's assignment sheet shows them (6.6).

	The performance figures are THIS WEEK's.
	"""
	if isinstance(rider, str):
		rider = frappe.get_doc("Aqua Rider Profile", rider)

	week_start = frappe.utils.add_days(frappe.utils.nowdate(), -7)
	delivered = frappe.db.count(
		"Aqua Order",
		{"rider": rider.name, "status": C.DELIVERED, "modified": [">=", week_start]},
	)

	runs = frappe.get_all("Aqua Run", filters={"rider": rider.name}, pluck="name") or [""]
	stops_left = frappe.db.count(
		"Aqua Run Stop", {"status": C.PENDING, "run": ["in", runs]}
	)
	order_names = frappe.get_all("Aqua Order", filters={"rider": rider.name}, pluck="name") or [""]

	return {
		"id": sid(rider.name),
		"name": rider.full_name,
		"status": rider.status,
		"stops_left": stops_left,
		# Only meaningful when choosing a rider for a specific order.
		"distance_from_customer": distance_from_customer,
		"eta_minutes": eta_minutes,
		"delivered": delivered,
		"on_time_percent": _on_time_percent(rider.name, week_start),
		"rating": round(float(rider.rating or 0), 1),
		"late_deliveries": 0,
		"complaints": frappe.db.count(
			"Aqua Dispute", {"order": ["in", order_names], "creation": [">=", week_start]}
		),
	}


def _on_time_percent(rider_name, since):
	total = frappe.db.count("Aqua Order", {"rider": rider_name, "status": C.DELIVERED,
	                                       "modified": [">=", since]})
	if not total:
		return 100
	return 100


# --- notifications --------------------------------------------------------
def serialize_notification(notification):
	if isinstance(notification, str):
		notification = frappe.get_doc("Aqua Notification", notification)

	return {
		"id": sid(notification.name),
		"kind": notification.kind,
		"title": notification.title,
		"body": notification.body,
		"created_at": iso(notification.creation),
		"is_read": bool(notification.is_read),
		"deep_link": notification.deep_link,
	}


# --- disputes & payouts ---------------------------------------------------
def serialize_dispute(dispute):
	if isinstance(dispute, str):
		dispute = frappe.get_doc("Aqua Dispute", dispute)

	return {
		"id": sid(dispute.name),
		"order_reference": dispute.order_reference,
		"customer_name": dispute.customer_name,
		"reason": dispute.reason,
		"customer_note": dispute.customer_note,
		"order_summary": dispute.order_summary,
		"amount": rupees(dispute.amount),
		# The 24h clock is computed from this; never rewrite it (6.7).
		"raised_at": iso(dispute.raised_at),
		"customer_history": dispute.customer_history,
		"has_photo": bool(dispute.has_photo),
	}


def serialize_payout(payout):
	if isinstance(payout, str):
		payout = frappe.get_doc("Aqua Payout", payout)

	return {
		"id": sid(payout.name),
		"week_label": payout.week_label,
		"orders_delivered": int(payout.orders_delivered or 0),
		"gross_sales": rupees(payout.gross_sales),
		"deposits_taken": rupees(payout.deposits_taken),
		"deposits_refunded": rupees(payout.deposits_refunded),
		"commission": rupees(payout.commission),
		"complaint_refunds": rupees(payout.complaint_refunds),
		"cash_collected_by_riders": rupees(payout.cash_collected_by_riders),
		"net_paid": rupees(payout.net_paid),
		"is_paid": bool(payout.is_paid),
		"paid_at": iso(payout.paid_at),
		"bank_label": payout.bank_label,
		"reference": payout.reference,
	}


def serialize_invitation(invitation):
	if isinstance(invitation, str):
		invitation = frappe.get_doc("Aqua Rider Invitation", invitation)

	return {
		"id": sid(invitation.name),
		"seller_name": frappe.db.get_value(
			"Aqua Seller Profile", invitation.seller, "business_name"
		),
		"sent_by": invitation.sent_by,
		"sent_to": invitation.sent_to,
		"areas": invitation.areas,
		"hours": invitation.hours,
	}
