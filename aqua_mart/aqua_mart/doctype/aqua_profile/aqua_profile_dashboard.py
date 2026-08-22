from frappe import _


def get_data():
	"""Aqua Profile is named CUST-####, but no document stores that name -- every
	customer-owned record links to the User (email) instead. Dashboard counts are
	always filtered by the current document's `name`, so the customer graph lives on
	the User dashboard (see aqua_mart.overrides.user_dashboard) rather than here."""
	return {
		"fieldname": "customer",
		"transactions": [],
	}
