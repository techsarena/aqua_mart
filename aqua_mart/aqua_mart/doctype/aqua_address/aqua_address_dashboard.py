from frappe import _


def get_data():
	return {
		"fieldname": "address",
		"transactions": [
			{"label": _("Orders"), "items": ["Aqua Order"]},
		],
	}
