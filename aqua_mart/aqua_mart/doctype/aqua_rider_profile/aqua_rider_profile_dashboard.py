from frappe import _


def get_data():
	return {
		"fieldname": "rider",
		"transactions": [
			{"label": _("Delivery"), "items": ["Aqua Run", "Aqua Order"]},
		],
	}
