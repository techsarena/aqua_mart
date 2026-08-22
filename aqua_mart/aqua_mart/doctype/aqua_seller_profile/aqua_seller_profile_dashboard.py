from frappe import _


def get_data():
	return {
		"fieldname": "seller",
		"non_standard_fieldnames": {
			"User": "name",
		},
		"transactions": [
			{"label": _("Catalog"), "items": ["Aqua Bottle"]},
			{"label": _("Orders"), "items": ["Aqua Order", "Aqua Dispute"]},
			{"label": _("Delivery"), "items": ["Aqua Run", "Aqua Rider Profile"]},
			{
				"label": _("Riders Onboarding"),
				"items": ["Aqua Rider Invitation", "Aqua Rider Invite Code"],
			},
			{"label": _("Ledger"), "items": ["Aqua Khata", "Aqua Empty Holding", "Aqua Payout"]},
		],
	}
