"""Empty bottles (API_SPEC 5.5)."""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.response import invalid, no_content, not_found, ok
from aqua_mart.services.serializers import serialize_holding


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def list_empties(**kwargs):
	"""GET /empties"""
	customer = current_user()

	names = frappe.get_all(
		"Aqua Empty Holding",
		filters={"customer": customer, "count": [">", 0]},
		order_by="litres desc",
		pluck="name",
	)
	holdings = [serialize_holding(name) for name in names]

	# The headline refill price is the cheapest one available to them.
	refill_price = frappe.get_all(
		"Aqua Bottle",
		filters={"is_visible": 1, "refill_price": [">", 0]},
		pluck="refill_price",
		order_by="refill_price asc",
		limit=1,
	)
	refill_price = refill_price[0] if refill_price else 0

	return ok(
		{
			"total_deposit": sum(h["deposit"] for h in holdings),
			"refill_price_per_bottle": int(refill_price or 0),
			"holdings": holdings,
		}
	)


def _own_holdings(customer, holding_ids):
	if not holding_ids or not isinstance(holding_ids, list):
		invalid({"holding_ids": "Choose which bottles to hand back."})

	holdings = []
	for holding_id in holding_ids:
		row = frappe.db.get_value(
			"Aqua Empty Holding", holding_id, ["name", "customer"], as_dict=True
		)
		if not row or row.customer != customer:
			not_found("We could not find those bottles.")
		holdings.append(frappe.get_doc("Aqua Empty Holding", holding_id))
	return holdings


def _schedule(customer, body):
	"""Mark holdings for collection. Shared by /return and /pickup."""
	handling = body.get("handling")
	if handling not in ("swap", "refund"):
		invalid({"handling": "Choose whether to swap them or get the deposit back."})

	holdings = _own_holdings(customer, body.get("holding_ids"))

	from aqua_mart.services.wallet import adjust_pending_deposits

	for holding in holdings:
		holding.pending_return = 1
		holding.pending_handling = handling
		holding.save(ignore_permissions=True)

		if handling == "refund":
			# The refund lands when the RIDER COLLECTS them, not now. Until
			# then it counts toward pending_deposits and the app says
			# "in 2 days" (5.5).
			adjust_pending_deposits(customer, int(holding.deposit or 0))

	return holdings, handling


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def return_empties(**kwargs):
	"""POST /empties/return"""
	customer = current_user()
	holdings, handling = _schedule(customer, request_body())

	if handling == "swap":
		_create_swap_order(customer, holdings)

	return no_content()


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def pickup_empties(**kwargs):
	"""POST /empties/pickup - schedules a collection with no order attached."""
	customer = current_user()
	_schedule(customer, request_body())
	return no_content()


def _create_swap_order(customer, holdings):
	"""A swap becomes a refill order for the same count at refill price (5.5)."""
	from aqua_mart.api.orders import _create_order

	address = frappe.db.get_value("Aqua Address", {"customer": customer, "is_default": 1}, "name")
	if not address:
		return None

	by_seller = {}
	for holding in holdings:
		by_seller.setdefault(holding.seller, []).append(holding)

	created = []
	for seller, rows in by_seller.items():
		lines = []
		for holding in rows:
			bottle = frappe.db.get_value(
				"Aqua Bottle",
				{"seller": seller, "litres": str(int(holding.litres)), "is_visible": 1},
				"name",
			)
			if not bottle:
				continue
			lines.append(
				{"bottle_id": bottle, "kind": C.KIND_REFILL, "quantity": int(holding.count)}
			)

		if lines:
			created.append(
				_create_order(
					customer,
					{
						"seller_id": seller,
						"address_id": address,
						"lines": lines,
						"payment_method": "cash",
					},
				)
			)
	return created
