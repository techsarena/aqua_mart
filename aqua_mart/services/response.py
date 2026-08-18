"""Response envelope helpers (API_SPEC 1.2, 1.3, 10.3).

Frappe wraps whitelisted returns in {"message": ...}. The client wants the
payload under "data" at the top level, so every handler routes through `ok`,
which sets "data" and clears "message". Errors go through `fail` (or one of
the typed raisers) which set "message" plus the optional "code"/"errors".
"""

import frappe

from aqua_mart.services.constants import DEFAULT_LIMIT, MAX_LIMIT


class AquaError(Exception):
	"""An error carrying an HTTP status and a user-facing sentence.

	Raised anywhere in the service layer; converted to the wire shape by the
	`aqua_endpoint` decorator, so handlers never format errors themselves.
	"""

	def __init__(self, message, status=400, code=None, errors=None):
		super().__init__(message)
		self.message = message
		self.status = status
		self.code = code
		self.errors = errors


def ok(data, status=200):
	"""Emit {"data": ...} at the top level and suppress Frappe's "message"."""
	frappe.local.response["http_status_code"] = status
	frappe.local.response["data"] = data
	frappe.local.response.pop("message", None)
	return None


def no_content(status=204):
	"""204 with an empty body - used by the many endpoints that return nothing."""
	frappe.local.response["http_status_code"] = status
	frappe.local.response.pop("message", None)
	frappe.local.response.pop("data", None)
	return None


def fail(message, status=400, code=None, errors=None):
	frappe.local.response["http_status_code"] = status
	frappe.local.response["message"] = message
	frappe.local.response.pop("data", None)
	if code:
		frappe.local.response["code"] = code
	if errors:
		frappe.local.response["errors"] = errors
	return None


# --- typed raisers --------------------------------------------------------
# 401 vs 403 matters enormously (1.3): 401 makes the client silently refresh
# and replay, 403 signs the user out. Never use 403 for an expired token.


def bad_request(message, code=None):
	raise AquaError(message, 400, code=code)


def unauthorised(message="Please sign in again.", code=None):
	raise AquaError(message, 401, code=code)


def forbidden(message="You do not have access to this.", code=None):
	raise AquaError(message, 403, code=code)


def not_found(message="We could not find that.", code=None):
	raise AquaError(message, 404, code=code)


def conflict(message, code=None):
	raise AquaError(message, 409, code=code)


def invalid(errors, message="Please check the details you entered."):
	"""422 - per-field validation errors painted onto the form inputs."""
	raise AquaError(message, 422, code="validation_error", errors=errors)


def throttled(message="Too many attempts. Please wait a little and try again.", code=None):
	raise AquaError(message, 429, code=code)


def paginate(kwargs):
	"""Read ?limit=&offset= with the spec's defaults and ceiling (1.8)."""
	try:
		limit = int(kwargs.get("limit") or DEFAULT_LIMIT)
	except (TypeError, ValueError):
		limit = DEFAULT_LIMIT
	try:
		offset = int(kwargs.get("offset") or 0)
	except (TypeError, ValueError):
		offset = 0

	limit = max(1, min(limit, MAX_LIMIT))
	offset = max(0, offset)
	return limit, offset
