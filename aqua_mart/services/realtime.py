"""Socket emitters (API_SPEC 8.4).

Two rules run through all of this:

* Send the WHOLE object, not a diff. The client reuses its REST DTOs and
  merge bugs are invisible until they aren't.
* Sockets are an accelerator, never a source of truth (8.6). Nothing here
  may be the only way the client learns something - every screen still works
  over REST alone.

Rooms are joined server-side from the authenticated identity; a client may
never ask to join an arbitrary room (8.3).
"""

import frappe

from aqua_mart.services import constants as C

# Custom rooms. Frappe's own helper produces `user:{user}`, which the
# socket.io handler already auto-joins, so we match that spelling.
def user_room(user):
	return f"user:{user}"


def order_room(order_name):
	return f"order:{order_name}"


def seller_room(seller_name):
	return f"seller:{seller_name}"


def rider_room(rider_name):
	return f"rider:{rider_name}"


def _emit(event, payload, room):
	"""Publish after commit so a listener never sees a rolled-back state."""
	try:
		frappe.publish_realtime(event=event, message=payload, room=room, after_commit=True)
	except Exception:
		# A dead socket server must never break the REST request that
		# triggered it. The client re-fetches on reconnect anyway.
		frappe.log_error(title="Aqua Mart realtime emit failed")


def emit_order_status(order, serialized=None):
	"""order:status - every transition, including the unhappy terminals."""
	from aqua_mart.services.serializers import serialize_order

	payload = {
		"order_id": order.name,
		"status": order.status,
		"order": serialized or serialize_order(order),
	}
	_emit("order:status", payload, order_room(order.name))
	_emit("order:status", payload, seller_room(order.seller))


def emit_order_new(order):
	"""order:new - fires the seller's new-order sound and badge."""
	from aqua_mart.services.serializers import serialize_order

	_emit("order:new", {"order": serialize_order(order)}, seller_room(order.seller))


def emit_rider_assigned(order):
	from aqua_mart.services.serializers import stops_before

	_emit(
		"order:rider_assigned",
		{
			"order_id": order.name,
			"rider_id": order.rider,
			"rider_name": order.rider_name,
			"rider_rating": float(order.rider_rating) if order.rider_rating else None,
			"stops_before": stops_before(order),
		},
		order_room(order.name),
	)


def emit_rider_location(rider_name, latitude, longitude, heading=None):
	"""rider:location - the one high-frequency event.

	Fanned out only to orders this rider is currently carrying, and only
	while they are onTheWay. A rider's phone is on mobile data and a bike
	battery; pushing to nobody is pure cost (8.4).
	"""
	from aqua_mart.services.serializers import iso, stops_before

	orders = frappe.get_all(
		"Aqua Order",
		filters={"rider": rider_name, "status": C.ON_THE_WAY},
		fields=["name", "eta_minutes"],
	)

	now = iso(frappe.utils.now_datetime())
	for row in orders:
		order = frappe.get_doc("Aqua Order", row.name)
		_emit(
			"rider:location",
			{
				"rider_id": rider_name,
				"order_id": order.name,
				"latitude": float(latitude),
				"longitude": float(longitude),
				"heading": float(heading) if heading is not None else None,
				"stops_before": stops_before(order),
				"eta_minutes": int(order.eta_minutes) if order.eta_minutes else None,
				"at": now,
			},
			order_room(order.name),
		)


def emit_run_updated(run):
	"""run:updated - the whole run after any change."""
	from aqua_mart.services.serializers import serialize_run

	_emit("run:updated", serialize_run(run), rider_room(run.rider))


def emit_notification(notification):
	"""notification:new - replaces the client's polling of /notifications."""
	from aqua_mart.services.serializers import serialize_notification

	_emit(
		"notification:new",
		{"notification": serialize_notification(notification)},
		user_room(notification.user),
	)


def emit_seller_dashboard(seller_name):
	"""seller:dashboard - throttled to once per 5s (8.4).

	A busy seller changes numbers constantly and the screen only needs to
	look alive, so a Redis key swallows the burst.
	"""
	cache_key = f"aqua:dash:{seller_name}"
	if frappe.cache().get_value(cache_key):
		return
	frappe.cache().set_value(cache_key, 1, expires_in_sec=5)

	from aqua_mart.services.dashboard import build_dashboard

	_emit("seller:dashboard", build_dashboard(seller_name), seller_room(seller_name))
