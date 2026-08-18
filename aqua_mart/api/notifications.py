"""Notification feed and device registration (API_SPEC 5.6, 9.1).

The feed is per-user AND per-role: a seller must never see customer
notifications, which falls out of scoping every read to the token's user.
"""

import frappe

from aqua_mart.services.guard import aqua_endpoint, current_user, request_body
from aqua_mart.services.response import invalid, no_content, not_found, ok, paginate
from aqua_mart.services.serializers import serialize_notification

# The client pins these to the top and tints them - they need action.
PINNED_KINDS = ("complaint", "stockLow", "khataDue")


@frappe.whitelist()
@aqua_endpoint()
def feed(**kwargs):
	"""GET /notifications"""
	user = current_user()
	limit, offset = paginate(frappe.local.form_dict)

	names = frappe.get_all(
		"Aqua Notification",
		filters={"user": user},
		order_by="creation desc",
		limit_page_length=limit,
		limit_start=offset,
		pluck="name",
	)
	rows = [serialize_notification(name) for name in names]

	# Pinned kinds first, then chronological - matching how the client
	# renders them, so an unchanged client and a paged feed still agree.
	rows.sort(key=lambda r: (r["kind"] not in PINNED_KINDS,))
	return ok(rows)


@frappe.whitelist()
@aqua_endpoint()
def read_all(**kwargs):
	"""POST /notifications/read-all"""
	user = current_user()
	frappe.db.set_value(
		"Aqua Notification", {"user": user, "is_read": 0}, "is_read", 1, update_modified=False
	)
	return no_content()


@frappe.whitelist()
@aqua_endpoint()
def mark_read(id=None, **kwargs):
	"""PATCH /notifications/{id}"""
	user = current_user()
	row = frappe.db.get_value("Aqua Notification", id, ["name", "user"], as_dict=True)
	if not row or row.user != user:
		not_found("We could not find that notification.")

	frappe.db.set_value("Aqua Notification", id, "is_read", 1)
	return ok(serialize_notification(id))


@frappe.whitelist()
@aqua_endpoint()
def register_device(**kwargs):
	"""POST /notifications/devices - one user may have several devices."""
	user = current_user()
	body = request_body()

	token = (body.get("fcm_token") or "").strip()
	if not token:
		invalid({"fcm_token": "Missing device token."})

	# A token may move between accounts when a phone is handed on, so it is
	# claimed by the current user rather than duplicated.
	existing = frappe.db.get_value("Aqua Device", {"fcm_token": token}, "name")
	values = {
		"user": user,
		"fcm_token": token,
		"platform": body.get("platform"),
		"app_version": body.get("app_version"),
	}

	if existing:
		frappe.db.set_value("Aqua Device", existing, values)
	else:
		frappe.get_doc({"doctype": "Aqua Device", **values}).insert(ignore_permissions=True)

	return no_content()


@frappe.whitelist()
@aqua_endpoint()
def unregister_device(**kwargs):
	"""DELETE /notifications/devices - called on logout."""
	user = current_user()
	body = request_body()
	token = (body.get("fcm_token") or "").strip()

	filters = {"user": user}
	if token:
		filters["fcm_token"] = token

	for name in frappe.get_all("Aqua Device", filters=filters, pluck="name"):
		frappe.delete_doc("Aqua Device", name, ignore_permissions=True, force=True)

	return no_content()
