"""Scheduled jobs (API_SPEC 10.5).

| Job                 | Frequency | Does                                  |
| expire OTPs         | 5 min     | delete codes past TTL                 |
| time out top-ups    | 1 min     | pending > 5 min -> failed             |
| open/close stores   | 5 min     | apply business hours to is_open       |
| khata reminders     | daily     | notify 3 days before due              |
| weekly payouts      | Mon 06:00 | build Aqua Payout per seller          |
| dispute escalation  | hourly    | unsettled past 24 h -> escalate       |
| low-stock alerts    | hourly    | notify sellers under threshold        |
"""

import frappe

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_settings
from aqua_mart.services import constants as C
from aqua_mart.services.notifications import notify


def expire_otps():
	"""Delete codes past their TTL - nothing should linger that can be tried."""
	ttl = int(get_settings().otp_ttl_seconds)
	cutoff = frappe.utils.add_to_date(frappe.utils.now_datetime(), seconds=-ttl)
	for name in frappe.get_all("Aqua OTP", filters={"expires_at": ["<", cutoff]}, pluck="name"):
		frappe.delete_doc("Aqua OTP", name, ignore_permissions=True, force=True)
	frappe.db.commit()


def timeout_topups():
	"""A pending top-up over 5 minutes old is failed, with a reason (5.4)."""
	cutoff = frappe.utils.add_to_date(frappe.utils.now_datetime(), minutes=-5)
	names = frappe.get_all(
		"Aqua Top Up", filters={"status": "pending", "creation": ["<", cutoff]}, pluck="name"
	)
	for name in names:
		frappe.db.set_value(
			"Aqua Top Up",
			name,
			{
				"status": "failed",
				"failure_reason": "You didn't approve the request in time.",
			},
		)
	frappe.db.commit()


def apply_business_hours():
	"""Roll the manual close flag off once a new day's opening time arrives.

	`is_open` itself is computed on read (compute_is_open), so this job only
	has to clear yesterday's manual override.
	"""
	today = frappe.utils.nowdate()
	stale = frappe.get_all(
		"Aqua Seller Profile",
		filters={"manual_close_date": ["<", today]},
		pluck="name",
	)
	for name in stale:
		frappe.db.set_value(
			"Aqua Seller Profile", name, {"manual_close_date": None, "is_open": 1}
		)
	frappe.db.commit()


def khata_reminders():
	"""Nudge customers 3 days before their monthly account falls due."""
	target = frappe.utils.add_days(frappe.utils.nowdate(), 3)
	rows = frappe.get_all(
		"Aqua Khata",
		filters={"is_approved": 1, "due_date": target, "due": [">", 0]},
		fields=["customer", "due", "seller"],
	)
	for row in rows:
		seller_name = frappe.db.get_value("Aqua Seller Profile", row.seller, "business_name")
		notify(
			row.customer,
			"khataDue",
			"Your khata is due soon",
			f"Rs {int(row.due)} due to {seller_name} in 3 days.",
			"/customer/wallet",
		)
	frappe.db.commit()


def escalate_stale_disputes():
	"""Unsettled past the dispute window -> escalate (6.7).

	The seller's rating is protected pending review, and support picks it up.
	The window is configured in Aqua Settings; the spec's default is 24 h.
	"""
	window = int(get_settings().dispute_window_hours)
	cutoff = frappe.utils.add_to_date(frappe.utils.now_datetime(), hours=-window)
	names = frappe.get_all(
		"Aqua Dispute",
		filters={"status": "open", "raised_at": ["<", cutoff]},
		pluck="name",
	)
	for name in names:
		dispute = frappe.get_doc("Aqua Dispute", name)
		dispute.status = "escalated"
		dispute.resolution = "escalate"
		dispute.save(ignore_permissions=True)

		seller_user = frappe.db.get_value("Aqua Seller Profile", dispute.seller, "user")
		notify(
			seller_user,
			"complaint",
			"A complaint was escalated",
			f"{dispute.order_reference} went past {window} hours and is now with Aqua Mart support.",
			f"/seller/disputes/{dispute.name}",
		)
	frappe.db.commit()


def low_stock_alerts():
	"""Tell sellers what is running out, using the same sentence as Today."""
	from aqua_mart.services.dashboard import low_stock_label

	sellers = frappe.get_all(
		"Aqua Seller Profile",
		filters={"verification_status": C.APPROVED, "is_suspended": 0},
		fields=["name", "user"],
	)
	for seller in sellers:
		label = low_stock_label(seller.name)
		if not label:
			continue

		# Once a day per seller - an hourly nag trains people to ignore it.
		key = f"aqua:lowstock:{seller.name}:{frappe.utils.nowdate()}"
		if frappe.cache().get_value(key):
			continue
		frappe.cache().set_value(key, 1, expires_in_sec=86400)

		notify(seller.user, "stockLow", "Stock running low", label, "/seller/inventory")
	frappe.db.commit()


def build_weekly_payouts():
	"""Monday 06:00 - one Aqua Payout per seller for the week just ended.

	The arithmetic must add up exactly as 6.9 states, because a seller who
	checks the maths and finds it wrong is the fastest way to lose them:

	    net_paid = gross_sales
	             + deposits_taken
	             - deposits_refunded
	             - commission
	             - complaint_refunds
	             - cash_collected_by_riders
	"""
	today = frappe.utils.getdate()
	week_end = frappe.utils.add_days(today, -1)
	week_start = frappe.utils.add_days(week_end, -6)

	commission_rate = float(get_settings().commission_rate) / 100.0

	sellers = frappe.get_all(
		"Aqua Seller Profile", filters={"verification_status": C.APPROVED}, pluck="name"
	)

	for seller_name in sellers:
		if frappe.db.exists("Aqua Payout", {"seller": seller_name, "week_start": week_start}):
			continue

		orders = frappe.get_all(
			"Aqua Order",
			filters={
				"seller": seller_name,
				"status": C.DELIVERED,
				"placed_at": ["between", [f"{week_start} 00:00:00", f"{week_end} 23:59:59"]],
			},
			fields=["name", "delivery_fee", "payment_method", "customer"],
		)
		if not orders:
			continue

		order_names = [o.name for o in orders]

		gross = int(
			frappe.db.sql(
				"""select coalesce(sum(unit_price * quantity), 0)
				   from `tabAqua Order Line` where parent in %(orders)s""",
				{"orders": order_names},
			)[0][0]
			or 0
		) + sum(int(o.delivery_fee or 0) for o in orders)

		deposits_taken = int(
			frappe.db.sql(
				"""select coalesce(sum(b.deposit * line.quantity), 0)
				   from `tabAqua Order Line` line
				   join `tabAqua Bottle` b on b.name = line.bottle
				   where line.parent in %(orders)s and line.kind = 'buyNew'""",
				{"orders": order_names},
			)[0][0]
			or 0
		)

		deposits_refunded = int(
			frappe.db.sql(
				"""select coalesce(sum(amount), 0) from `tabAqua Wallet Transaction`
				   where reference_doctype = 'Aqua Empty Holding' and is_credit = 1
				   and at between %(start)s and %(end)s""",
				{"start": f"{week_start} 00:00:00", "end": f"{week_end} 23:59:59"},
			)[0][0]
			or 0
		)

		complaint_refunds = int(
			frappe.db.sql(
				"""select coalesce(sum(amount), 0) from `tabAqua Dispute`
				   where seller = %(seller)s and resolution = 'refund'
				   and resolved_at between %(start)s and %(end)s""",
				{
					"seller": seller_name,
					"start": f"{week_start} 00:00:00",
					"end": f"{week_end} 23:59:59",
				},
			)[0][0]
			or 0
		)

		cash_collected = int(
			frappe.db.sql(
				"""select coalesce(sum(stop.amount_to_collect), 0)
				   from `tabAqua Run Stop` stop
				   where stop.order in %(orders)s and stop.status = 'delivered'""",
				{"orders": order_names},
			)[0][0]
			or 0
		)

		commission = int(round(gross * commission_rate))

		net_paid = (
			gross
			+ deposits_taken
			- deposits_refunded
			- commission
			- complaint_refunds
			- cash_collected
		)

		payout = frappe.get_doc(
			{
				"doctype": "Aqua Payout",
				"seller": seller_name,
				"week_label": _week_label(week_start, week_end),
				"week_start": week_start,
				"week_end": week_end,
				"orders_delivered": len(orders),
				"gross_sales": gross,
				"deposits_taken": deposits_taken,
				"deposits_refunded": deposits_refunded,
				"commission": commission,
				"complaint_refunds": complaint_refunds,
				"cash_collected_by_riders": cash_collected,
				"net_paid": net_paid,
				"is_paid": 0,
			}
		).insert(ignore_permissions=True)

		seller_user = frappe.db.get_value("Aqua Seller Profile", seller_name, "user")
		notify(
			seller_user,
			"payout",
			"Your weekly statement is ready",
			f"{payout.week_label} · Rs {net_paid}",
			"/seller/payouts",
		)

	frappe.db.commit()


def _week_label(start, end):
	"""'11 – 17 Aug'"""
	start = frappe.utils.getdate(start)
	end = frappe.utils.getdate(end)
	if start.month == end.month:
		return f"{start.day} – {end.day} {end.strftime('%b')}"
	return f"{start.day} {start.strftime('%b')} – {end.day} {end.strftime('%b')}"
