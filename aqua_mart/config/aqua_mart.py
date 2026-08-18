"""Desk module listing for Aqua Mart."""

from frappe import _


def get_data():
	return [
		{
			"label": _("Settings"),
			"icon": "octicon octicon-settings",
			"items": [
				{
					"type": "doctype",
					"name": "Aqua Settings",
					"label": _("Aqua Settings"),
					"description": _("OTP delivery, token lifetimes, commission and deposits."),
					"onboard": 1,
				}
			],
		},
		{
			"label": _("Sellers & Riders"),
			"icon": "octicon octicon-organization",
			"items": [
				{"type": "doctype", "name": "Aqua Seller Profile", "onboard": 1},
				{"type": "doctype", "name": "Aqua Rider Profile"},
				{"type": "doctype", "name": "Aqua Bottle"},
				{"type": "doctype", "name": "Aqua Rider Invite Code"},
			],
		},
		{
			"label": _("Operations"),
			"icon": "octicon octicon-package",
			"items": [
				{"type": "doctype", "name": "Aqua Order", "onboard": 1},
				{"type": "doctype", "name": "Aqua Run"},
				{"type": "doctype", "name": "Aqua Run Stop"},
				{"type": "doctype", "name": "Aqua Dispute"},
			],
		},
		{
			"label": _("Money"),
			"icon": "octicon octicon-credit-card",
			"items": [
				{"type": "doctype", "name": "Aqua Wallet"},
				{"type": "doctype", "name": "Aqua Wallet Transaction"},
				{"type": "doctype", "name": "Aqua Top Up"},
				{"type": "doctype", "name": "Aqua Payout"},
				{"type": "doctype", "name": "Aqua Khata"},
			],
		},
	]
