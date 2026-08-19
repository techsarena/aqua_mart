"""The order transition table - the ONE copy (API_SPEC 5.2, 10.1).

This is enforced from three different roles' endpoints (customer cancel,
seller accept/advance/decline, rider complete/fail). A second copy would
drift, so every transition in the app goes through `transition()` here.

An illegal transition is 409, never 400 (5.2).
"""

import frappe

from aqua_mart.services import constants as C
from aqua_mart.services.response import conflict

# Who may move an order where. Keyed by actor role.
ALLOWED = {
	C.ROLE_SELLER: {
		C.PENDING: (C.ACCEPTED, C.REJECTED_BY_SELLER),
		C.ACCEPTED: (C.PACKED,),
		C.PACKED: (C.ON_THE_WAY,),
		C.ON_THE_WAY: (C.DELIVERED,),
	},
	C.ROLE_CUSTOMER: {
		C.PENDING: (C.CANCELLED_BY_CUSTOMER,),
		C.ACCEPTED: (C.CANCELLED_BY_CUSTOMER,),
		C.PACKED: (C.CANCELLED_BY_CUSTOMER,),
		C.ON_THE_WAY: (C.CANCELLED_BY_CUSTOMER,),
	},
	C.ROLE_RIDER: {
		C.ON_THE_WAY: (C.DELIVERED,),
	},
}

# Sentences the customer reads when they hit a wall.
_BLOCKED = {
	C.DELIVERED: "This order has already been delivered.",
	C.CANCELLED_BY_CUSTOMER: "This order was already cancelled.",
	C.REJECTED_BY_SELLER: "The seller could not take this order.",
}

_STEP_TITLES = {
	C.PENDING: ("Order placed", "sent to the seller"),
	C.ACCEPTED: ("Order confirmed", "seller accepted"),
	C.PACKED: ("Bottles loaded", "sealed and checked"),
	C.ON_THE_WAY: ("On the way", None),
	C.DELIVERED: ("Delivered", "enjoy your water"),
}


def is_terminal(status):
	return status in C.TERMINAL_STATUSES


def next_status(status):
	"""The next step along the happy path, or None at the end."""
	if status not in C.HAPPY_PATH:
		return None
	i = C.HAPPY_PATH.index(status)
	if i + 1 >= len(C.HAPPY_PATH):
		return None
	return C.HAPPY_PATH[i + 1]


def assert_can(order, role, target):
	"""Raise 409 unless `role` may move `order` to `target` right now."""
	current = order.status

	if is_terminal(current):
		conflict(_BLOCKED.get(current, "This order can no longer be changed."), code="order_terminal")

	allowed = ALLOWED.get(role, {}).get(current, ())
	if target not in allowed:
		conflict(
			f"This order is {_human(current)} and cannot be changed that way.",
			code="illegal_transition",
		)


def _human(status):
	return {
		C.PENDING: "still waiting for the seller",
		C.ACCEPTED: "confirmed",
		C.PACKED: "packed",
		C.ON_THE_WAY: "on the way",
	}.get(status, status)


def transition(order, target, role, actor=None, **fields):
	"""Move an order to `target`, log it, and fan out the side effects.

	Every status change in the app funnels through here so the log, the
	socket emit and the notification can never be forgotten at a call site.
	"""
	assert_can(order, role, target)

	# packed -> onTheWay must have a rider. Dispatching an order nobody is
	# carrying is worse than refusing the transition (6.4).
	if target == C.ON_THE_WAY and not order.rider:
		conflict("Assign a rider before sending this order out.", code="rider_required")

	order.status = target
	# Stamped here rather than read off `modified` later: any subsequent edit
	# (a rating, a dispute) moves `modified`, which would silently rewrite
	# when the order was delivered and corrupt the on-time figures.
	if target == C.DELIVERED and not order.delivered_at:
		order.delivered_at = frappe.utils.now_datetime()

	for key, value in fields.items():
		setattr(order, key, value)
	order.save(ignore_permissions=True)

	log(order.name, target, actor=actor)
	return order


def log(order_name, status, actor=None, at=None):
	"""Append a timeline row with a REAL timestamp (5.2 tracking)."""
	title, subtitle = _STEP_TITLES.get(status, (status, None))
	frappe.get_doc(
		{
			"doctype": "Aqua Order Status Log",
			"order": order_name,
			"status": status,
			"at": at or frappe.utils.now_datetime(),
			"actor": actor or frappe.session.user,
			"title": title,
			"subtitle": subtitle,
		}
	).insert(ignore_permissions=True)
