"""Runs and stops (API_SPEC 7.1, 7.2).

Two things here carry real operational weight:

* `distance_metres` on a stop is measured from the PREVIOUS stop, not the
  depot - the client sums the remaining stops to show run length, and an
  absolute distance makes that sum meaningless.
* `amount_to_collect` is 0 for anything already paid. Getting this wrong
  means a rider asks a prepaid customer for money.
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.geo import haversine_metres


def today_run(rider_name, create=False):
	"""The rider's run for today, created on demand."""
	today = frappe.utils.nowdate()
	name = frappe.db.get_value(
		"Aqua Run", {"rider": rider_name, "run_date": today}, "name"
	)
	if name:
		return frappe.get_doc("Aqua Run", name)
	if not create:
		return None

	rider = frappe.get_doc("Aqua Rider Profile", rider_name)
	seller_name = frappe.db.get_value("Aqua Seller Profile", rider.seller, "business_name")

	return frappe.get_doc(
		{
			"doctype": "Aqua Run",
			"rider": rider_name,
			"seller": rider.seller,
			"seller_name": seller_name,
			"label": _run_label(),
			"run_date": today,
		}
	).insert(ignore_permissions=True)


def _run_label():
	hour = frappe.utils.now_datetime().hour
	if hour < 12:
		return "Morning run"
	if hour < 17:
		return "Afternoon run"
	return "Evening run"


def amount_to_collect(order):
	"""Only cash orders carry a figure; everything else is already paid."""
	if order.payment_method != "cash":
		return 0
	subtotal = sum(int(l.unit_price) * int(l.quantity) for l in order.lines)
	return subtotal + int(order.delivery_fee or 0)


def empties_to_collect(order):
	"""Equals the refill quantity on the order - buyNew leaves nothing behind."""
	return sum(int(l.quantity) for l in order.lines if l.kind == C.KIND_REFILL)


def add_stop(rider_name, order):
	"""Append a stop to the rider's run, sequenced after the existing ones."""
	run = today_run(rider_name, create=True)

	existing = frappe.db.get_value("Aqua Run Stop", {"run": run.name, "order": order.name}, "name")
	if existing:
		return frappe.get_doc("Aqua Run Stop", existing)

	last = frappe.get_all(
		"Aqua Run Stop", filters={"run": run.name}, pluck="sequence",
		order_by="sequence desc", limit=1,
	)
	last_sequence = last[0] if last else 0

	stop = frappe.get_doc(
		{
			"doctype": "Aqua Run Stop",
			"run": run.name,
			"order": order.name,
			"sequence": int(last_sequence) + 1,
			"status": C.PENDING,
			"amount_to_collect": amount_to_collect(order),
			"empties_to_collect": empties_to_collect(order),
		}
	).insert(ignore_permissions=True)

	resequence(run.name)
	return stop


def resequence(run_name):
	"""Recompute leg distances and plot positions after any change.

	Stop ORDER is the delivery order - the client takes the first pending
	stop as "next" and never re-sorts, so the sequencing decision is ours.
	"""
	stops = frappe.get_all(
		"Aqua Run Stop",
		filters={"run": run_name},
		fields=["name", "order", "sequence"],
		order_by="sequence asc",
	)
	if not stops:
		return

	run = frappe.get_doc("Aqua Run", run_name)
	seller = frappe.get_doc("Aqua Seller Profile", run.seller)

	# The first leg starts at the depot; every later leg starts at the
	# previous stop.
	previous = (seller.latitude, seller.longitude)
	points = []

	for stop in stops:
		order = frappe.db.get_value(
			"Aqua Order", stop.order, ["address_latitude", "address_longitude"], as_dict=True
		)
		here = (order.address_latitude, order.address_longitude)
		distance = haversine_metres(previous[0], previous[1], here[0], here[1])

		frappe.db.set_value(
			"Aqua Run Stop", stop.name, "distance_metres", distance, update_modified=False
		)
		points.append((stop.name, here))
		if here[0] is not None:
			previous = here

	_write_plots(points)


def _write_plots(points):
	"""Normalise coordinates into the client's -1..1 run map.

	Send BOTH x and y or neither - a half-filled plot pins the stop to an
	axis it was never on (7.1).
	"""
	known = [(name, p) for name, p in points if p[0] is not None and p[1] is not None]
	if not known:
		for name, _ in points:
			frappe.db.set_value(
				"Aqua Run Stop", name, {"plot_x": None, "plot_y": None}, update_modified=False
			)
		return

	lats = [p[0] for _, p in known]
	lngs = [p[1] for _, p in known]
	lat_min, lat_max = min(lats), max(lats)
	lng_min, lng_max = min(lngs), max(lngs)

	def scale(value, low, high):
		if high == low:
			return 0.0
		return round((float(value) - low) / (high - low) * 2 - 1, 3)

	for name, point in points:
		if point[0] is None or point[1] is None:
			frappe.db.set_value(
				"Aqua Run Stop", name, {"plot_x": None, "plot_y": None}, update_modified=False
			)
			continue
		frappe.db.set_value(
			"Aqua Run Stop",
			name,
			{
				"plot_x": scale(point[1], lng_min, lng_max),
				"plot_y": scale(point[0], lat_min, lat_max),
			},
			update_modified=False,
		)


def recompute_stops_before(run_name):
	"""`stops_before` is derived, but the orders on a run need re-emitting.

	Called after a stop completes so every later order's tracking screen
	updates (7.2 step 5).
	"""
	from aqua_mart.services.realtime import emit_order_status

	stops = frappe.get_all(
		"Aqua Run Stop",
		filters={"run": run_name, "status": C.PENDING},
		fields=["order"],
		order_by="sequence asc",
	)
	for stop in stops:
		order = frappe.get_doc("Aqua Order", stop.order)
		if order.status == C.ON_THE_WAY:
			emit_order_status(order)
