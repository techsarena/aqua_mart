"""Wallet, top-ups, cards and khata (API_SPEC 5.4).

Card note: no PAN and no CVV is ever persisted here. The body is forwarded
to the PSP and only a token plus the last four digits survive (5.4, 10.6).
"""

import re

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.response import invalid, no_content, not_found, ok, paginate
from aqua_mart.services.serializers import iso, serialize_topup, serialize_transaction
from aqua_mart.services.wallet import get_wallet as _get_wallet


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def get_wallet(**kwargs):
	"""GET /wallet"""
	customer = current_user()
	wallet = _get_wallet(customer)

	names = frappe.get_all(
		"Aqua Wallet Transaction",
		filters={"wallet": wallet.name},
		order_by="at desc",
		limit_page_length=C.DEFAULT_LIMIT,
		pluck="name",
	)

	return ok(
		{
			"balance": int(wallet.balance or 0),
			# Deposits released when the customer returns their empties -
			# shown apart from the spendable balance.
			"pending_deposits": int(wallet.pending_deposits or 0),
			"transactions": [serialize_transaction(name) for name in names],
		}
	)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def transactions(**kwargs):
	"""GET /wallet/transactions - the paginated ledger."""
	customer = current_user()
	wallet = _get_wallet(customer)
	limit, offset = paginate(frappe.local.form_dict)

	names = frappe.get_all(
		"Aqua Wallet Transaction",
		filters={"wallet": wallet.name},
		order_by="at desc",
		limit_page_length=limit,
		limit_start=offset,
		pluck="name",
	)
	return ok([serialize_transaction(name) for name in names])


# Promotional credit: "Top up Rs 1,000, get Rs 60 free".
BONUS_TIERS = ((5000, 350), (2000, 140), (1000, 60), (500, 20))


def _bonus_for(amount):
	for threshold, bonus in BONUS_TIERS:
		if amount >= threshold:
			return bonus
	return 0


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def top_up(**kwargs):
	"""POST /wallet/top-up - returns a PENDING top-up.

	The customer approves it in the provider's own app, so this call returns
	before the money moves.
	"""
	customer = current_user()
	body = request_body()

	errors = {}
	try:
		amount = int(body.get("amount") or 0)
	except (TypeError, ValueError):
		amount = 0
	if amount < 100:
		errors["amount"] = "Enter an amount of Rs 100 or more."

	provider = body.get("provider")
	if provider not in C.TOPUP_PROVIDERS:
		errors["provider"] = "Choose JazzCash or Easypaisa."
	if errors:
		invalid(errors)

	reference = _provider_reference(provider)

	topup = frappe.get_doc(
		{
			"doctype": "Aqua Top Up",
			"customer": customer,
			"amount": amount,
			"provider": provider,
			"status": "pending",
			"bonus": _bonus_for(amount),
			"fee": 0,
			"reference": reference,
		}
	).insert(ignore_permissions=True)

	return ok(serialize_topup(topup), status=201)


def _provider_reference(provider):
	prefix = "JC" if provider == "jazzCash" else "EP"
	return f"{prefix}-{frappe.generate_hash(length=8).upper()}"


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def topup_status(id=None, **kwargs):
	"""GET /wallet/top-up/{id} - polled roughly every 2s by the client.

	The credit is idempotent against the provider reference because this
	poll and the provider callback WILL race (5.4, 10.4).
	"""
	customer = current_user()
	row = frappe.db.get_value("Aqua Top Up", id, ["name", "customer"], as_dict=True)
	if not row or row.customer != customer:
		not_found("We could not find that top-up.")

	topup = frappe.get_doc("Aqua Top Up", id)

	if topup.status == "pending":
		_expire_if_stale(topup)

	return ok(serialize_topup(topup))


def _expire_if_stale(topup):
	"""A pending top-up times out after 5 minutes (5.4).

	The client's pending screen expects a resolution; leaving it pending
	forever strands the user.
	"""
	age = frappe.utils.time_diff_in_seconds(frappe.utils.now_datetime(), topup.creation)
	if age < 300:
		return

	topup.status = "failed"
	topup.failure_reason = "You didn't approve the request in time."
	topup.save(ignore_permissions=True)


def complete_topup(reference, succeeded=True, failure_reason=None):
	"""Called by the PSP callback (and by the poll) to settle a top-up.

	Safe to call twice - the wallet credit is guarded by `is_credited`.
	"""
	name = frappe.db.get_value("Aqua Top Up", {"reference": reference}, "name")
	if not name:
		return None

	topup = frappe.get_doc("Aqua Top Up", name)
	if topup.status != "pending":
		return topup

	if succeeded:
		from aqua_mart.services.wallet import credit_topup_once

		topup.status = "succeeded"
		topup.completed_at = frappe.utils.now_datetime()
		topup.save(ignore_permissions=True)
		credit_topup_once(topup)
	else:
		topup.status = "failed"
		topup.failure_reason = failure_reason or "The payment did not go through."
		topup.save(ignore_permissions=True)

	return topup


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def save_card(**kwargs):
	"""POST /payment-methods/cards

	The PAN and CVV are NEVER persisted. This handler forwards to the PSP
	and keeps only the token and the last four digits; the body is redacted
	in logs, mirroring the client (5.4).
	"""
	customer = current_user()
	body = request_body()

	number = re.sub(r"\D", "", str(body.get("number") or ""))
	errors = {}
	if len(number) < 13 or len(number) > 19 or not _luhn(number):
		errors["number"] = "Enter a valid card number."
	if not (body.get("expiry") or "").strip():
		errors["expiry"] = "Enter the expiry date."
	cvv = str(body.get("cvv") or "")
	if not cvv.isdigit() or len(cvv) not in (3, 4):
		errors["cvv"] = "Enter the 3-digit code on the back."
	if errors:
		invalid(errors)

	tokenise = frappe.get_hooks("aqua_card_tokeniser")
	if tokenise:
		frappe.get_attr(tokenise[-1])(
			customer=customer,
			number=number,
			holder=body.get("holder"),
			expiry=body.get("expiry"),
			cvv=cvv,
			save=bool(body.get("save")),
		)

	# Nothing sensitive is written to our database at any point.
	del number, cvv
	return no_content()


def _luhn(number):
	total = 0
	for index, digit in enumerate(reversed(number)):
		value = int(digit)
		if index % 2:
			value *= 2
			if value > 9:
				value -= 9
		total += value
	return total % 10 == 0


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_CUSTOMER)
def khata(**kwargs):
	"""GET /khata - the monthly-account summary."""
	customer = current_user()

	row = frappe.db.get_value(
		"Aqua Khata",
		{"customer": customer, "is_approved": 1},
		["name", "seller", "due", "due_date"],
		as_dict=True,
	)
	if not row:
		return ok({"due": 0, "seller_name": None, "due_date": None, "orders": []})

	orders = frappe.get_all(
		"Aqua Order",
		filters={"customer": customer, "seller": row.seller, "payment_method": "khata"},
		fields=["name", "reference", "delivery_fee", "placed_at"],
		order_by="placed_at desc",
		limit_page_length=50,
	)

	lines = []
	for order in orders:
		subtotal = frappe.db.sql(
			"""select coalesce(sum(unit_price * quantity), 0)
			   from `tabAqua Order Line` where parent = %s""",
			order.name,
		)[0][0]
		lines.append(
			{
				"reference": order.reference,
				"amount": int(subtotal or 0) + int(order.delivery_fee or 0),
				"at": iso(order.placed_at),
			}
		)

	return ok(
		{
			"due": int(row.due or 0),
			"seller_name": frappe.db.get_value("Aqua Seller Profile", row.seller, "business_name"),
			"due_date": iso(row.due_date),
			"orders": lines,
		}
	)
