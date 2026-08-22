from frappe import _


def get_data():
	return {
		"fieldname": "wallet",
		"transactions": [
			{"label": _("Transactions"), "items": ["Aqua Wallet Transaction"]},
		],
	}
