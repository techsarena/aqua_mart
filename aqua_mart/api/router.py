"""Path dispatcher (API_SPEC 1.1, 10.2).

The client sees clean REST paths - `/v1/orders/ORD-1/cancel` - while Frappe
serves whitelisted methods at /api/method/<dotted.path>. Rather than making
every endpoint a separately-whitelisted dotted name (which cannot express
path parameters or HTTP verbs), everything under /v1 lands on `handle`,
which matches the path against the table below.

`website_route_rules` in hooks.py routes /v1/<path> here, so the nginx
rewrite in 1.1 is optional - the paths work as documented either way.
"""

import re

import frappe

from aqua_mart.api import (
	addresses,
	auth,
	catalog,
	empties,
	notifications,
	orders,
	rider,
	seller,
	wallet,
)
from aqua_mart.services.response import fail

# (method, pattern) -> handler. Patterns use {param} placeholders.
ROUTES = [
	# --- auth (1-6) ---
	("POST", "/auth/otp/request", auth.otp_request),
	("POST", "/auth/otp/verify", auth.otp_verify),
	("POST", "/auth/refresh", auth.refresh),
	("POST", "/auth/logout", auth.logout),
	("GET", "/auth/me", auth.me),
	("PATCH", "/auth/profile", auth.profile),
	# --- catalogue (7-11) ---
	("GET", "/sellers/nearby", catalog.sellers_nearby),
	("GET", "/sellers/search", catalog.sellers_search),
	("GET", "/sellers/{id}/bottles", catalog.seller_bottles),
	("GET", "/sellers/{id}", catalog.seller_detail),
	("GET", "/sellers", catalog.sellers_list),
	# --- orders (12-19) ---
	("POST", "/orders/{id}/cancel", orders.cancel),
	("POST", "/orders/{id}/rating", orders.rate),
	("POST", "/orders/{id}/report", orders.report),
	("POST", "/orders/{id}/reorder", orders.reorder),
	("GET", "/orders/{id}/tracking", orders.tracking),
	("GET", "/orders/{id}", orders.detail),
	("GET", "/orders", orders.list_orders),
	("POST", "/orders", orders.place),
	# --- addresses (20-24) ---
	("POST", "/addresses/{id}/default", addresses.make_default),
	("GET", "/addresses", addresses.list_addresses),
	("POST", "/addresses", addresses.create),
	("PUT", "/addresses/{id}", addresses.update),
	("DELETE", "/addresses/{id}", addresses.delete),
	# --- wallet & payments (25-30) ---
	("GET", "/wallet/top-up/{id}", wallet.topup_status),
	("POST", "/wallet/top-up", wallet.top_up),
	("GET", "/wallet/transactions", wallet.transactions),
	("GET", "/wallet", wallet.get_wallet),
	("POST", "/payment-methods/cards", wallet.save_card),
	("GET", "/khata", wallet.khata),
	# --- empties (31-33) ---
	("GET", "/empties", empties.list_empties),
	("POST", "/empties/return", empties.return_empties),
	("POST", "/empties/pickup", empties.pickup_empties),
	# --- notifications (34-38) ---
	("GET", "/notifications", notifications.feed),
	("POST", "/notifications/read-all", notifications.read_all),
	("POST", "/notifications/devices", notifications.register_device),
	("DELETE", "/notifications/devices", notifications.unregister_device),
	("PATCH", "/notifications/{id}", notifications.mark_read),
	# --- seller (39-61) ---
	("POST", "/seller/register", seller.register),
	("POST", "/seller/documents", seller.documents),
	("POST", "/seller/verification", seller.submit_verification),
	("GET", "/seller/verification", seller.verification_status),
	("GET", "/seller/dashboard", seller.dashboard),
	("POST", "/seller/open", seller.set_open),
	("GET", "/seller/orders", seller.orders),
	("POST", "/seller/orders/{id}/accept", seller.accept_order),
	("POST", "/seller/orders/{id}/advance", seller.advance_order),
	("POST", "/seller/orders/{id}/decline", seller.decline_order),
	("POST", "/seller/orders/{id}/assign", seller.assign_rider),
	("GET", "/seller/inventory", seller.inventory),
	("PUT", "/seller/inventory/{id}", seller.update_bottle),
	("DELETE", "/seller/inventory/{id}", seller.delete_bottle),
	("GET", "/seller/riders/code", seller.rider_code),
	("GET", "/seller/riders/invitations", seller.rider_invitations),
	("POST", "/seller/riders/invitations/{id}/resend", seller.resend_invitation),
	("DELETE", "/seller/riders/invitations/{id}", seller.cancel_invitation),
	("POST", "/seller/riders/invite", seller.invite_rider),
	("GET", "/seller/riders", seller.riders),
	("GET", "/seller/disputes/{id}", seller.dispute_detail),
	("POST", "/seller/disputes/{id}/resolve", seller.resolve_dispute),
	("GET", "/seller/disputes", seller.disputes),
	("GET", "/seller/service-area", seller.get_service_area),
	("PUT", "/seller/service-area", seller.set_service_area),
	("GET", "/seller/hours", seller.get_hours),
	("PUT", "/seller/hours", seller.set_hours),
	("GET", "/seller/payouts/{id}", seller.payout_detail),
	("GET", "/seller/payouts", seller.payouts),
	# --- rider (62-70) ---
	("GET", "/rider/run", rider.run),
	("POST", "/rider/stops/{id}/complete", rider.complete_stop),
	("POST", "/rider/stops/{id}/fail", rider.fail_stop),
	("POST", "/rider/cash-handover", rider.cash_handover),
	("GET", "/rider/earnings", rider.earnings),
	("GET", "/rider/invitations", rider.invitations),
	("POST", "/rider/invitations/{id}", rider.respond_invitation),
	("GET", "/rider/seller-codes/{code}", rider.seller_code),
	("POST", "/rider/application", rider.application),
]


def _compile(pattern):
	"""'/orders/{id}/cancel' -> a regex capturing `id`."""
	regex = re.sub(r"\{(\w+)\}", r"(?P<\1>[^/]+)", pattern)
	return re.compile(f"^{regex}/?$")


COMPILED = [(method, _compile(pattern), handler, pattern) for method, pattern, handler in ROUTES]


def resolve(method, path):
	"""Find the handler for this method+path, and the path parameters."""
	matched_path = False
	for route_method, regex, handler, pattern in COMPILED:
		match = regex.match(path)
		if not match:
			continue
		matched_path = True
		if route_method == method:
			return handler, match.groupdict()

	# The path exists but not for this verb - 405 is more honest than 404.
	return (None, {"_method_not_allowed": True}) if matched_path else (None, {})


@frappe.whitelist(allow_guest=True)
def handle(**kwargs):
	"""Entry point for every /v1 path."""
	request = frappe.local.request
	method = request.method.upper()

	path = frappe.local.form_dict.get("aqua_path") or ""
	path = "/" + path.strip("/")

	handler, params = resolve(method, path)

	if handler is None:
		if params.get("_method_not_allowed"):
			return fail("That action is not supported here.", 405, code="method_not_allowed")
		return fail("We could not find that.", 404, code="unknown_route")

	# Path parameters are merged into form_dict so handlers read them the
	# same way they read query parameters.
	frappe.local.form_dict.update(params)
	return handler(**params)
