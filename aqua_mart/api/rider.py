"""Rider endpoints (API_SPEC 7).

The simplest app and the most operationally sensitive - used one-handed on
a motorbike, often on poor signal. Which is why /complete is idempotent:
riders lose signal and retap, and a double-count of cash is a real loss.
"""

import re

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services import order_state, realtime
from aqua_mart.services.guard import (
	aqua_endpoint,
	current_user,
	request_body,
	require_approved_rider,
)
from aqua_mart.services.notifications import notify, notify_order_status
from aqua_mart.services.response import conflict, invalid, no_content, not_found, ok
from aqua_mart.services.runs import recompute_stops_before, today_run
from aqua_mart.services.serializers import serialize_invitation, serialize_run


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_RIDER)
def run(**kwargs):
	"""GET /rider/run

	If there is no run today, return a run with an EMPTY stops array -
	never a 404 (7.1).
	"""
	rider_name = require_approved_rider()
	doc = today_run(rider_name, create=True)
	return ok(serialize_run(doc))


def _own_stop(rider_name, stop_id):
	"""A rider may complete a stop only if it is on TODAY'S OWN run (2)."""
	stop = frappe.db.get_value("Aqua Run Stop", stop_id, ["name", "run"], as_dict=True)
	if not stop:
		not_found("We could not find that stop.")

	run_row = frappe.db.get_value(
		"Aqua Run", stop.run, ["name", "rider", "run_date"], as_dict=True
	)
	if not run_row or run_row.rider != rider_name:
		not_found("We could not find that stop.")

	if frappe.utils.getdate(run_row.run_date) != frappe.utils.getdate():
		conflict("That stop is not on today's run.", code="stale_run")

	return frappe.get_doc("Aqua Run Stop", stop_id)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_RIDER)
def complete_stop(id=None, **kwargs):
	"""POST /rider/stops/{id}/complete - returns the ENTIRE updated run.

	Idempotent: a second call on an already-delivered stop returns the run
	unchanged with 200, and does NOT double-count the cash (7.2).
	"""
	rider_name = require_approved_rider()
	stop = _own_stop(rider_name, id)

	if stop.status == C.DELIVERED:
		return ok(serialize_run(stop.run))
	if stop.status == "failed":
		conflict("This stop was already marked as failed.", code="stop_failed")

	order = frappe.get_doc("Aqua Order", stop.order)

	# All of this is one transaction - a partial completion would leave the
	# rider's cash and the customer's order disagreeing.
	stop.status = C.DELIVERED
	stop.completed_at = frappe.utils.now_datetime()
	stop.save(ignore_permissions=True)

	if order.status != C.DELIVERED:
		order_state.transition(order, C.DELIVERED, C.ROLE_RIDER, actor=current_user())

	# Cash orders add to the rider's cash-in-hand.
	if int(stop.amount_to_collect or 0):
		frappe.db.sql(
			"""update `tabAqua Rider Profile`
			   set cash_in_hand = cash_in_hand + %s where name = %s""",
			(int(stop.amount_to_collect), rider_name),
		)

	from aqua_mart.services.empties import collect_holdings, record_empties_for_order

	record_empties_for_order(order)
	if int(stop.empties_to_collect or 0):
		collect_holdings(order.customer, order.seller)

	run_doc = frappe.get_doc("Aqua Run", stop.run)
	recompute_stops_before(run_doc.name)

	realtime.emit_order_status(order)
	realtime.emit_run_updated(run_doc)
	realtime.emit_seller_dashboard(order.seller)
	notify_order_status(order, actor=current_user())

	_finish_run_if_done(run_doc)

	return ok(serialize_run(run_doc))


def _finish_run_if_done(run_doc):
	"""Close the run once nothing is pending, and free the rider."""
	pending = frappe.db.count("Aqua Run Stop", {"run": run_doc.name, "status": C.PENDING})
	if pending:
		return

	run_doc.finished_at = frappe.utils.now_datetime()
	run_doc.save(ignore_permissions=True)
	frappe.db.set_value("Aqua Rider Profile", run_doc.rider, "status", "idle")


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_RIDER)
def fail_stop(id=None, **kwargs):
	"""POST /rider/stops/{id}/fail

	The ORDER does not become terminal - it returns to the seller to
	reschedule or refund. No cash is counted (7.3).
	"""
	rider_name = require_approved_rider()
	stop = _own_stop(rider_name, id)
	body = request_body()

	if stop.status != C.PENDING:
		conflict("This stop has already been closed.", code="stop_closed")

	stop.status = "failed"
	stop.failure_reason = body.get("reason")
	stop.completed_at = frappe.utils.now_datetime()
	stop.save(ignore_permissions=True)

	order = frappe.get_doc("Aqua Order", stop.order)
	run_doc = frappe.get_doc("Aqua Run", stop.run)
	recompute_stops_before(run_doc.name)

	# Notify BOTH the customer and the seller (7.3).
	notify(
		order.customer,
		"orderUpdate",
		"We could not deliver your order",
		stop.failure_reason or "The rider could not complete this delivery.",
		f"/customer/order/{order.name}/track",
		actor=current_user(),
	)
	seller_user = frappe.db.get_value("Aqua Seller Profile", order.seller, "user")
	notify(
		seller_user,
		"orderUpdate",
		"Delivery failed",
		f"{order.reference} · {stop.failure_reason or 'no reason given'}",
		"/seller/orders",
		actor=current_user(),
	)

	realtime.emit_run_updated(run_doc)
	_finish_run_if_done(run_doc)

	return ok(serialize_run(run_doc))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_RIDER)
def cash_handover(**kwargs):
	"""POST /rider/cash-handover

	Reconciled against what the run actually collected; a short handover is
	flagged to the seller rather than silently accepted (7.4).
	"""
	rider_name = require_approved_rider()
	body = request_body()

	try:
		amount = int(body.get("amount") or 0)
	except (TypeError, ValueError):
		invalid({"amount": "Enter the amount you handed over."})

	rider = frappe.get_doc("Aqua Rider Profile", rider_name)
	expected = int(rider.cash_in_hand or 0)

	rider.cash_in_hand = 0
	rider.save(ignore_permissions=True)

	if amount != expected:
		seller_user = frappe.db.get_value("Aqua Seller Profile", rider.seller, "user")
		difference = expected - amount
		notify(
			seller_user,
			"payout",
			"Cash handover does not match",
			f"{rider.full_name} handed over Rs {amount}; Rs {expected} was expected "
			f"({'short' if difference > 0 else 'over'} by Rs {abs(difference)}).",
			"/seller/riders",
			actor=current_user(),
		)

	return no_content()


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_RIDER)
def earnings(**kwargs):
	"""GET /rider/earnings

	`per_day` is Monday-first with SEVEN entries - a wrong-length array
	silently misreports the rider's week (7.4).
	"""
	rider_name = require_approved_rider()
	rider = frappe.get_doc("Aqua Rider Profile", rider_name)

	today = frappe.utils.get_datetime(frappe.utils.nowdate())
	monday = frappe.utils.add_days(today, -today.weekday())

	per_day = []
	for offset in range(7):
		day = frappe.utils.add_days(monday, offset)
		per_day.append(
			frappe.db.count(
				"Aqua Run Stop",
				{
					"status": C.DELIVERED,
					"completed_at": ["between", [f"{day} 00:00:00", f"{day} 23:59:59"]],
					"run": [
						"in",
						frappe.get_all("Aqua Run", filters={"rider": rider_name}, pluck="name")
						or [""],
					],
				},
			)
		)

	deliveries = frappe.db.count(
		"Aqua Order", {"rider": rider_name, "status": C.DELIVERED}
	)

	return ok(
		{
			"deliveries": deliveries,
			"per_delivery": int(rider.per_delivery or 0),
			"on_time_bonus": int(rider.on_time_bonus or 0),
			# Money already drawn, hence subtracted by the client.
			"fuel_advance": int(rider.fuel_advance or 0),
			"rating": round(float(rider.rating or 0), 1),
			"rating_count": int(rider.rating_count or 0),
			"per_day": per_day,
			"is_top_rider": float(rider.rating or 0) >= 4.8,
		}
	)


# --- 7.5 onboarding -------------------------------------------------------


@frappe.whitelist(allow_guest=True)
@aqua_endpoint()
def seller_code(code=None, **kwargs):
	"""GET /rider/seller-codes/{code}

	An unknown code returns {"data": null} with 200, NOT 404 - the client
	shows an inline hint rather than an error screen (7.5).

	Unauthenticated and an obvious enumeration target, so it is rate
	limited to 10 attempts per device per hour.
	"""
	_rate_limit_code_lookup()

	row = frappe.db.get_value(
		"Aqua Rider Invite Code", {"code": (code or "").upper(), "active": 1}, "seller"
	)
	if not row:
		return ok(None)

	seller = frappe.get_doc("Aqua Seller Profile", row)
	rider_count = frappe.db.count(
		"Aqua Rider Profile", {"seller": seller.name, "approval_status": C.APPROVED}
	)

	return ok(
		{
			"seller_name": seller.business_name,
			"area": seller.areas[0].area if seller.areas else None,
			"rider_count": rider_count,
			"joined_year": frappe.utils.get_datetime(seller.creation).year,
		}
	)


def _rate_limit_code_lookup(limit=10, window=3600):
	from aqua_mart.services.response import throttled

	ip = frappe.local.request_ip or "unknown"
	key = f"aqua:code-lookup:{ip}"
	cache = frappe.cache()

	count = cache.get_value(key) or 0
	if int(count) >= limit:
		throttled("Too many tries. Please wait a while.", code="lookup_throttled")

	cache.set_value(key, int(count) + 1, expires_in_sec=window)


@frappe.whitelist()
@aqua_endpoint()
def application(**kwargs):
	"""POST /rider/application - a rider joins BY a seller's invite code."""
	user = current_user()
	body = request_body()

	errors = {}
	full_name = (body.get("full_name") or "").strip()
	if not full_name:
		errors["full_name"] = "Enter your full name."

	# CNIC is 13 digits, conventionally #####-#######-#. Validate on digits.
	cnic_digits = re.sub(r"\D", "", body.get("cnic") or "")
	if len(cnic_digits) != 13:
		errors["cnic"] = "CNIC must be 13 digits."

	vehicle = body.get("vehicle")
	if vehicle not in C.VEHICLES:
		errors["vehicle"] = "Choose your vehicle."

	registration = (body.get("registration_number") or "").strip()
	# Required for every vehicle EXCEPT onFoot.
	if vehicle != "onFoot" and not registration:
		errors["registration_number"] = "Enter the registration number."

	seller_code_value = (body.get("seller_code") or "").upper().strip()
	seller_name = frappe.db.get_value(
		"Aqua Rider Invite Code", {"code": seller_code_value, "active": 1}, "seller"
	)
	if not seller_name:
		errors["seller_code"] = "We do not recognise that code."

	if errors:
		invalid(errors)

	phone = frappe.db.get_value("Aqua Profile", {"user": user}, "phone")

	existing = frappe.db.get_value("Aqua Rider Profile", {"user": user}, "name")
	values = {
		"full_name": full_name,
		"seller": seller_name,
		"cnic": cnic_digits,
		"phone": phone,
		"vehicle": vehicle,
		"registration_number": registration or None,
		"approval_status": C.IN_REVIEW,
		"status": "offDuty",
	}

	if existing:
		doc = frappe.get_doc("Aqua Rider Profile", existing)
		doc.update(values)
		doc.save(ignore_permissions=True)
	else:
		doc = frappe.get_doc({"doctype": "Aqua Rider Profile", "user": user, **values}).insert(
			ignore_permissions=True
		)

	frappe.db.set_value("Aqua Profile", {"user": user}, "role", C.ROLE_RIDER)

	seller_user = frappe.db.get_value("Aqua Seller Profile", seller_name, "user")
	notify(
		seller_user,
		"riderRun",
		"A rider wants to join",
		f"{full_name} applied with your code.",
		"/seller/riders",
		actor=user,
	)

	return ok({"id": doc.name, "approval_status": doc.approval_status}, status=201)


@frappe.whitelist()
@aqua_endpoint()
def invitations(**kwargs):
	"""GET /rider/invitations - a list; the client uses the FIRST element."""
	user = current_user()
	phone = frappe.db.get_value("Aqua Profile", {"user": user}, "phone")

	names = frappe.get_all(
		"Aqua Rider Invitation",
		filters={"sent_to": phone, "status": "pending"},
		order_by="creation desc",
		pluck="name",
	)
	# Empty array when there's nothing pending - never an error.
	return ok([serialize_invitation(name) for name in names])


@frappe.whitelist()
@aqua_endpoint()
def respond_invitation(id=None, **kwargs):
	"""POST /rider/invitations/{id} - {"accept": true|false}"""
	user = current_user()
	body = request_body()
	phone = frappe.db.get_value("Aqua Profile", {"user": user}, "phone")

	invitation = frappe.db.get_value(
		"Aqua Rider Invitation", id, ["name", "sent_to", "seller", "status"], as_dict=True
	)
	if not invitation or invitation.sent_to != phone:
		not_found("We could not find that invitation.")
	if invitation.status != "pending":
		conflict("You have already responded to this invitation.", code="already_answered")

	accept = bool(body.get("accept"))
	frappe.db.set_value(
		"Aqua Rider Invitation", invitation.name, "status", "accepted" if accept else "declined"
	)

	if accept:
		# Accepting attaches the rider and puts them in the seller's list as idle.
		existing = frappe.db.get_value("Aqua Rider Profile", {"user": user}, "name")
		full_name = frappe.db.get_value("Aqua Profile", {"user": user}, "full_name")
		values = {
			"seller": invitation.seller,
			"approval_status": C.APPROVED,
			"status": "idle",
		}
		if existing:
			frappe.db.set_value("Aqua Rider Profile", existing, values)
		else:
			frappe.get_doc(
				{
					"doctype": "Aqua Rider Profile",
					"user": user,
					"full_name": full_name,
					"phone": phone,
					**values,
				}
			).insert(ignore_permissions=True)

		frappe.db.set_value("Aqua Profile", {"user": user}, "role", C.ROLE_RIDER)

	return no_content()
