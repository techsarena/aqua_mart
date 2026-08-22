from frappe import _


def get_data():
	return {
		"fieldname": "order_status_log",
		"internal_links": {
			"Aqua Order": "order",
		},
		"transactions": [
			{"label": _("Order"), "items": ["Aqua Order"]},
		],
	}
