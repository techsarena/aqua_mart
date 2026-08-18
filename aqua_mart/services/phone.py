"""Phone normalisation and OTP (API_SPEC 4.1, 4.2).

Pakistani numbers arrive in every form a user might type. They are stored
E.164 and only E.164, so a number is one account no matter how it was typed.

Delivery and limits are configured in **Aqua Settings**, not here. The code
itself is hashed at rest, never logged outside console mode, and never
returned by the API in any mode (4.1).
"""

import hashlib
import random
import re

import frappe

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_password, get_settings
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
	"""Create a code, rate-limited per Aqua Settings.

	Returns the resend interval the client counts down before re-enabling
	"Resend code". The code itself is NEVER returned - not even in staging.
	"""
	settings = get_settings()

	_enforce_rate_limits(phone, settings)

	code = _generate_code(settings)

	frappe.get_doc(
		{
			"doctype": "Aqua OTP",
			"phone": phone,
			"code_hash": _hash_code(phone, code),
			"expires_at": frappe.utils.add_to_date(
				frappe.utils.now_datetime(), seconds=int(settings.otp_ttl_seconds)
			),
			"attempts": 0,
			"is_used": 0,
		}
	).insert(ignore_permissions=True)

	send_code(phone, code, settings)
	return int(settings.resend_interval_seconds)


def _enforce_rate_limits(phone, settings):
	"""Two limits: a per-hour cap, and a minimum gap between requests (4.1)."""
	now = frappe.utils.now_datetime()

	hour_start = frappe.utils.add_to_date(now, hours=-1)
	recent = frappe.db.count("Aqua OTP", {"phone": phone, "creation": [">", hour_start]})
	if recent >= int(settings.hourly_limit):
		throttled("Too many code requests. Please wait a while and try again.", code="otp_throttled")

	last = frappe.db.get_value(
		"Aqua OTP", {"phone": phone}, "creation", order_by="creation desc"
	)
	if last:
		elapsed = frappe.utils.time_diff_in_seconds(now, last)
		if elapsed < int(settings.resend_interval_seconds):
			throttled(
				"Please wait a moment before asking for another code.", code="otp_resend_too_soon"
			)


def _generate_code(settings):
	"""A cryptographically random 6-digit code, or the fixed development one.

	The fixed code is only honoured in console mode - the controller refuses
	to save it otherwise - so a live site can never pin every OTP to one value.
	"""
	if settings.provider == "console" and settings.use_fixed_dev_code:
		code = (settings.fixed_dev_code or "").strip()
		if code.isdigit() and len(code) == 6:
			return code

	return f"{random.SystemRandom().randint(0, 999999):06d}"


def send_code(phone, code, settings=None):
	"""Deliver the code through whichever provider is configured.

	A delivery failure is logged and swallowed: the code is already stored,
	so a gateway outage must not turn into a 500 on sign-in. The customer
	retries and the resend limit covers the rest.
	"""
	settings = settings or get_settings()

	# An app-level hook still wins, so an integrator can bypass all of this.
	hook = frappe.get_hooks("aqua_sms_sender")
	if hook:
		frappe.get_attr(hook[-1])(phone, code)
		return

	message = f"Your Aqua Mart code is {code}. It expires in {int(settings.otp_ttl_seconds) // 60} minutes."

	try:
		if settings.provider == "whatsapp":
			_send_whatsapp(phone, code, message, settings)
		elif settings.provider == "sms":
			_send_sms(phone, message, settings)
		else:
			_send_console(phone, code)
	except Exception:
		frappe.log_error(title="Aqua Mart OTP delivery failed")


def _send_console(phone, code):
	"""console mode: record the code so the flow is testable without a gateway.

	This is the ONLY place a plaintext code is ever written down, and it is
	never reachable by the app.
	"""
	frappe.log_error(f"OTP for {phone}: {code}", "Aqua Mart OTP (console mode)")


def _send_whatsapp(phone, code, message, settings):
	backend = settings.whatsapp_backend or "meta"

	if backend == "meta":
		_send_whatsapp_meta(phone, code, settings)
	elif backend == "ultramsg":
		_send_whatsapp_ultramsg(phone, message, settings)
	elif backend == "openwaapi":
		_send_whatsapp_openwaapi(phone, message, settings)


def _send_whatsapp_meta(phone, code, settings):
	"""Meta Cloud API, using an approved template.

	The code goes in the body parameter and again in the button parameter,
	which is what an authentication template expects.
	"""
	import requests

	token = get_password("whatsapp_access_token")
	if not token or not settings.whatsapp_phone_number_id:
		return

	version = settings.whatsapp_api_version or "v18.0"
	url = f"https://graph.facebook.com/{version}/{settings.whatsapp_phone_number_id}/messages"

	requests.post(
		url,
		headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
		json={
			"messaging_product": "whatsapp",
			"to": phone.lstrip("+"),
			"type": "template",
			"template": {
				"name": settings.whatsapp_otp_template_name,
				"language": {"code": settings.whatsapp_otp_template_lang or "en"},
				"components": [
					{"type": "body", "parameters": [{"type": "text", "text": code}]},
					{
						"type": "button",
						"sub_type": "url",
						"index": "0",
						"parameters": [{"type": "text", "text": code}],
					},
				],
			},
		},
		timeout=15,
	)


def _send_whatsapp_ultramsg(phone, message, settings):
	import requests

	token = get_password("ultramsg_token")
	if not token or not settings.ultramsg_instance_id:
		return

	base = (settings.ultramsg_base_url or "https://api.ultramsg.com").rstrip("/")
	requests.post(
		f"{base}/{settings.ultramsg_instance_id}/messages/chat",
		data={
			"token": token,
			"to": phone,
			"body": message,
			"priority": settings.ultramsg_priority or 10,
		},
		timeout=15,
	)


def _send_whatsapp_openwaapi(phone, message, settings):
	import requests

	api_key = get_password("openwaapi_api_key")
	if not api_key or not settings.openwaapi_base_url:
		return

	# The base URL is accepted with or without the trailing /api.
	base = (settings.openwaapi_base_url or "").rstrip("/")
	if not base.endswith("/api"):
		base = f"{base}/api"

	requests.post(
		f"{base}/sendText",
		headers={"x-api-key": api_key, "Content-Type": "application/json"},
		json={
			"session": settings.openwaapi_session_id,
			"to": phone.lstrip("+"),
			"text": message,
		},
		timeout=15,
	)


def _send_sms(phone, message, settings):
	backend = settings.sms_backend or "twilio"

	if backend == "twilio":
		_send_sms_twilio(phone, message, settings)
	else:
		_send_sms_generic(phone, message, settings)


def _send_sms_twilio(phone, message, settings):
	import requests

	token = get_password("twilio_auth_token")
	if not token or not settings.twilio_account_sid:
		return

	requests.post(
		f"https://api.twilio.com/2010-04-01/Accounts/{settings.twilio_account_sid}/Messages.json",
		auth=(settings.twilio_account_sid, token),
		data={"To": phone, "From": settings.twilio_from_number, "Body": message},
		timeout=15,
	)


def _send_sms_generic(phone, message, settings):
	"""Any gateway that takes the number and text as parameters."""
	import requests

	if not settings.sms_gateway_url:
		return

	url = (
		settings.sms_gateway_url.replace("{phone}", phone).replace("{message}", message)
	)
	params = {}
	api_key = get_password("sms_gateway_api_key")
	if api_key:
		params["api_key"] = api_key

	requests.get(url, params=params, timeout=15)


# Kept as the old name so any external caller keeps working.
send_sms = send_code


def verify_otp(phone, code):
	"""Consume a code. Wrong/expired -> 422, too many attempts -> 429 (4.2)."""
	if not code or not str(code).strip():
		invalid({"code": "Enter the code we sent you."})

	settings = get_settings()

	row = frappe.db.get_value(
		"Aqua OTP",
		{"phone": phone, "is_used": 0},
		["name", "code_hash", "expires_at", "attempts"],
		as_dict=True,
		order_by="creation desc",
	)
	if not row:
		invalid({"code": "That code has expired."})

	if row.attempts >= int(settings.max_attempts):
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
