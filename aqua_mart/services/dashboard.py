"""The seller's Today figures (API_SPEC 6.2).

The sync fields are FLAT, not nested - the client assembles them into its
own ErpSyncState. `sync_pending` is the honest signal that the app's numbers
and the seller's books have drifted, so it is read from the profile rather
than hard-coded to zero.
"""

import frappe

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_settings
from aqua_mart.services import constants as C
from aqua_mart.services.serializers import compute_is_open, iso


def build_dashboard(seller_name):
	seller = frappe.get_doc("Aqua Seller Profile", seller_name)
	today = frappe.utils.nowdate()
	day_start = f"{today} 00:00:00"

	orders_today = frappe.db.count(
		"Aqua Order", {"seller": seller_name, "placed_at": [">=", day_start]}
	)
	delivered = frappe.db.count(
		"Aqua Order",
		{"seller": seller_name, "status": C.DELIVERED, "placed_at": [">=", day_start]},
	)
	pending_count = frappe.db.count(
		"Aqua Order", {"seller": seller_name, "status": C.PENDING}
	)

	return {
		"orders_today": orders_today,
		"delivered": delivered,
		"earned": _earned_today(seller_name, day_start),
		"is_open": compute_is_open(seller),
		"pending_count": pending_count,
		"low_stock_label": low_stock_label(seller_name),
		"sync_online": bool(seller.sync_online),
		"sync_pending": int(seller.sync_pending or 0),
		"last_synced_at": iso(seller.last_synced_at),
	}


def _earned_today(seller_name, day_start):
	"""Today's DELIVERED revenue, in rupees."""
	rows = frappe.get_all(
		"Aqua Order",
		filters={"seller": seller_name, "status": C.DELIVERED, "placed_at": [">=", day_start]},
		pluck="name",
	)
	if not rows:
		return 0

	total = frappe.db.sql(
		"""select coalesce(sum(unit_price * quantity), 0)
		   from `tabAqua Order Line`
		   where parent in %(orders)s""",
		{"orders": rows},
	)[0][0]

	fees = frappe.db.sql(
		"""select coalesce(sum(delivery_fee), 0)
		   from `tabAqua Order` where name in %(orders)s""",
		{"orders": rows},
	)[0][0]

	return int(total or 0) + int(fees or 0)


def low_stock_label(seller_name, threshold=None):
	"""A ready-made sentence, or None (6.2).

	Composed server-side so the threshold logic lives in exactly one place;
	the client prints it verbatim.
	"""
	if threshold is None:
		threshold = int(get_settings().low_stock_threshold)

	rows = frappe.get_all(
		"Aqua Bottle",
		filters={"seller": seller_name, "is_visible": 1, "filled_stock": ["<=", threshold]},
		fields=["bottle_name", "litres", "filled_stock"],
		order_by="filled_stock asc",
	)
	if not rows:
		return None

	first = rows[0]
	label = f"{first.litres}L bottles running low — {int(first.filled_stock)} left in stock"
	if len(rows) > 1:
		label += f" (and {len(rows) - 1} more)"
	return label
