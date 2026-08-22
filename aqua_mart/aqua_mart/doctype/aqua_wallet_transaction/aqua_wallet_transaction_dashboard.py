from frappe import _


def get_data():
	return {
		"fieldname": "wallet_transaction",
		"internal_links": {
			"Aqua Wallet": "wallet",
		},
		"transactions": [
			{"label": _("Wallet"), "items": ["Aqua Wallet"]},
		],
	}
