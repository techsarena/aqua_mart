from frappe import _


def get_data():
	return {
		"fieldname": "run_stop",
		"internal_links": {
			"Aqua Run": "run",
			"Aqua Order": "order",
		},
		"transactions": [
			{"label": _("Run"), "items": ["Aqua Run"]},
			{"label": _("Order"), "items": ["Aqua Order"]},
		],
	}
