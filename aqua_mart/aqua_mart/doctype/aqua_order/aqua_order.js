// Copyright (c) 2026, Muhammad Saad and contributors
// For license information, please see license.txt

// Assignment goes through the seller API (API_SPEC 6.6 / 6.4), not a
// desk-only method - so the desk, the seller app and any other client all
// drive assignment through exactly one code path.
const RIDERS_ENDPOINT = "aqua_mart.api.seller.riders";
const ASSIGN_ENDPOINT = "aqua_mart.api.seller.assign_rider";

const TERMINAL_STATUSES = ["delivered", "cancelledByCustomer", "rejectedBySeller"];

frappe.ui.form.on("Aqua Order", {
	refresh(frm) {
		if (frm.is_new()) return;
		if (TERMINAL_STATUSES.includes(frm.doc.status)) return;

		frm.add_custom_button(frm.doc.rider ? __("Reassign Order") : __("Assign Order"), () =>
			open_rider_picker(frm)
		).addClass("btn-primary");
	},
});

function open_rider_picker(frm) {
	// `order_id` is what GET /seller/riders reads to fill in each rider's
	// distance and ETA for this specific drop.
	call_api({
		method: RIDERS_ENDPOINT,
		args: { order_id: frm.doc.name },
		freeze_message: __("Loading riders…"),
		on_success(data) {
			const riders = data || [];

			if (!riders.length) {
				frappe.msgprint({
					title: __("No riders available"),
					indicator: "orange",
					message: __("{0} has no approved riders yet.", [
						frm.doc.seller_name || frm.doc.seller,
					]),
				});
				return;
			}

			show_dialog(frm, riders);
		},
	});
}

function show_dialog(frm, riders) {
	let selected = null;

	const dialog = new frappe.ui.Dialog({
		title: __("Assign to Rider"),
		fields: [{ fieldtype: "HTML", fieldname: "riders" }],
		primary_action_label: __("Assign"),
		primary_action() {
			if (!selected) {
				frappe.msgprint(__("Pick a rider first."));
				return;
			}
			call_api({
				method: ASSIGN_ENDPOINT,
				args: { id: frm.doc.name, rider_id: selected.id },
				freeze_message: __("Assigning…"),
				// assign_rider answers 204 with an empty body on success.
				on_success() {
					dialog.hide();
					frappe.show_alert({
						message: __("Assigned to {0}.", [selected.name]),
						indicator: "green",
					});
					frm.reload_doc();
				},
			});
		},
	});

	dialog.fields_dict.riders.$wrapper.html(render_riders(frm, riders));

	dialog.$wrapper.on("click", ".aqua-rider-row", function () {
		const $row = $(this);
		if ($row.hasClass("aqua-rider-disabled")) return;

		dialog.$wrapper.find(".aqua-rider-row").removeClass("aqua-rider-selected");
		$row.addClass("aqua-rider-selected");
		selected = { id: $row.data("rider"), name: $row.data("rider-name") };
	});

	dialog.show();
}

function render_riders(frm, riders) {
	const rows = riders
		.map((rider) => {
			const off_duty = rider.status === "offDuty";
			const is_current = String(rider.id) === String(frm.doc.rider);

			const bits = [
				`${__("Rating")} ${rider.rating || 0}★`,
				`${rider.stops_left} ${__("stops left")}`,
				`${rider.delivered} ${__("delivered this week")}`,
			];
			if (rider.distance_from_customer != null) {
				bits.push(`${(rider.distance_from_customer / 1000).toFixed(1)} km`);
			}
			if (rider.eta_minutes != null) bits.push(`~${rider.eta_minutes} ${__("min")}`);

			const badge = is_current
				? `<span class="indicator-pill blue">${__("Current")}</span>`
				: `<span class="indicator-pill ${
						off_duty ? "gray" : rider.status === "onRun" ? "orange" : "green"
				  }">${frappe.utils.escape_html(rider.status)}</span>`;

			return `
				<div class="aqua-rider-row ${off_duty ? "aqua-rider-disabled" : ""}"
					data-rider="${frappe.utils.escape_html(rider.id)}"
					data-rider-name="${frappe.utils.escape_html(rider.name || rider.id)}">
					<div>
						<div class="aqua-rider-name">${frappe.utils.escape_html(rider.name || rider.id)}</div>
						<div class="text-muted small">${frappe.utils.escape_html(bits.join(" · "))}</div>
					</div>
					${badge}
				</div>`;
		})
		.join("");

	return `
		<style>
			.aqua-rider-row {
				display: flex;
				align-items: center;
				justify-content: space-between;
				gap: 8px;
				padding: 10px 12px;
				border: 1px solid var(--border-color);
				border-radius: var(--border-radius-md);
				margin-bottom: 8px;
				cursor: pointer;
			}
			.aqua-rider-row:hover { background-color: var(--fg-hover-color); }
			.aqua-rider-selected {
				border-color: var(--primary);
				background-color: var(--bg-light-gray);
			}
			.aqua-rider-disabled { opacity: 0.5; cursor: not-allowed; }
			.aqua-rider-name { font-weight: 600; }
		</style>
		<div class="aqua-rider-list">${rows}</div>`;
}

// These endpoints speak HTTP status codes, which frappe.call's `callback`
// does not: it only fires on a literal 200, so assign_rider's 204 would be
// swallowed and every 4xx would surface as a generic framework error rather
// than the API's own message. `always` fires either way - but it is handed
// only the parsed body, and frappe strips http_status_code out of that
// before serialising. The body shape carries the outcome instead:
//
//   ok()         -> {"data": ...}, no "message"
//   no_content() -> neither key
//   fail()       -> {"message": "...", "code": ...}, no "data"
//
// so a "message" with no "data" is the API reporting a failure.
function call_api({ method, args, freeze_message, on_success }) {
	frappe.call({
		method,
		args,
		freeze: true,
		freeze_message,
		always(response) {
			const body = response || {};

			if (body.message && body.data === undefined) {
				frappe.msgprint({
					title: __("Could not assign"),
					indicator: "red",
					message: body.message,
				});
				return;
			}

			on_success(body.data);
		},
	});
}
