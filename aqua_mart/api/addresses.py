"""Address book (API_SPEC 5.3).

Invariants enforced here:
* exactly one default address per customer, changed atomically
* deleting the default promotes another rather than leaving none
* `is_serviceable` is server-computed on every read and never accepted
  from the client
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.response import invalid, no_content, not_found, ok
from aqua_mart.services.serializers import serialize_address


def _own_address(customer, name):
	address = frappe.db.get_value("Aqua Address", name, ["name", "customer"], as_dict=True)
	if not address or address.customer != customer:
		not_found("We could not find that address.")
	return frappe.get_doc("Aqua Address", name)


def _clear_other_defaults(customer, keep):
	"""Exactly one default. Cleared in one statement so no window has two."""
	frappe.db.sql(
		"""update `tabAqua Address`
		   set is_default = 0
		   where customer = %s and name != %s and is_default = 1""",
		(customer, keep),
	)


def _validate(body, partial=False):
	errors = {}

	label = body.get("label")
	if label is not None and label not in C.ADDRESS_LABELS:
		errors["label"] = "Choose home, office or other."

	if not partial or "area" in body:
		if not (body.get("area") or "").strip():
			errors["area"] = "Enter the area."

	if errors:
		invalid(errors)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def list_addresses(**kwargs):
	"""GET /addresses"""
	customer = current_user()
	names = frappe.get_all(
		"Aqua Address",
		filters={"customer": customer},
		order_by="is_default desc, modified desc",
		pluck="name",
	)
	return ok([serialize_address(name) for name in names])


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def create(**kwargs):
	"""POST /addresses"""
	customer = current_user()
	body = request_body()
	_validate(body)

	is_first = not frappe.db.exists("Aqua Address", {"customer": customer})
	wants_default = bool(body.get("is_default")) or is_first

	doc = frappe.get_doc(
		{
			"doctype": "Aqua Address",
			"customer": customer,
			"label": body.get("label") or "home",
			"title": body.get("title"),
			"area": (body.get("area") or "").strip(),
			"house_number": body.get("house_number"),
			"rider_note": body.get("rider_note"),
			"latitude": body.get("latitude"),
			"longitude": body.get("longitude"),
			"is_default": 1 if wants_default else 0,
		}
	).insert(ignore_permissions=True)

	if wants_default:
		_clear_other_defaults(customer, doc.name)

	return ok(serialize_address(doc), status=201)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def update(id=None, **kwargs):
	"""PUT /addresses/{id}"""
	customer = current_user()
	doc = _own_address(customer, id)
	body = request_body()
	_validate(body, partial=True)

	for field in ("label", "title", "area", "house_number", "rider_note", "latitude", "longitude"):
		if field in body:
			setattr(doc, field, body.get(field))

	if body.get("is_default"):
		doc.is_default = 1

	doc.save(ignore_permissions=True)

	if doc.is_default:
		_clear_other_defaults(customer, doc.name)

	return ok(serialize_address(doc))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def delete(id=None, **kwargs):
	"""DELETE /addresses/{id} - promotes another default if needed."""
	customer = current_user()
	doc = _own_address(customer, id)
	was_default = bool(doc.is_default)

	frappe.delete_doc("Aqua Address", doc.name, ignore_permissions=True)

	if was_default:
		replacement = frappe.db.get_value(
			"Aqua Address", {"customer": customer}, "name", order_by="modified desc"
		)
		if replacement:
			frappe.db.set_value("Aqua Address", replacement, "is_default", 1)

	return no_content()


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def make_default(id=None, **kwargs):
	"""POST /addresses/{id}/default"""
	customer = current_user()
	doc = _own_address(customer, id)

	doc.is_default = 1
	doc.save(ignore_permissions=True)
	_clear_other_defaults(customer, doc.name)

	return ok(serialize_address(doc))
