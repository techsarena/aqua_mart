"""Customer order endpoints (API_SPEC 5.2).

The rules that bite:
* the address is SNAPSHOT onto the order, never joined live (5.2.1)
* no subtotal/total is ever serialised - the client computes them
* the client's unit_price is advisory; every line is re-priced (5.2)
* illegal transitions are 409, not 400
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services import order_state, realtime
from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.notifications import notify, notify_seller_new_order
from aqua_mart.services.pricing import delivery_fee, order_total, price_lines
from aqua_mart.services.response import conflict, invalid, no_content, not_found, ok, paginate
from aqua_mart.services.serializers import (
	compose_items,
	compute_is_open,
	serialize_order,
	serialize_timeline,
)
from aqua_mart.services.wallet import debit


def _own_order(customer, name):
	"""A customer may read an order ONLY if it is theirs (2)."""
	row = frappe.db.get_value("Aqua Order", name, ["name", "customer"], as_dict=True)
	if not row or row.customer != customer:
		not_found("We could not find that order.")
	return frappe.get_doc("Aqua Order", name)


def _next_reference():
	"""The short, speakable number that appears in disputes: SO-2418."""
	counter = frappe.db.get_value("Aqua Settings", None, "order_counter") if frappe.db.exists(
		"DocType", "Aqua Settings"
	) else None
	if counter is None:
		count = frappe.db.count("Aqua Order")
		return f"SO-{2400 + count + 1}"
	return f"SO-{int(counter) + 1}"


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def place(**kwargs):
	"""POST /orders"""
	customer = current_user()
	body = request_body()

	# Idempotency: a replayed POST returns the ORIGINAL order (10.4).
	idempotency_key = frappe.local.request.headers.get("Idempotency-Key")
	if idempotency_key:
		existing = frappe.db.get_value(
			"Aqua Order", {"idempotency_key": idempotency_key, "customer": customer}, "name"
		)
		if existing:
			return ok(serialize_order(existing, for_role=C.ROLE_CUSTOMER), status=201)

	order = _create_order(customer, body, idempotency_key)
	return ok(serialize_order(order, for_role=C.ROLE_CUSTOMER), status=201)


def _create_order(customer, body, idempotency_key=None):
	"""Build one order from a validated body. Shared by place() and reorder()."""
	seller_id = body.get("seller_id")
	address_id = body.get("address_id")

	errors = {}
	if not seller_id:
		errors["seller_id"] = "Choose a seller."
	if not address_id:
		errors["address_id"] = "Choose a delivery address."
	payment_method = body.get("payment_method") or "cash"
	if payment_method not in C.PAYMENT_METHODS:
		errors["payment_method"] = "Choose a payment method."
	if errors:
		invalid(errors)

	seller = frappe.db.get_value(
		"Aqua Seller Profile", seller_id, ["name"], as_dict=True
	)
	if not seller:
		not_found("We could not find that seller.")
	seller = frappe.get_doc("Aqua Seller Profile", seller_id)

	if seller.verification_status != C.APPROVED or seller.is_suspended:
		conflict("This seller is not taking orders.", code="seller_unavailable")
	if not compute_is_open(seller):
		conflict("This seller has stopped taking orders for today.", code="seller_closed")

	# The address must belong to the caller and be inside the seller's area.
	address = frappe.db.get_value("Aqua Address", address_id, ["name", "customer"], as_dict=True)
	if not address or address.customer != customer:
		not_found("We could not find that address.")
	address = frappe.get_doc("Aqua Address", address_id)

	from aqua_mart.services.geo import seller_covers

	if not seller_covers(seller, address):
		conflict("This seller does not deliver to that address.", code="not_serviceable")

	lines, subtotal, empties = price_lines(seller.name, body.get("lines") or [])
	fee = delivery_fee(seller, subtotal)
	total = order_total(subtotal, fee)

	if payment_method == "wallet":
		from aqua_mart.services.wallet import get_wallet

		wallet = get_wallet(customer)
		if int(wallet.balance or 0) < total:
			conflict(
				"Your wallet balance is too low for this order. Please top up first.",
				code="insufficient_balance",
			)

	if payment_method == "khata":
		approved = frappe.db.exists(
			"Aqua Khata", {"customer": customer, "seller": seller.name, "is_approved": 1}
		)
		if not approved:
			conflict(
				"You do not have a monthly account with this seller yet.",
				code="no_khata",
			)

	profile_name = frappe.db.get_value("Aqua Profile", {"user": customer}, "full_name")

	order = frappe.get_doc(
		{
			"doctype": "Aqua Order",
			"reference": _next_reference(),
			"customer": customer,
			"customer_name": profile_name,
			"seller": seller.name,
			"seller_name": seller.business_name,
			"status": C.PENDING,
			"payment_method": payment_method,
			"placed_at": frappe.utils.now_datetime(),
			"delivery_fee": fee,
			"eta_minutes": int(seller.eta_minutes or 0),
			"idempotency_key": idempotency_key,
			"lines": lines,
			# --- the address SNAPSHOT (5.2.1) ---
			"address": address.name,
			"address_label": address.label,
			"address_title": address.title,
			"address_area": address.area,
			"address_house_number": address.house_number,
			"address_rider_note": address.rider_note,
			"address_latitude": address.latitude,
			"address_longitude": address.longitude,
			"address_is_default": address.is_default,
		}
	).insert(ignore_permissions=True)

	# Prepaid methods take the money now; cash is collected at the door.
	if payment_method == "wallet":
		debit(customer, total, f"Order {order.reference}", "Aqua Order", order.name)
	elif payment_method == "khata":
		_add_to_khata(customer, seller.name, total)

	_reserve_stock(lines)
	order_state.log(order.name, C.PENDING, actor=customer)

	realtime.emit_order_new(order)
	realtime.emit_seller_dashboard(seller.name)
	notify_seller_new_order(order)

	return order


def _reserve_stock(lines):
	"""Decrement filled stock as the order is taken."""
	for line in lines:
		frappe.db.sql(
			"""update `tabAqua Bottle`
			   set filled_stock = greatest(0, filled_stock - %s)
			   where name = %s""",
			(int(line["quantity"]), line["bottle"]),
		)


def _restore_stock(order):
	"""Put stock back when an order dies before delivery."""
	for line in order.lines:
		if line.bottle:
			frappe.db.sql(
				"""update `tabAqua Bottle`
				   set filled_stock = filled_stock + %s
				   where name = %s""",
				(int(line.quantity), line.bottle),
			)


def _add_to_khata(customer, seller, amount):
	name = frappe.db.get_value(
		"Aqua Khata", {"customer": customer, "seller": seller, "is_approved": 1}, "name"
	)
	if name:
		khata = frappe.get_doc("Aqua Khata", name)
		khata.due = int(khata.due or 0) + int(amount)
		khata.save(ignore_permissions=True)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def list_orders(**kwargs):
	"""GET /orders - newest first, scoped to the caller.

	`active` and `past` are accepted as groupings because the client's
	Orders tab is split that way.
	"""
	customer = current_user()
	limit, offset = paginate(frappe.local.form_dict)
	status = frappe.local.form_dict.get("status")

	filters = {"customer": customer}
	if status == "active":
		filters["status"] = ["not in", C.TERMINAL_STATUSES]
	elif status == "past":
		filters["status"] = ["in", C.TERMINAL_STATUSES]
	elif status in C.ORDER_STATUSES:
		filters["status"] = status

	names = frappe.get_all(
		"Aqua Order",
		filters=filters,
		order_by="placed_at desc",
		limit_page_length=limit,
		limit_start=offset,
		pluck="name",
	)
	return ok([serialize_order(name, for_role=C.ROLE_CUSTOMER) for name in names])


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def detail(id=None, **kwargs):
	"""GET /orders/{id}"""
	customer = current_user()
	order = _own_order(customer, id)
	return ok(serialize_order(order, for_role=C.ROLE_CUSTOMER))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def tracking(id=None, **kwargs):
	"""GET /orders/{id}/tracking - order object plus a REAL timeline (5.2).

	The timeline overrides the client's derived steps, so it is only sent
	when we have genuine timestamps; otherwise it is omitted entirely and
	the client uses the copy it already owns.
	"""
	customer = current_user()
	order = _own_order(customer, id)

	payload = serialize_order(order, for_role=C.ROLE_CUSTOMER)
	timeline = serialize_timeline(order.name)
	if timeline:
		payload["timeline"] = timeline

	return ok(payload)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def cancel(id=None, **kwargs):
	"""POST /orders/{id}/cancel

	The client hides the button past `onTheWay`, but a replay attack must
	not succeed either - the transition table is the real guard.
	"""
	customer = current_user()
	order = _own_order(customer, id)
	body = request_body()

	order_state.transition(
		order,
		C.CANCELLED_BY_CUSTOMER,
		C.ROLE_CUSTOMER,
		actor=customer,
		cancellation_reason=body.get("reason"),
	)

	_restore_stock(order)
	_refund_if_prepaid(order)

	realtime.emit_order_status(order)
	realtime.emit_seller_dashboard(order.seller)

	seller_user = frappe.db.get_value("Aqua Seller Profile", order.seller, "user")
	notify(
		seller_user,
		"orderUpdate",
		"Order cancelled",
		f"{order.reference} was cancelled by the customer.",
		"/seller/orders",
		actor=customer,
	)

	return ok(serialize_order(order, for_role=C.ROLE_CUSTOMER))


def _refund_if_prepaid(order):
	"""Wallet- and card-paid orders are refunded to the wallet (5.2).

	Cash orders need nothing - no money has moved yet.
	"""
	if order.payment_method not in ("wallet", "card", "jazzCash"):
		if order.payment_method == "khata":
			_add_to_khata(order.customer, order.seller, -_order_value(order))
		return

	from aqua_mart.services.wallet import credit

	credit(
		order.customer,
		_order_value(order),
		f"Refund · {order.reference}",
		"Aqua Order",
		order.name,
	)


def _order_value(order):
	subtotal = sum(int(l.unit_price) * int(l.quantity) for l in order.lines)
	return subtotal + int(order.delivery_fee or 0)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def rate(id=None, **kwargs):
	"""POST /orders/{id}/rating - delivered orders only, once."""
	customer = current_user()
	order = _own_order(customer, id)
	body = request_body()

	if order.status != C.DELIVERED:
		conflict("You can rate an order once it has been delivered.", code="not_delivered")
	if order.rating:
		conflict("You have already rated this order.", code="already_rated")

	try:
		stars = int(body.get("stars") or 0)
	except (TypeError, ValueError):
		stars = 0
	if stars < 1 or stars > 5:
		invalid({"stars": "Choose between 1 and 5 stars."})

	tags = body.get("tags") or []
	order.rating = stars
	order.rating_comment = body.get("comment")
	order.rating_tags = ", ".join(tags) if isinstance(tags, list) else str(tags)
	order.save(ignore_permissions=True)

	# The rating moves both rolling averages.
	_bump_rating("Aqua Seller Profile", order.seller, stars)
	if order.rider:
		_bump_rating("Aqua Rider Profile", order.rider, stars)

	return no_content()


def _bump_rating(doctype, name, stars):
	row = frappe.db.get_value(doctype, name, ["rating_total", "rating_count"], as_dict=True)
	total = int(row.rating_total or 0) + stars
	count = int(row.rating_count or 0) + 1
	frappe.db.set_value(
		doctype,
		name,
		{"rating_total": total, "rating_count": count, "rating": round(total / count, 1)},
	)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def report(id=None, **kwargs):
	"""POST /orders/{id}/report - raises a dispute and starts the 24h clock."""
	customer = current_user()
	order = _own_order(customer, id)
	body = request_body()

	reason = (body.get("reason") or "").strip()
	if not reason:
		invalid({"reason": "Tell us what went wrong."})

	dispute = frappe.get_doc(
		{
			"doctype": "Aqua Dispute",
			"order": order.name,
			"order_reference": order.reference,
			"seller": order.seller,
			"customer": customer,
			"customer_name": order.customer_name,
			"reason": reason,
			"customer_note": body.get("note"),
			"order_summary": compose_items(order),
			"amount": _order_value(order),
			# The clock starts NOW and this is never rewritten (6.7).
			"raised_at": frappe.utils.now_datetime(),
			"status": "open",
			"customer_history": _customer_history(customer),
		}
	).insert(ignore_permissions=True)

	seller_user = frappe.db.get_value("Aqua Seller Profile", order.seller, "user")
	notify(
		seller_user,
		"complaint",
		"Complaint raised",
		f"{order.reference} · {reason}",
		f"/seller/disputes/{dispute.name}",
		actor=customer,
	)

	return no_content()


def _customer_history(customer):
	"""Context that helps the seller judge fairly (6.7)."""
	orders = frappe.db.count("Aqua Order", {"customer": customer, "status": C.DELIVERED})
	complaints = frappe.db.count("Aqua Dispute", {"customer": customer})

	if complaints <= 1:
		return f"Their first complaint in {orders} orders."
	month_start = frappe.utils.get_first_day(frappe.utils.nowdate())
	this_month = frappe.db.count(
		"Aqua Dispute", {"customer": customer, "raised_at": [">=", month_start]}
	)
	if this_month > 1:
		return f"{_ordinal(this_month)} complaint this month."
	return f"{complaints} complaints in {orders} orders."


def _ordinal(n):
	return {1: "First", 2: "Second", 3: "Third"}.get(n, f"{n}th")


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def reorder(id=None, **kwargs):
	"""POST /orders/{id}/reorder - copies the lines at TODAY's prices."""
	customer = current_user()
	old = _own_order(customer, id)

	seller = frappe.get_doc("Aqua Seller Profile", old.seller)
	if seller.verification_status != C.APPROVED or seller.is_suspended:
		conflict("This seller is not taking orders any more.", code="seller_unavailable")
	if not compute_is_open(seller):
		conflict("This seller has stopped taking orders for today.", code="seller_closed")

	default_address = frappe.db.get_value(
		"Aqua Address", {"customer": customer, "is_default": 1}, "name"
	)
	if not default_address:
		conflict("Add a delivery address first.", code="no_address")

	# Re-priced from the catalogue; a gone bottle fails with a message the
	# customer can act on.
	requested = [
		{
			"bottle_id": line.bottle,
			"kind": line.kind,
			"quantity": line.quantity,
		}
		for line in old.lines
	]

	order = _create_order(
		customer,
		{
			"seller_id": old.seller,
			"address_id": default_address,
			"lines": requested,
			"payment_method": old.payment_method,
		},
	)
	return ok(serialize_order(order, for_role=C.ROLE_CUSTOMER), status=201)
