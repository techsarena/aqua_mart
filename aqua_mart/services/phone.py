"""Phone normalisation and OTP (API_SPEC 4.1, 4.2).

Pakistani numbers arrive in every form a user might type. They are stored
E.164 and only E.164, so a number is one account no matter how it was typed.
"""

import hashlib
import random
import re

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.response import invalid, throttled

E164 = re.compile(r"^\+92\d{10}$")


def normalise_phone(raw):
	"""'0300 4412987' / '+92 300 4412987' / '923004412987' -> '+923004412987'."""
	if not raw:
		return None

	digits = re.sub(r"\D", "", str(raw))

	if digits.startswith("0092"):
		digits = digits[4:]
	elif digits.startswith("92") and len(digits) == 12:
		pass
	elif digits.startswith("0") and len(digits) == 11:
		digits = "92" + digits[1:]
	elif len(digits) == 10 and digits.startswith("3"):
		digits = "92" + digits

	candidate = "+" + digits
	return candidate if E164.match(candidate) else None


def require_phone(raw):
	phone = normalise_phone(raw)
	if not phone:
		invalid({"phone": "Enter a valid Pakistani mobile number."})
	return phone


def _hash_code(phone, code):
	"""Codes are hashed at rest and never logged (10.6)."""
	return hashlib.sha256(f"{phone}:{code}".encode()).hexdigest()


def issue_otp(phone):
	"""Create a code, rate-limited to 3 per number per 15 minutes (4.1)."""
	window_start = frappe.utils.add_to_date(frappe.utils.now_datetime(), minutes=-15)
	recent = frappe.db.count("Aqua OTP", {"phone": phone, "creation": [">", window_start]})
	if recent >= 3:
		throttled("Too many code requests. Please wait 15 minutes.", code="otp_throttled")

	code = f"{random.SystemRandom().randint(0, 999999):06d}"

	frappe.get_doc(
		{
			"doctype": "Aqua OTP",
			"phone": phone,
			"code_hash": _hash_code(phone, code),
			"expires_at": frappe.utils.add_to_date(
				frappe.utils.now_datetime(), minutes=C.OTP_TTL_MINUTES
			),
			"attempts": 0,
			"is_used": 0,
		}
	).insert(ignore_permissions=True)

	send_sms(phone, code)
	# The code is NEVER returned to the caller - not even in staging.
	return C.OTP_RESEND_AFTER_SECONDS


def send_sms(phone, code):
	"""Hand the code to whatever SMS gateway the site configures.

	A site without a gateway logs to the error log in developer mode so the
	flow is testable, and stays silent otherwise.
	"""
	sender = frappe.get_hooks("aqua_sms_sender")
	if sender:
		frappe.get_attr(sender[-1])(phone, code)
		return

	if frappe.conf.get("developer_mode"):
		frappe.log_error(f"OTP for {phone}: {code}", "Aqua Mart OTP (developer mode)")


def verify_otp(phone, code):
	"""Consume a code. Wrong/expired -> 422, too many attempts -> 429 (4.2)."""
	if not code or not str(code).strip():
		invalid({"code": "Enter the code we sent you."})

	row = frappe.db.get_value(
		"Aqua OTP",
		{"phone": phone, "is_used": 0},
		["name", "code_hash", "expires_at", "attempts"],
		as_dict=True,
		order_by="creation desc",
	)
	if not row:
		invalid({"code": "That code has expired."})

	if row.attempts >= C.OTP_MAX_ATTEMPTS:
		frappe.db.set_value("Aqua OTP", row.name, "is_used", 1)
		throttled("Too many wrong attempts. Please request a new code.", code="otp_attempts")

	if frappe.utils.get_datetime(row.expires_at) < frappe.utils.now_datetime():
		invalid({"code": "That code has expired."})

	if row.code_hash != _hash_code(phone, str(code).strip()):
		frappe.db.set_value("Aqua OTP", row.name, "attempts", int(row.attempts) + 1)
		frappe.db.commit()
		invalid({"code": "That code is not right."})

	frappe.db.set_value("Aqua OTP", row.name, "is_used", 1)
	return True
