"""Empty bottle holdings and deposits (API_SPEC 5.5).

The customer holds deposits on empties and can either SWAP them for full
bottles at refill price, or RETURN them for the deposit back. A refund is
credited when the rider COLLECTS them, not when the customer asks - until
then the money sits in `pending_deposits`.
"""

import frappe

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_settings
from aqua_mart.services import constants as C


def record_empties_for_order(order):
	"""On delivery: buyNew bottles become holdings the customer now owns.

	A refill swaps an empty for a full one, so the holding count does not
	change; only buyNew adds a bottle (and its deposit) to their name.
	"""
	for line in order.lines:
		if line.kind != C.KIND_BUY_NEW:
			continue

		deposit_each = frappe.db.get_value("Aqua Bottle", line.bottle, "deposit") or int(
			get_settings().default_deposit
		)
		_add_holding(
			order.customer,
			order.seller,
			int(line.litres),
			int(line.quantity),
			int(deposit_each) * int(line.quantity),
		)


def _add_holding(customer, seller, litres, count, deposit):
	name = frappe.db.get_value(
		"Aqua Empty Holding", {"customer": customer, "seller": seller, "litres": litres}, "name"
	)
	if name:
		holding = frappe.get_doc("Aqua Empty Holding", name)
		holding.count = int(holding.count or 0) + count
		holding.deposit = int(holding.deposit or 0) + deposit
		holding.save(ignore_permissions=True)
		return holding

	return frappe.get_doc(
		{
			"doctype": "Aqua Empty Holding",
			"customer": customer,
			"seller": seller,
			"seller_name": frappe.db.get_value("Aqua Seller Profile", seller, "business_name"),
			"litres": litres,
			"count": count,
			"deposit": deposit,
		}
	).insert(ignore_permissions=True)


def collect_holdings(customer, seller=None):
	"""Called when the rider actually takes the empties back.

	Releases any pending deposit into the spendable wallet balance.
	"""
	from aqua_mart.services.wallet import adjust_pending_deposits, credit

	filters = {"customer": customer, "pending_return": 1}
	if seller:
		filters["seller"] = seller

	for name in frappe.get_all("Aqua Empty Holding", filters=filters, pluck="name"):
		holding = frappe.get_doc("Aqua Empty Holding", name)

		if holding.pending_handling == "refund":
			credit(
				customer,
				holding.deposit,
				f"Deposit refund · {holding.count} × {holding.litres}L",
				"Aqua Empty Holding",
				holding.name,
			)
			adjust_pending_deposits(customer, -int(holding.deposit or 0))

		frappe.delete_doc("Aqua Empty Holding", holding.name, ignore_permissions=True, force=True)
