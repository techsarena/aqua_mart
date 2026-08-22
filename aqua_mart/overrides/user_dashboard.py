from frappe import _


def get_data(data=None):
	"""Attach the Aqua Mart customer graph to the User form.

	Every customer-owned record links to the User (email) rather than to the
	CUST-#### Aqua Profile name, so the connections belong here. Merges into
	whatever Frappe and other apps already contribute to the User dashboard.
	"""
	data = data or {}

	data.setdefault("fieldname", "user")
	data.setdefault("non_standard_fieldnames", {}).update(
		{
			"Aqua Address": "customer",
			"Aqua Dispute": "customer",
			"Aqua Empty Holding": "customer",
			"Aqua Khata": "customer",
			"Aqua Order": "customer",
			"Aqua Order Status Log": "actor",
			"Aqua Top Up": "customer",
			"Aqua Wallet": "customer",
			"Aqua Wallet Transaction": "customer",
		}
	)

	data.setdefault("transactions", []).extend(
		[
			{"label": _("Aqua Profiles"), "items": ["Aqua Profile", "Aqua Seller Profile", "Aqua Rider Profile"]},
			{"label": _("Aqua Orders"), "items": ["Aqua Order", "Aqua Dispute", "Aqua Order Status Log"]},
			{"label": _("Aqua Addresses"), "items": ["Aqua Address"]},
			{"label": _("Aqua Wallet"), "items": ["Aqua Wallet", "Aqua Wallet Transaction", "Aqua Top Up"]},
			{"label": _("Aqua Ledger"), "items": ["Aqua Khata", "Aqua Empty Holding"]},
			{"label": _("Aqua Devices"), "items": ["Aqua Device", "Aqua Notification", "Aqua Refresh Token"]},
		]
	)

	return data
