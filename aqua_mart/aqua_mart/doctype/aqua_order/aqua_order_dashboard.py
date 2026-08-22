from frappe import _


def get_data():
	return {
		"fieldname": "order",
		"internal_links": {
			"Aqua Bottle": ["lines", "bottle"],
			"Aqua Address": "address",
			"Aqua Seller Profile": "seller",
			"Aqua Rider Profile": "rider",
		},
		"transactions": [
			{"label": _("Fulfilment"), "items": ["Aqua Run Stop"]},
			{"label": _("Activity"), "items": ["Aqua Order Status Log"]},
			{"label": _("Issues"), "items": ["Aqua Dispute"]},
			{"label": _("Catalog"), "items": ["Aqua Bottle"]},
			{"label": _("Parties"), "items": ["Aqua Seller Profile", "Aqua Rider Profile"]},
			{"label": _("Delivery To"), "items": ["Aqua Address"]},
		],
	}
