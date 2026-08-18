"""Re-pricing and totals (API_SPEC 5.2).

The client sends `unit_price` on every line. It is advisory ONLY - the field
exists because the DTO is shared with the response. Every line is re-priced
from the catalogue here, and a stale client price is a 409, not a silent
correction: the customer must see the new number before they commit.
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.response import conflict, not_found

STALE_PRICE_MESSAGE = "Prices changed while you were ordering. Please check your cart."


def price_lines(seller_name, lines):
	"""Validate and re-price the requested lines against the seller's shelf.

	Returns rows ready to attach to an Aqua Order, plus the subtotal and the
	number of empties the rider will collect back.
	"""
	if not lines:
		conflict("Your cart is empty.", code="empty_cart")

	priced = []
	subtotal = 0
	empties = 0

	for line in lines:
		bottle_id = line.get("bottle_id")
		if not bottle_id:
			conflict(STALE_PRICE_MESSAGE, code="stale_price")

		bottle = frappe.db.get_value(
			"Aqua Bottle",
			bottle_id,
			[
				"name",
				"seller",
				"litres",
				"bottle_name",
				"refill_price",
				"new_price",
				"filled_stock",
				"is_visible",
			],
			as_dict=True,
		)
		if not bottle:
			not_found("One of the bottles in your cart is no longer available.")

		# Every bottle must belong to THIS seller and be visible.
		if bottle.seller != seller_name or not bottle.is_visible:
			conflict(
				"One of the bottles in your cart is no longer available from this seller.",
				code="bottle_unavailable",
			)

		kind = line.get("kind")
		if kind not in C.LINE_KINDS:
			conflict(STALE_PRICE_MESSAGE, code="stale_price")

		try:
			quantity = int(line.get("quantity") or 0)
		except (TypeError, ValueError):
			quantity = 0
		if quantity < 1:
			conflict("Choose how many bottles you want.", code="invalid_quantity")

		if int(bottle.filled_stock or 0) < quantity:
			conflict(
				f"{bottle.bottle_name} is out of stock right now.",
				code="out_of_stock",
			)

		# The authoritative price - never the client's.
		unit_price = int(
			bottle.refill_price if kind == C.KIND_REFILL else bottle.new_price
		)

		client_price = line.get("unit_price")
		if client_price is not None and int(client_price) != unit_price:
			conflict(STALE_PRICE_MESSAGE, code="stale_price")

		if kind == C.KIND_REFILL:
			empties += quantity

		subtotal += unit_price * quantity
		priced.append(
			{
				"bottle": bottle.name,
				"litres": int(bottle.litres),
				"item_name": bottle.bottle_name,
				"kind": kind,
				"unit_price": unit_price,
				"quantity": quantity,
			}
		)

	return priced, subtotal, empties


def delivery_fee(seller, subtotal):
	"""Flat per-seller fee, waived over the seller's free-delivery threshold.

	Appendix C question 1 is still open (flat vs distance-based, and who sets
	it). This implements the flat-per-seller reading, which is the only one
	the current data model supports.
	"""
	threshold = seller.free_delivery_over
	fee = int(seller.delivery_fee or 0)

	if threshold is not None and int(threshold) == 0:
		return 0
	if threshold is not None and subtotal >= int(threshold):
		return 0
	return fee


def order_total(subtotal, fee):
	"""Used server-side only for wallet/khata checks.

	Never serialised - the client computes its own total from the lines and
	a disagreeing figure would show the customer a different number (5.2.1).
	"""
	return int(subtotal) + int(fee)
