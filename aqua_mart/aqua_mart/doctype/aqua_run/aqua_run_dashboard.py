from frappe import _


def get_data():
	return {
		"fieldname": "run",
		"internal_links": {
			"Aqua Rider Profile": "rider",
			"Aqua Seller Profile": "seller",
		},
		"transactions": [
			{"label": _("Stops"), "items": ["Aqua Run Stop"]},
			{"label": _("Parties"), "items": ["Aqua Rider Profile", "Aqua Seller Profile"]},
		],
	}
