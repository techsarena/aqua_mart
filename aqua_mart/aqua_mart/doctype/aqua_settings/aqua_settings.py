# Copyright (c) 2026, Muhammad Saad and contributors
# For license information, please see license.txt

"""Site-wide configuration for the Aqua Mart app.

Everything the API_SPEC leaves to operations lives here rather than in
`services/constants.py`: OTP delivery and limits, token lifetimes, and the
business values Appendix C leaves open (deposit, commission, thresholds).

Read it through `get_settings()` - it is cached, so the hot paths (every OTP
request, every token mint) do not hit the database for it.
"""

import frappe
from frappe.model.document import Document

# Falls back to these when the single doc has never been saved, so a fresh
# site behaves exactly as the spec describes without anyone opening the form.
DEFAULTS = {
	"provider": "console",
	"use_fixed_dev_code": 0,
	"fixed_dev_code": "472901",
	"otp_ttl_seconds": 300,
	"max_attempts": 5,
	"resend_interval_seconds": 30,
	"hourly_limit": 3,
	"whatsapp_backend": "meta",
	"whatsapp_api_version": "v18.0",
	"whatsapp_otp_template_name": "aqua_otp",
	"whatsapp_otp_template_lang": "en",
	"ultramsg_base_url": "https://api.ultramsg.com",
	"ultramsg_priority": 10,
	"sms_backend": "twilio",
	"access_token_ttl_minutes": 60,
	"refresh_token_ttl_days": 60,
	"default_deposit": 300,
	"commission_rate": 10.0,
	"low_stock_threshold": 5,
	"dispute_window_hours": 24,
}

CACHE_KEY = "aqua_settings"


class AquaSettings(Document):
	def validate(self):
		self._validate_positive()
		self._validate_dev_code()
		self._validate_provider_credentials()

	def _validate_positive(self):
		"""A zero TTL or limit silently breaks sign-in, so refuse it here."""
		must_be_positive = (
			("otp_ttl_seconds", "OTP TTL"),
			("max_attempts", "Max Attempts"),
			("hourly_limit", "Hourly Limit"),
			("access_token_ttl_minutes", "Access Token TTL"),
			("refresh_token_ttl_days", "Refresh Token TTL"),
		)
		for fieldname, label in must_be_positive:
			if int(self.get(fieldname) or 0) < 1:
				frappe.throw(frappe._("{0} must be at least 1.").format(label))

		if float(self.commission_rate or 0) < 0 or float(self.commission_rate or 0) > 100:
			frappe.throw(frappe._("Commission Rate must be between 0 and 100."))

	def _validate_dev_code(self):
		"""The fixed code is a development aid; it must still look like a code."""
		if not self.use_fixed_dev_code:
			return

		code = (self.fixed_dev_code or "").strip()
		if not code.isdigit() or len(code) != 6:
			frappe.throw(frappe._("Fixed Dev Code must be exactly 6 digits."))

		if self.provider != "console":
			frappe.throw(
				frappe._("Fixed Dev Code only applies when the provider is console.")
			)

	def _validate_provider_credentials(self):
		"""Refuse a provider that cannot actually send, rather than failing at
		the first sign-in attempt."""
		required = {
			("whatsapp", "meta"): (
				("whatsapp_phone_number_id", "WhatsApp Phone Number ID"),
				("whatsapp_access_token", "WhatsApp Access Token"),
				("whatsapp_otp_template_name", "WhatsApp OTP Template Name"),
			),
			("whatsapp", "ultramsg"): (
				("ultramsg_instance_id", "UltraMsg Instance ID"),
				("ultramsg_token", "UltraMsg Token"),
			),
			("whatsapp", "openwaapi"): (
				("openwaapi_base_url", "OpenWA API Base URL"),
				("openwaapi_api_key", "OpenWA API Key"),
				("openwaapi_session_id", "OpenWA Session ID"),
			),
			("sms", "twilio"): (
				("twilio_account_sid", "Twilio Account SID"),
				("twilio_auth_token", "Twilio Auth Token"),
				("twilio_from_number", "Twilio From Number"),
			),
			("sms", "generic"): (("sms_gateway_url", "SMS Gateway URL"),),
		}

		if self.provider == "whatsapp":
			key = (self.provider, self.whatsapp_backend or "meta")
		elif self.provider == "sms":
			key = (self.provider, self.sms_backend or "twilio")
		else:
			return

		for fieldname, label in required.get(key, ()):
			if not (self.get(fieldname) or "").strip():
				frappe.throw(
					frappe._("{0} is required to send through this provider.").format(label)
				)

	def on_update(self):
		clear_settings_cache()


def clear_settings_cache():
	frappe.cache().delete_value(CACHE_KEY)


def get_settings():
	"""The settings as a plain dict, cached, with defaults filled in.

	Never returns None and never raises when the doc has not been saved -
	callers can read a key unconditionally.
	"""
	cached = frappe.cache().get_value(CACHE_KEY)
	if cached:
		return frappe._dict(cached)

	values = dict(DEFAULTS)
	try:
		doc = frappe.get_cached_doc("Aqua Settings")
		for key in DEFAULTS:
			value = doc.get(key)
			# An unsaved single doc reads back empty; keep the default then.
			if value not in (None, ""):
				values[key] = value

		# Credentials are not in DEFAULTS (they have no sensible default) but
		# still need to reach callers.
		for key in (
			"whatsapp_phone_number_id",
			"ultramsg_instance_id",
			"openwaapi_base_url",
			"openwaapi_session_id",
			"twilio_account_sid",
			"twilio_from_number",
			"sms_gateway_url",
		):
			values[key] = doc.get(key)
	except Exception:
		# A site mid-migration may not have the table yet.
		pass

	frappe.cache().set_value(CACHE_KEY, values, expires_in_sec=300)
	return frappe._dict(values)


def get_password(fieldname):
	"""Read one encrypted credential, or None when it is unset.

	Password fields are not readable from the cached dict, so secrets are
	fetched on demand and never cached.
	"""
	try:
		return frappe.get_doc("Aqua Settings").get_password(fieldname, raise_exception=False)
	except Exception:
		return None
