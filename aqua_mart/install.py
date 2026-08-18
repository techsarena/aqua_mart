"""Install-time setup for aqua_mart.

The three app roles back the role checks in API_SPEC 2. They are created
here (rather than shipped as fixtures alone) so a fresh site is usable
immediately after `bench install-app aqua_mart`.
"""

import frappe

ROLES = ("Aqua Customer", "Aqua Seller", "Aqua Rider")


def after_install():
	create_roles()


def create_roles():
	for role in ROLES:
		if frappe.db.exists("Role", role):
			continue
		frappe.get_doc(
			{
				"doctype": "Role",
				"role_name": role,
				# App users never touch the desk.
				"desk_access": 0,
			}
		).insert(ignore_permissions=True)
	frappe.db.commit()
