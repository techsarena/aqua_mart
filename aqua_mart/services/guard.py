"""Endpoint decorator + role guards (API_SPEC 2, 10.2, 10.6).

Every handler is wrapped by `aqua_endpoint`, which does three things:

1. turns an AquaError into the documented error envelope
2. turns anything unexpected into a 500 with a sentence a customer can read
   (never a Python traceback string)
3. enforces the role, derived from the token - never from the request body

The actor is always re-derived from the session here. A `seller_id` in a body
is never trusted for authorisation (10.6).
"""

import json
from functools import wraps

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.response import AquaError, fail, forbidden, unauthorised


def aqua_endpoint(role=None, require_approved=True):
	"""Wrap a handler with error translation and role enforcement.

	:param role: one of "customer"/"seller"/"rider", or None for any signed-in
	        user. Guest-allowed endpoints simply don't use this guard's role.
	:param require_approved: for seller/rider, also require the profile to be
	        approved (2). Onboarding endpoints pass False.
	"""

	def decorator(fn):
		@wraps(fn)
		def wrapper(*args, **kwargs):
			try:
				if role:
					_require_role(role, require_approved)
				return fn(*args, **kwargs)
			except AquaError as e:
				return fail(e.message, e.status, code=e.code, errors=e.errors)
			except frappe.DoesNotExistError:
				frappe.clear_last_message()
				return fail("We could not find that.", 404, code="not_found")
			except Exception:
				frappe.log_error(title="Aqua Mart API error")
				frappe.clear_last_message()
				return fail(
					"Something went wrong on our side. Please try again.",
					500,
					code="server_error",
				)

		return wrapper

	return decorator


def current_user():
	"""The signed-in Frappe user, or raise 401 so the client refreshes."""
	user = frappe.session.user
	if not user or user == "Guest":
		unauthorised("Please sign in to continue.")
	return user


def current_role():
	"""The app role of the caller, read from their Aqua Profile."""
	user = current_user()
	role = frappe.db.get_value("Aqua Profile", {"user": user}, "role")
	if not role:
		forbidden("This account is not set up for the app.")
	return role


def _require_role(role, require_approved):
	actual = current_role()
	if actual != role:
		# Wrong role is a genuine authorisation failure -> 403 signs them out.
		forbidden("This account cannot use that part of the app.")

	if role == C.ROLE_SELLER and require_approved:
		require_approved_seller()
	elif role == C.ROLE_RIDER and require_approved:
		require_approved_rider()


def require_approved_seller():
	"""The Aqua Seller Profile of the caller, or 403 pointing at the waiting screen."""
	user = current_user()
	seller = frappe.db.get_value(
		"Aqua Seller Profile",
		{"user": user},
		["name", "verification_status", "is_suspended"],
		as_dict=True,
	)
	if not seller:
		forbidden("Finish setting up your store before you can use this.")
	if seller.is_suspended:
		forbidden("This store has been suspended. Please contact Aqua Mart support.")
	if seller.verification_status != C.APPROVED:
		forbidden("Your store is still being reviewed. We will let you know as soon as it is approved.")
	return seller.name


def require_seller(allow_unapproved=True):
	"""The caller's seller profile name during onboarding (approval not required)."""
	user = current_user()
	name = frappe.db.get_value("Aqua Seller Profile", {"user": user}, "name")
	if not name:
		forbidden("Finish setting up your store before you can use this.")
	return name


def require_approved_rider():
	"""The Aqua Rider Profile of the caller, approved and attached to a seller."""
	user = current_user()
	rider = frappe.db.get_value(
		"Aqua Rider Profile",
		{"user": user},
		["name", "status", "approval_status", "seller"],
		as_dict=True,
	)
	if not rider:
		forbidden("You are not set up as a rider yet.")
	if rider.approval_status != C.APPROVED:
		forbidden("Your account is waiting for the store to approve it.")
	if not rider.seller:
		forbidden("You are not attached to a store yet.")
	return rider.name


def require_rider(allow_unapproved=True):
	"""The caller's rider profile during onboarding (approval not required)."""
	user = current_user()
	name = frappe.db.get_value("Aqua Rider Profile", {"user": user}, "name")
	if not name:
		forbidden("You are not set up as a rider yet.")
	return name


def request_body():
	"""The client-supplied body as a dict, whatever way it arrived.

	The API layer snapshots frappe's parsed form_dict into `aqua_body`
	before merging path parameters into form_dict, so a path segment such as
	{id} can never masquerade as a field the client posted. Falls back to
	parsing the raw body for callers outside the /v1 dispatcher.
	"""
	body = getattr(frappe.local, "aqua_body", None)
	if body:
		return {k: v for k, v in body.items() if k != "cmd"}

	try:
		raw = frappe.local.request.get_data(as_text=True)
		if raw:
			parsed = json.loads(raw)
			if isinstance(parsed, dict):
				return parsed
	except Exception:
		pass

	if getattr(frappe.local, "form_dict", None):
		return {k: v for k, v in frappe.local.form_dict.items() if k != "cmd"}
	return {}
