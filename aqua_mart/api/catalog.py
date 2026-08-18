"""Catalogue endpoints (API_SPEC 5.1).

Server rules that are easy to get wrong and are enforced here:

* only approved, non-suspended sellers whose service area covers the address
* CLOSED sellers still appear (greyed on the client) - never filter them out
* bottles with is_visible=0 are never returned to a customer at all
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.geo import distance_to_address, seller_covers
from aqua_mart.services.guard import aqua_endpoint, current_user
from aqua_mart.services.response import not_found, ok, paginate
from aqua_mart.services.serializers import compute_is_open, serialize_bottle, serialize_seller


def _approved_sellers():
	return frappe.get_all(
		"Aqua Seller Profile",
		filters={"verification_status": C.APPROVED, "is_suspended": 0},
		pluck="name",
	)


def _address_for(customer, address_id):
	"""The customer's own address, or their default one."""
	if address_id:
		address = frappe.db.get_value(
			"Aqua Address", address_id, ["name", "customer"], as_dict=True
		)
		if not address or address.customer != customer:
			not_found("We could not find that address.")
		return frappe.get_doc("Aqua Address", address_id)

	default = frappe.db.get_value("Aqua Address", {"customer": customer, "is_default": 1}, "name")
	return frappe.get_doc("Aqua Address", default) if default else None


def _shelf(customer, address, query=None, sort=None, open_now=False, limit=None, offset=0):
	"""Build the water shelf: cover-check, score, sort, page."""
	rows = []
	for name in _approved_sellers():
		seller = frappe.get_doc("Aqua Seller Profile", name)

		if address and not seller_covers(seller, address):
			continue

		if query:
			q = query.strip().lower()
			haystack = " ".join(
				filter(
					None,
					[
						seller.business_name or "",
						seller.purification or "",
						" ".join(a.area or "" for a in seller.areas),
					],
				)
			).lower()
			if q not in haystack:
				continue

		is_open = compute_is_open(seller)
		if open_now and not is_open:
			continue

		distance = distance_to_address(seller, address) if address else None
		rows.append((seller, distance, is_open))

	rows = _sort(rows, sort)

	serialized = [
		serialize_seller(seller, customer=customer, distance_metres=distance)
		for seller, distance, _ in rows
	]

	if limit is not None:
		serialized = serialized[offset : offset + limit]
	return serialized


def _sort(rows, sort):
	"""Default is a blend of distance and rating; the client does not re-sort."""
	if sort == "nearest":
		return sorted(rows, key=lambda r: (r[1] is None, r[1] or 0))
	if sort == "fastest":
		return sorted(rows, key=lambda r: int(r[0].eta_minutes or 999))
	if sort == "rating":
		return sorted(rows, key=lambda r: -float(r[0].rating or 0))
	if sort == "cheapest":
		return sorted(rows, key=lambda r: _cheapest(r[0].name))

	def blended(row):
		seller, distance, is_open = row
		# Open stores first, then a distance/rating blend: every km of
		# travel is worth about half a rating point.
		km = (distance or 0) / 1000.0
		return (not is_open, km * 0.5 - float(seller.rating or 0))

	return sorted(rows, key=blended)


def _cheapest(seller_name):
	prices = frappe.get_all(
		"Aqua Bottle",
		filters={"seller": seller_name, "is_visible": 1, "refill_price": [">", 0]},
		pluck="refill_price",
		order_by="refill_price asc",
		limit=1,
	)
	return int(prices[0]) if prices else 10**9


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def sellers_nearby(**kwargs):
	"""GET /sellers/nearby - the customer home shelf."""
	customer = current_user()
	limit, offset = paginate(frappe.local.form_dict)
	address = _address_for(customer, frappe.local.form_dict.get("address_id"))

	return ok(
		_shelf(
			customer,
			address,
			query=frappe.local.form_dict.get("q"),
			limit=limit,
			offset=offset,
		)
	)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def sellers_list(**kwargs):
	"""GET /sellers - the whole serviceable shelf."""
	return sellers_nearby(**kwargs)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def sellers_search(**kwargs):
	"""GET /sellers/search - matches name, area and purification label."""
	customer = current_user()
	form = frappe.local.form_dict
	limit, offset = paginate(form)
	address = _address_for(customer, form.get("address_id"))

	return ok(
		_shelf(
			customer,
			address,
			query=form.get("q"),
			sort=form.get("sort"),
			open_now=str(form.get("open_now") or "").lower() == "true",
			limit=limit,
			offset=offset,
		)
	)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def seller_detail(id=None, **kwargs):
	"""GET /sellers/{id}"""
	customer = current_user()
	seller = frappe.db.get_value(
		"Aqua Seller Profile", id, ["name", "verification_status", "is_suspended"], as_dict=True
	)
	if not seller or seller.verification_status != C.APPROVED or seller.is_suspended:
		not_found("We could not find that seller.")

	address = _address_for(customer, frappe.local.form_dict.get("address_id"))
	doc = frappe.get_doc("Aqua Seller Profile", id)
	distance = distance_to_address(doc, address) if address else None

	return ok(serialize_seller(doc, customer=customer, distance_metres=distance))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def seller_bottles(id=None, **kwargs):
	"""GET /sellers/{id}/bottles - the shelf, visible bottles only."""
	if not frappe.db.exists("Aqua Seller Profile", id):
		not_found("We could not find that seller.")

	names = frappe.get_all(
		"Aqua Bottle", filters={"seller": id, "is_visible": 1}, pluck="name"
	)
	# `litres` is a Select field, so it sorts as a string in SQL ("10" before
	# "6"). Order on the integer after serialising.
	bottles = sorted(
		(serialize_bottle(name) for name in names), key=lambda b: b["litres"], reverse=True
	)
	return ok(bottles)
