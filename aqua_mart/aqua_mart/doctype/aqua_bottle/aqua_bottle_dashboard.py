from frappe import _


def get_data():
	return {
		"fieldname": "bottle",
		"internal_links": {
			"Aqua Seller Profile": "seller",
		},
		"transactions": [
			{"label": _("Seller"), "items": ["Aqua Seller Profile"]},
		],
	}
