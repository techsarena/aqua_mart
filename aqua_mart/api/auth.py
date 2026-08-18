"""Auth endpoints (API_SPEC 4).

Phone + 6-digit SMS OTP. No passwords anywhere.

Envelope warning: /auth/otp/verify and /auth/refresh return their keys at the
TOP LEVEL, not under "data" (4.2). The client throws a parse error if
access_token / refresh_token / user are missing. This is deliberate - do not
"normalise" it.
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services import tokens
from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.phone import issue_otp, require_phone, verify_otp
from aqua_mart.services.response import invalid, no_content, ok, unauthorised
from aqua_mart.services.serializers import serialize_user


@frappe.whitelist(allow_guest=True)
@aqua_endpoint()
def otp_request(**kwargs):
	"""POST /auth/otp/request"""
	body = request_body()
	phone = require_phone(body.get("phone"))

	resend_after = issue_otp(phone)

	# Never reveal whether the number is registered - same response either way.
	return ok({"resend_after_seconds": resend_after})


@frappe.whitelist(allow_guest=True)
@aqua_endpoint()
def otp_verify(**kwargs):
	"""POST /auth/otp/verify - the account-creating call.

	Handles both sign-in and sign-up. `full_name` and `role` are used ONLY
	when the account does not exist yet: a returning seller must not be
	downgraded to customer because the app sent a default (4.2).
	"""
	body = request_body()
	phone = require_phone(body.get("phone"))
	verify_otp(phone, body.get("code"))

	profile_name = frappe.db.get_value("Aqua Profile", {"phone": phone}, "name")

	if profile_name:
		profile = frappe.get_doc("Aqua Profile", profile_name)
		# An abandoned first registration must resume its remaining steps rather
		# than being treated as a returning, fully registered account.
		is_new_user = not bool(profile.is_profile_complete)
	else:
		role = body.get("role")
		if role not in C.ROLES:
			role = C.ROLE_CUSTOMER
		profile = _create_account(phone, body.get("full_name"), role)
		is_new_user = True

	pair = tokens.issue_pair(profile.user, profile.role)

	# Top-level keys, NOT under "data".
	frappe.local.response["http_status_code"] = 200
	frappe.local.response.pop("message", None)
	frappe.local.response["access_token"] = pair["access_token"]
	frappe.local.response["refresh_token"] = pair["refresh_token"]
	frappe.local.response["is_new_user"] = is_new_user
	frappe.local.response["user"] = serialize_user(profile)
	return None


def _create_account(phone, full_name, role):
	"""Create the User + Aqua Profile pair for a new phone number."""
	full_name = (full_name or "").strip() or "Aqua User"
	# Frappe needs an email-shaped username; the phone is the real identity.
	email = f"{phone.lstrip('+')}@aqua.local"

	user = frappe.get_doc(
		{
			"doctype": "User",
			"email": email,
			"first_name": full_name,
			"username": phone.lstrip("+"),
			"mobile_no": phone,
			"send_welcome_email": 0,
			"user_type": "Website User",
			"enabled": 1,
		}
	).insert(ignore_permissions=True)

	frappe_role = C.FRAPPE_ROLE.get(role)
	if frappe_role and frappe.db.exists("Role", frappe_role):
		user.add_roles(frappe_role)

	profile = frappe.get_doc(
		{
			"doctype": "Aqua Profile",
			"user": user.name,
			"phone": phone,
			"role": role,
			"full_name": full_name,
			# The profile is NOT complete until PATCH /auth/profile lands (4.6).
			"is_profile_complete": 0,
			"is_verified": 0,
		}
	).insert(ignore_permissions=True)

	return profile


@frappe.whitelist(allow_guest=True)
@aqua_endpoint()
def refresh(**kwargs):
	"""POST /auth/refresh - top level, like verify.

	Must never answer 401 for a reason the client can't fix by refreshing;
	a failure here wipes tokens and signs the user out (1.4).
	"""
	body = request_body()
	token = body.get("refresh_token")
	if not token:
		unauthorised("Please sign in again.", code="missing_refresh_token")

	pair = tokens.rotate(token)

	frappe.local.response["http_status_code"] = 200
	frappe.local.response.pop("message", None)
	frappe.local.response["access_token"] = pair["access_token"]
	frappe.local.response["refresh_token"] = pair["refresh_token"]
	return None


@frappe.whitelist()
@aqua_endpoint()
def me(**kwargs):
	"""GET /auth/me - on the critical path to first paint, keep it fast."""
	user = current_user()
	profile = _profile_for(user)
	return ok(serialize_user(profile))


@frappe.whitelist()
@aqua_endpoint()
def profile(**kwargs):
	"""PATCH /auth/profile - the FINAL sign-up step (4.4, 4.6)."""
	user = current_user()
	doc = _profile_for(user)
	body = request_body()

	errors = {}
	requested_role = None

	if "full_name" in body:
		full_name = (body.get("full_name") or "").strip()
		if not full_name:
			errors["full_name"] = "Please enter your name."
		else:
			doc.full_name = full_name

	if "gender" in body and body.get("gender"):
		gender = body.get("gender")
		if gender not in C.GENDERS:
			errors["gender"] = "Choose one of the options."
		else:
			doc.gender = gender

	if "date_of_birth" in body:
		dob = body.get("date_of_birth")
		if dob in (None, ""):
			doc.date_of_birth = None
		else:
			parsed = frappe.utils.getdate(str(dob)[:10])
			if not parsed:
				errors["date_of_birth"] = "Enter a valid date."
			else:
				doc.date_of_birth = parsed

	# OTP creates a provisional customer account because the visible flow asks
	# for the role afterwards. The role may therefore be finalized exactly once,
	# while that profile is still incomplete. Completed accounts are immutable.
	if not doc.is_profile_complete and "role" in body:
		requested_role = body.get("role")
		if requested_role not in C.ROLES:
			errors["role"] = "Choose one of the account types."

	if errors:
		invalid(errors)

	if requested_role and requested_role != doc.role:
		_set_initial_role(doc, requested_role)

	doc.is_profile_complete = 1
	doc.save(ignore_permissions=True)

	if doc.full_name:
		frappe.db.set_value("User", user, "first_name", doc.full_name)

	if doc.role == C.ROLE_CUSTOMER:
		from aqua_mart.services.wallet import get_wallet

		get_wallet(user)

	return ok(serialize_user(doc))


def _set_initial_role(profile, role):
	"""Finalize a provisional profile's app role and Frappe role together."""
	profile.role = role

	user = frappe.get_doc("User", profile.user)
	app_roles = set(C.FRAPPE_ROLE.values())
	user.set("roles", [row for row in user.roles if row.role not in app_roles])

	frappe_role = C.FRAPPE_ROLE.get(role)
	if frappe_role and frappe.db.exists("Role", frappe_role):
		user.append("roles", {"role": frappe_role})
	user.save(ignore_permissions=True)


@frappe.whitelist()
@aqua_endpoint()
def logout(**kwargs):
	"""POST /auth/logout - revoke refresh tokens and drop this device (4.5)."""
	user = current_user()
	tokens.revoke_all(user)

	body = request_body()
	fcm_token = body.get("fcm_token")
	if fcm_token:
		for name in frappe.get_all(
			"Aqua Device", filters={"user": user, "fcm_token": fcm_token}, pluck="name"
		):
			frappe.delete_doc("Aqua Device", name, ignore_permissions=True, force=True)

	return no_content()


def _profile_for(user):
	name = frappe.db.get_value("Aqua Profile", {"user": user}, "name")
	if not name:
		unauthorised("Please sign in again.", code="no_profile")
	return frappe.get_doc("Aqua Profile", name)
