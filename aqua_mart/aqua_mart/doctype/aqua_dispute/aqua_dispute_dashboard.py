from frappe import _


def get_data():
	return {
		"fieldname": "dispute",
		"internal_links": {
			"Aqua Order": "order",
			"Aqua Seller Profile": "seller",
		},
		"transactions": [
			{"label": _("Order"), "items": ["Aqua Order"]},
			{"label": _("Seller"), "items": ["Aqua Seller Profile"]},
		],
	}
