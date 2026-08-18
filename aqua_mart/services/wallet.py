"""Wallet ledger (API_SPEC 5.4).

`amount` on a transaction is ALWAYS positive; `is_credit` carries the
direction. The balance is derived by applying credits and debits, and every
movement writes a ledger line - a balance that changed without a line is a
bug the customer will eventually notice.
"""

import frappe

from aqua_mart.services.response import conflict


def get_wallet(customer, create=True):
	name = frappe.db.get_value("Aqua Wallet", {"customer": customer}, "name")
	if name:
		return frappe.get_doc("Aqua Wallet", name)
	if not create:
		return None

	return frappe.get_doc(
		{"doctype": "Aqua Wallet", "customer": customer, "balance": 0, "pending_deposits": 0}
	).insert(ignore_permissions=True)


def credit(customer, amount, label, reference_doctype=None, reference_name=None):
	"""Add money and write the ledger line."""
	return _move(customer, abs(int(amount)), label, True, reference_doctype, reference_name)


def debit(customer, amount, label, reference_doctype=None, reference_name=None):
	"""Take money, refusing to go negative."""
	amount = abs(int(amount))
	wallet = get_wallet(customer)
	if int(wallet.balance or 0) < amount:
		conflict(
			"Your wallet balance is too low. Please top up and try again.",
			code="insufficient_balance",
		)
	return _move(customer, amount, label, False, reference_doctype, reference_name)


def _move(customer, amount, label, is_credit, reference_doctype, reference_name):
	wallet = get_wallet(customer)
	balance = int(wallet.balance or 0)
	wallet.balance = balance + amount if is_credit else balance - amount
	wallet.save(ignore_permissions=True)

	return frappe.get_doc(
		{
			"doctype": "Aqua Wallet Transaction",
			"wallet": wallet.name,
			"customer": customer,
			"label": label,
			"amount": amount,
			"is_credit": 1 if is_credit else 0,
			"at": frappe.utils.now_datetime(),
			"reference_doctype": reference_doctype,
			"reference_name": reference_name,
		}
	).insert(ignore_permissions=True)


def credit_topup_once(topup):
	"""Credit a succeeded top-up EXACTLY once (5.4, 10.4).

	Both the client's 2s poll and the provider's callback will race to call
	this, so the guard is the `is_credited` flag checked under a row lock.
	"""
	locked = frappe.db.get_value(
		"Aqua Top Up", topup.name, ["is_credited", "amount", "bonus"], as_dict=True, for_update=True
	)
	if locked.is_credited:
		return None

	frappe.db.set_value("Aqua Top Up", topup.name, "is_credited", 1)

	total = int(locked.amount or 0) + int(locked.bonus or 0)
	return credit(
		topup.customer,
		total,
		f"Top-up · {topup.provider}",
		reference_doctype="Aqua Top Up",
		reference_name=topup.name,
	)


def adjust_pending_deposits(customer, delta):
	"""Move the pending-deposit figure, which is shown apart from the balance."""
	wallet = get_wallet(customer)
	wallet.pending_deposits = max(0, int(wallet.pending_deposits or 0) + int(delta))
	wallet.save(ignore_permissions=True)
	return wallet
