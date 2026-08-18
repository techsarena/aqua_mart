"""Server-side socket room authorisation (API_SPEC 8.3, 8.5).

These are called by realtime/handlers.js over the socket's authenticated
HTTP channel. Every one re-derives the actor from the session - a payload
never decides what a socket may join.

They are throttled to what the socket layer needs and return plain values
(not the `data` envelope), because their caller is our own JS, not the app.
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.realtime import emit_rider_location, rider_room, seller_room


@frappe.whitelist()
def my_rooms():
	"""The rooms this identity is entitled to, joined server-side."""
	user = frappe.session.user
	if not user or user == "Guest":
		return []

	rooms = []

	seller = frappe.db.get_value(
		"Aqua Seller Profile", {"user": user}, ["name", "verification_status"], as_dict=True
	)
	if seller and seller.verification_status == C.APPROVED:
		rooms.append(seller_room(seller.name))

	rider = frappe.db.get_value(
		"Aqua Rider Profile", {"user": user}, ["name", "seller", "approval_status"], as_dict=True
	)
	if rider and rider.approval_status == C.APPROVED:
		rooms.append(rider_room(rider.name))
		# Riders also see their seller's queue changes (8.3).
		if rider.seller:
			rooms.append(seller_room(rider.seller))

	return rooms


@frappe.whitelist()
def can_watch_order(order_id=None):
	"""May the caller join order:{id}?

	The order's customer, its seller, and its assigned rider - nobody else.
	"""
	user = frappe.session.user
	if not user or user == "Guest" or not order_id:
		return False

	order = frappe.db.get_value(
		"Aqua Order", order_id, ["name", "customer", "seller", "rider"], as_dict=True
	)
	if not order:
		return False

	if order.customer == user:
		return True

	if order.seller and frappe.db.get_value("Aqua Seller Profile", order.seller, "user") == user:
		return True

	if order.rider and frappe.db.get_value("Aqua Rider Profile", order.rider, "user") == user:
		return True

	return False


@frappe.whitelist()
def rider_ping(latitude=None, longitude=None, heading=None):
	"""Fan a rider's position out to the orders they are actually carrying.

	Validated against an ACTIVE run: a rider not on a run is dropped.
	Rate-limited to one emit per 10 seconds per rider (8.4) - the client is
	supposed to respect that, but a buggy build should not be able to
	saturate every watcher's battery.
	"""
	user = frappe.session.user
	if not user or user == "Guest":
		return False

	rider = frappe.db.get_value(
		"Aqua Rider Profile", {"user": user}, ["name", "approval_status"], as_dict=True
	)
	if not rider or rider.approval_status != C.APPROVED:
		return False

	if latitude in (None, "") or longitude in (None, ""):
		return False

	# Must be on a run today that still has pending stops.
	run = frappe.db.get_value(
		"Aqua Run", {"rider": rider.name, "run_date": frappe.utils.nowdate()}, "name"
	)
	if not run or not frappe.db.count("Aqua Run Stop", {"run": run, "status": C.PENDING}):
		return False

	cache_key = f"aqua:ping:{rider.name}"
	if frappe.cache().get_value(cache_key):
		return False
	frappe.cache().set_value(cache_key, 1, expires_in_sec=10)

	frappe.db.set_value(
		"Aqua Rider Profile",
		rider.name,
		{"latitude": latitude, "longitude": longitude},
		update_modified=False,
	)

	emit_rider_location(
		rider.name, latitude, longitude, heading=heading if heading not in ("", None) else None
	)
	return True
