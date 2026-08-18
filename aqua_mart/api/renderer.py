"""The /v1 request handler (API_SPEC 1.1).

The client calls clean REST paths - `/v1/orders/ORD-1/cancel` - while Frappe
serves whitelisted methods at /api/method/<dotted.path>. Everything under
/v1 is claimed here, dispatched on path + verb, and written straight out as
JSON. The nginx rewrite in 1.1 is therefore OPTIONAL: the documented paths
work against a bare bench.

WHY THIS RUNS FROM before_request RATHER THAN page_renderer
-----------------------------------------------------------
frappe/app.py routes only GET, HEAD and POST into the website stack; every
other verb raises NotFound before a page_renderer is ever consulted. The
spec needs PATCH (/auth/profile), PUT (/addresses/{id}) and DELETE
(/addresses/{id}, /notifications/devices), so the API is served from the
`before_request` hook - which runs inside init_request, ahead of that method
check - and the finished response is raised as a werkzeug exception so
frappe returns it untouched.
"""

import json

import frappe
from werkzeug.exceptions import HTTPException
from werkzeug.wrappers import Response

from aqua_mart.api.router import resolve

PREFIX = "v1"


class AquaResponse(HTTPException):
	"""A finished HTTP response, raised so frappe returns it as-is.

	frappe/app.py answers `isinstance(e, HTTPException)` with
	`e.get_response(...)` verbatim, which is how a before_request hook can
	respond to a request outright.
	"""

	def __init__(self, response):
		super().__init__("aqua response")
		self.response = response

	def get_response(self, environ=None, scope=None):
		return self.response


def serve_api():
	"""before_request hook: answer /v1/* and let everything else through."""
	request = getattr(frappe.local, "request", None)
	if not request:
		return

	path = (request.path or "").strip("/ ")
	if path != PREFIX and not path.startswith(f"{PREFIX}/"):
		return

	response = AquaApiHandler(path).render()

	# frappe rolls the transaction back after an HTTPException, so anything
	# the handler wrote has to be committed before the response is raised.
	try:
		frappe.db.commit()
	except Exception:
		frappe.log_error(title="Aqua Mart commit failed")

	raise AquaResponse(response)


class AquaApiHandler:
	"""Dispatches one /v1 request and builds its JSON response."""

	def __init__(self, path):
		self.path = (path or "").strip("/ ")

	def render(self):
		api_path = "/" + self.path[len(PREFIX) :].strip("/")
		method = frappe.local.request.method.upper()

		# CORS preflight - the app is a mobile client on another origin.
		if method == "OPTIONS":
			return self._respond({}, 204)

		handler, params = resolve(method, api_path)

		if handler is None:
			if params.get("_method_not_allowed"):
				return self._respond(
					{"message": "That action is not supported here.", "code": "method_not_allowed"},
					405,
				)
			return self._respond(
				{"message": "We could not find that.", "code": "unknown_route"}, 404
			)

		# Query parameters are NOT in form_dict here. Frappe populates it from
		# the query string later in its own request pipeline, which never runs
		# for a before_request route - so `?address_id=`, `?q=`, `?limit=` and
		# every other query parameter arrived empty and each handler silently
		# fell back to its default. Merge them in before anything reads them.
		try:
			for key, value in (frappe.local.request.args or {}).items():
				frappe.local.form_dict.setdefault(key, value)
		except Exception:
			pass

		# Snapshot the client-supplied body BEFORE path parameters are merged
		# in, so request_body() can never mistake a path segment for a field
		# the client sent.
		frappe.local.aqua_body = dict(frappe.local.form_dict)

		# Path parameters then join form_dict so handlers read them exactly
		# like query parameters.
		frappe.local.form_dict.update(params)

		try:
			handler(**params)
		except frappe.ValidationError:
			frappe.db.rollback()
			frappe.local.response["http_status_code"] = 400
			frappe.local.response["message"] = "Please check the details you entered."
		except Exception:
			frappe.db.rollback()
			frappe.log_error(title="Aqua Mart API error")
			frappe.clear_last_message()
			frappe.local.response["http_status_code"] = 500
			frappe.local.response["message"] = "Something went wrong on our side. Please try again."

		return self._build()

	def _build(self):
		"""Turn frappe.local.response into the documented envelope (1.2, 1.3)."""
		response = frappe.local.response
		status = response.get("http_status_code") or 200

		if status == 204:
			return self._respond(None, 204)

		payload = {}
		# `data` is the success envelope; the auth endpoints additionally put
		# their tokens at the top level (4.2) and those keys are carried
		# through untouched.
		if "data" in response:
			payload["data"] = response.get("data")

		# `is_new_user` decides where the client sends someone after OTP: a
		# returning account goes straight to its role's home, a brand-new one
		# to "Who are you?". It was being computed and then dropped here.
		for key in (
			"message",
			"code",
			"errors",
			"access_token",
			"refresh_token",
			"user",
			"is_new_user",
		):
			if key in response and response.get(key) is not None:
				payload[key] = response.get(key)

		return self._respond(payload, status)

	def _respond(self, payload, status):
		body = b"" if payload is None else json.dumps(payload, default=str).encode()
		response = Response(body, status=status, mimetype="application/json")
		response.headers["Access-Control-Allow-Origin"] = frappe.local.request.headers.get(
			"Origin", "*"
		)
		response.headers["Access-Control-Allow-Credentials"] = "true"
		response.headers["Access-Control-Allow-Headers"] = (
			"Authorization, Content-Type, Idempotency-Key, Accept-Language, X-Frappe-Site-Name"
		)
		response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
		return response
