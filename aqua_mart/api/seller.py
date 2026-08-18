"""Seller endpoints (API_SPEC 6).

Every handler acts on the seller DERIVED FROM THE TOKEN. There is no
seller_id parameter anywhere in this module and one must never be accepted -
that would let any seller drive another's store (6).
"""

import hashlib
import random
import re
import string

import frappe

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_settings
from aqua_mart.services import constants as C
from aqua_mart.services import order_state, realtime
from aqua_mart.services.dashboard import build_dashboard
from aqua_mart.services.guard import (
	aqua_endpoint,
	current_user,
	request_body,
	require_approved_seller,
	require_seller,
)
from aqua_mart.services.notifications import notify, notify_order_status
from aqua_mart.services.response import conflict, invalid, no_content, not_found, ok, paginate
from aqua_mart.services.serializers import (
	serialize_bottle,
	serialize_dispute,
	serialize_order,
	serialize_payout,
	serialize_rider,
)

# --- 6.1 onboarding & KYC -------------------------------------------------


@frappe.whitelist()
@aqua_endpoint()
def register(**kwargs):
	"""POST /seller/register - step 1, before any approval exists."""
	user = current_user()
	body = request_body()

	errors = {}
	business_name = (body.get("business_name") or "").strip()
	if not business_name:
		errors["business_name"] = "Enter your business name."
	business_type = body.get("business_type")
	if business_type not in C.BUSINESS_TYPES:
		errors["business_type"] = "Choose the kind of business you run."
	if errors:
		invalid(errors)

	existing = frappe.db.get_value("Aqua Seller Profile", {"user": user}, "name")
	if existing:
		doc = frappe.get_doc("Aqua Seller Profile", existing)
		doc.business_name = business_name
		doc.owner_name = body.get("owner_name")
		doc.business_type = business_type
		doc.save(ignore_permissions=True)
	else:
		doc = frappe.get_doc(
			{
				"doctype": "Aqua Seller Profile",
				"user": user,
				"business_name": business_name,
				"owner_name": body.get("owner_name"),
				"business_type": business_type,
				"verification_status": C.DETAILS_RECEIVED,
			}
		).insert(ignore_permissions=True)

		_ensure_invite_code(doc.name)

	# The account's role becomes seller at registration.
	frappe.db.set_value("Aqua Profile", {"user": user}, "role", C.ROLE_SELLER)

	return ok({"id": doc.name, "verification_status": doc.verification_status}, status=201)


def _ensure_invite_code(seller_name):
	"""Every seller gets a 6-character rider join code (7.5)."""
	if frappe.db.exists("Aqua Rider Invite Code", {"seller": seller_name, "active": 1}):
		return

	alphabet = string.ascii_uppercase + string.digits
	for _ in range(20):
		code = "".join(random.SystemRandom().choice(alphabet) for _ in range(6))
		if not frappe.db.exists("Aqua Rider Invite Code", code):
			frappe.get_doc(
				{
					"doctype": "Aqua Rider Invite Code",
					"seller": seller_name,
					"code": code,
					"active": 1,
				}
			).insert(ignore_permissions=True)
			return code


@frappe.whitelist()
@aqua_endpoint()
def documents(**kwargs):
	"""POST /seller/documents - multipart KYC upload.

	CNIC images must NEVER be reachable by a public URL (6.1), so every file
	is stored private.
	"""
	seller_name = require_seller()
	doc = frappe.get_doc("Aqua Seller Profile", seller_name)

	required = ("cnic_front", "cnic_back", "water_test")
	optional = ("licence", "plant_photo")

	files = getattr(frappe.local.request, "files", None) or {}
	body = request_body()
	contents = {}

	for field in required + optional:
		upload = files.get(field)
		if not upload:
			continue
		contents[field] = _read_private_upload(upload, field)

	missing = {f: "This document is required." for f in required if not (contents.get(f) or doc.get(f))}
	if missing:
		invalid(missing)

	# A new CNIC is accepted only when both sides have passed on-device OCR,
	# and the server independently checks the OCR evidence and image bytes.
	if "cnic_front" in contents or "cnic_back" in contents:
		if not {"cnic_front", "cnic_back"}.issubset(contents):
			invalid(
				{
					"cnic_front": "Upload both CNIC sides together.",
					"cnic_back": "Upload both CNIC sides together.",
				}
			)
		cnic_errors = _cnic_validation_errors(
			_multipart_text(body, "cnic_front_ocr"),
			_multipart_text(body, "cnic_back_ocr"),
			contents["cnic_front"],
			contents["cnic_back"],
		)
		if cnic_errors:
			invalid(cnic_errors, message=next(iter(cnic_errors.values())))

	saved = {
		field: _save_private_file(files[field], content, doc.name, field)
		for field, content in contents.items()
	}

	for field, url in saved.items():
		setattr(doc, field, url)

	doc.verification_status = C.DOCUMENTS_UPLOADED
	doc.save(ignore_permissions=True)

	return ok({"verification_status": doc.verification_status})


MAX_UPLOAD_BYTES = 5 * 1024 * 1024
ALLOWED_UPLOAD_TYPES = {"image/jpeg", "image/png", "application/pdf"}


def _read_private_upload(upload, field):
	"""Read and validate one KYC upload before anything is persisted."""
	content = upload.stream.read()
	if not content:
		invalid({field: "This file is empty. Choose it again."})
	if len(content) > MAX_UPLOAD_BYTES:
		invalid({field: "This file is too large. The limit is 5 MB."})

	if upload.mimetype and upload.mimetype not in ALLOWED_UPLOAD_TYPES:
		invalid({field: "Upload a JPEG, PNG or PDF."})
	if field in ("cnic_front", "cnic_back") and upload.mimetype not in (
		"image/jpeg",
		"image/png",
	):
		invalid({field: "Take or choose a clear CNIC photo."})
	return content


def _save_private_file(upload, content, seller_name, field):
	"""Store a validated KYC file privately, stripping image EXIF."""

	if upload.mimetype in ("image/jpeg", "image/png"):
		content = _strip_exif(content)

	saved = frappe.get_doc(
		{
			"doctype": "File",
			"file_name": f"{seller_name}-{field}-{upload.filename}",
			"attached_to_doctype": "Aqua Seller Profile",
			"attached_to_name": seller_name,
			"content": content,
			"is_private": 1,
		}
	).insert(ignore_permissions=True)
	return saved.file_url


CNIC_NUMBER_PATTERN = re.compile(r"(?:^|\D)(\d{5})[\s\-–—]*(\d{7})[\s\-–—]*(\d)(?:\D|$)")
CNIC_FRONT_SIGNALS = {
	"pakistan",
	"identity",
	"national",
	"name",
	"father",
	"husband",
	"gender",
	"birth",
	"country of stay",
}
CNIC_FRONT_SIDE_SIGNALS = {
	"name",
	"father",
	"husband",
	"gender",
	"birth",
	"country of stay",
}
CNIC_BACK_SIGNALS = {
	"address",
	"present",
	"current",
	"permanent",
	"issue",
	"expiry",
	"signature",
	"family",
	"nadra",
	"return",
	"serial",
	"issuing authority",
	"qr",
}
CNIC_BACK_SIDE_SIGNALS = {
	"present address",
	"current address",
	"permanent address",
	"card serial",
	"serial no",
	"serial number",
	"family no",
	"family number",
	"issuing authority",
	"qr code",
	"machine readable",
	"visa free entry",
}


def _multipart_text(body, field):
	"""Read a text field reliably from Frappe/Werkzeug multipart parsing."""
	request = getattr(frappe.local, "request", None)
	form = getattr(request, "form", None)
	if form is not None:
		value = form.get(field)
		if value not in (None, ""):
			return value

	value = body.get(field)
	if value not in (None, ""):
		return value

	form_dict = getattr(frappe.local, "form_dict", None)
	return form_dict.get(field) if form_dict else None


def _cnic_validation_errors(front_ocr, back_ocr, front_content, back_content):
	"""Reject non-CNIC, wrong-side, duplicate, and mismatched CNIC images."""
	front_ocr = str(front_ocr or "")[:10000]
	back_ocr = str(back_ocr or "")[:10000]
	front_text = _normalise_ocr(front_ocr)
	back_text = _normalise_ocr(back_ocr)
	front_score = _signal_score(front_text, CNIC_FRONT_SIGNALS)
	front_back_score = _signal_score(front_text, CNIC_BACK_SIGNALS)
	front_back_side_score = _signal_score(front_text, CNIC_BACK_SIDE_SIGNALS)
	back_score = _signal_score(back_text, CNIC_BACK_SIGNALS)
	back_side_score = _signal_score(back_text, CNIC_BACK_SIDE_SIGNALS)
	back_front_side_score = _signal_score(back_text, CNIC_FRONT_SIDE_SIGNALS)
	front_number = _extract_cnic_number(front_ocr)
	back_number = _extract_cnic_number(back_ocr)

	errors = {}
	if len(front_text) < 20 or not front_number or front_score < 2:
		errors["cnic_front"] = (
			"This looks like the CNIC back. Add the front side here."
			if (front_back_side_score >= 1 or front_back_score >= 2) and front_score < 2
			else "This is not a readable Pakistani CNIC front. Retake the correct card."
		)

	# Front-only biographical labels take precedence because a real front also
	# contains shared words such as issue, expiry, signature, and NADRA.
	if back_front_side_score >= 1:
		errors["cnic_back"] = (
			"This is the front side of the CNIC. Please take or upload a picture of the back side."
		)
	elif (len(back_text) < 20 and not (back_side_score >= 1 and len(back_text) >= 8)) or (
		back_side_score < 1 and back_score < 2
	):
		errors["cnic_back"] = (
			"This is not a readable Pakistani CNIC back. Retake the correct card."
		)

	if hashlib.sha256(front_content).digest() == hashlib.sha256(back_content).digest():
		errors["cnic_back"] = "The same CNIC photo was selected twice. Add the other side."
	elif front_text and front_text == back_text:
		errors["cnic_back"] = "The same CNIC side was selected twice. Add the other side."
	elif front_number and back_number and front_number != back_number:
		errors["cnic_back"] = "The CNIC front and back are from different cards."
	return errors


def _normalise_ocr(text):
	return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", text.lower())).strip()


def _signal_score(text, signals):
	return sum(1 for signal in signals if signal in text)


def _extract_cnic_number(text):
	match = CNIC_NUMBER_PATTERN.search(text)
	if match:
		return "".join(match.groups())
	for line in re.split(r"[\r\n]+", text):
		digits = re.sub(r"\D", "", line)
		if len(digits) == 13:
			return digits
	return None


def _strip_exif(content):
	"""Drop EXIF (which carries GPS) before the image is stored (10.6)."""
	try:
		import io

		from PIL import Image

		image = Image.open(io.BytesIO(content))
		clean = Image.new(image.mode, image.size)
		clean.putdata(list(image.getdata()))

		out = io.BytesIO()
		clean.save(out, format=image.format)
		return out.getvalue()
	except Exception:
		# Never fail an upload because the stripper choked.
		return content


@frappe.whitelist()
@aqua_endpoint()
def submit_verification(**kwargs):
	"""POST /seller/verification - submit for review, with the catalogue."""
	seller_name = require_seller()
	doc = frappe.get_doc("Aqua Seller Profile", seller_name)
	body = request_body()

	for bottle in body.get("bottles") or []:
		litres = int(bottle.get("litres") or 0)
		if litres not in C.BOTTLE_LITRES:
			invalid({"bottles": "Choose 6, 10 or 25 litre bottles."})

		existing = frappe.db.get_value(
			"Aqua Bottle", {"seller": seller_name, "litres": str(litres)}, "name"
		)
		values = {
			"refill_price": int(bottle.get("refill_price") or 0),
			"new_price": int(bottle.get("new_price") or 0),
			"deposit": int(
				bottle.get("deposit") or get_settings().default_deposit
			),
		}
		if existing:
			frappe.db.set_value("Aqua Bottle", existing, values)
		else:
			frappe.get_doc(
				{
					"doctype": "Aqua Bottle",
					"seller": seller_name,
					"litres": str(litres),
					"bottle_name": f"{litres}L Bottle",
					"is_visible": 1,
					**values,
				}
			).insert(ignore_permissions=True)

	# A note for the verification team, not a priced item.
	doc.sells_other_sizes = 1 if body.get("sells_other_sizes") else 0
	doc.verification_status = C.IN_REVIEW
	doc.submitted_at = frappe.utils.now_datetime()
	doc.save(ignore_permissions=True)

	return ok({"verification_status": doc.verification_status})


@frappe.whitelist()
@aqua_endpoint()
def verification_status(**kwargs):
	"""GET /seller/verification - the waiting room, polled by the client."""
	seller_name = require_seller()
	doc = frappe.get_doc("Aqua Seller Profile", seller_name)

	from aqua_mart.services.serializers import iso

	return ok(
		{
			"verification_status": doc.verification_status,
			"submitted_at": iso(doc.submitted_at),
			"estimated_hours": 24,
			"rejection_reason": doc.rejection_reason,
		}
	)


# --- 6.2 dashboard --------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def dashboard(**kwargs):
	"""GET /seller/dashboard"""
	return ok(build_dashboard(require_approved_seller()))


# --- 6.3 open/closed ------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def set_open(**kwargs):
	"""POST /seller/open

	Closing hides the store from /sellers/nearby for NEW orders only.
	Orders already in flight continue normally - nothing is cancelled (6.3).
	"""
	seller_name = require_approved_seller()
	body = request_body()

	is_open = bool(body.get("is_open"))
	frappe.db.set_value(
		"Aqua Seller Profile",
		seller_name,
		{
			"is_open": 1 if is_open else 0,
			# A manual close sticks for the rest of today only (6.8).
			"manual_close_date": None if is_open else frappe.utils.nowdate(),
		},
	)
	realtime.emit_seller_dashboard(seller_name)
	return no_content()


# --- 6.4 order queue ------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def orders(**kwargs):
	"""GET /seller/orders - all four buckets in one call, not pre-filtered.

	Sorted oldest-first within New so the longest-waiting customer is at
	the top (6.4).
	"""
	seller_name = require_approved_seller()
	limit, offset = paginate(frappe.local.form_dict)

	rows = frappe.get_all(
		"Aqua Order",
		filters={"seller": seller_name},
		fields=["name", "status", "placed_at"],
		order_by="placed_at desc",
		limit_page_length=limit,
		limit_start=offset,
	)

	# New (pending) first and OLDEST-first inside it, so the longest-waiting
	# customer is at the top; everything else stays newest-first (6.4).
	pending = sorted(
		[r for r in rows if r.status == C.PENDING], key=lambda r: r.placed_at or ""
	)
	rest = [r for r in rows if r.status != C.PENDING]

	return ok(
		[serialize_order(r.name, for_role=C.ROLE_SELLER) for r in pending + rest]
	)


def _seller_order(seller_name, order_id):
	"""A seller may act on an order ONLY if it is theirs (2)."""
	row = frappe.db.get_value("Aqua Order", order_id, ["name", "seller"], as_dict=True)
	if not row or row.seller != seller_name:
		not_found("We could not find that order.")
	return frappe.get_doc("Aqua Order", order_id)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def accept_order(id=None, **kwargs):
	"""POST /seller/orders/{id}/accept - advance, restricted to pending."""
	seller_name = require_approved_seller()
	order = _seller_order(seller_name, id)

	if order.status != C.PENDING:
		conflict("This order has already been accepted.", code="already_accepted")

	return _advance_to(order, C.ACCEPTED)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def advance_order(id=None, **kwargs):
	"""POST /seller/orders/{id}/advance - one step along the happy path.

	Idempotent enough to survive the client's retries: the transition table
	rejects a repeat with 409 rather than skipping a step (10.4).
	"""
	seller_name = require_approved_seller()
	order = _seller_order(seller_name, id)

	target = order_state.next_status(order.status)
	if not target:
		conflict("This order cannot be moved any further.", code="order_terminal")

	return _advance_to(order, target)


def _advance_to(order, target):
	order_state.transition(order, target, C.ROLE_SELLER)

	if target == C.DELIVERED:
		_on_delivered(order)

	realtime.emit_order_status(order)
	realtime.emit_seller_dashboard(order.seller)
	notify_order_status(order, actor=frappe.session.user)

	return ok(serialize_order(order, for_role=C.ROLE_SELLER))


def _on_delivered(order):
	"""Record the empties the customer now holds, and release deposits."""
	from aqua_mart.services.empties import record_empties_for_order

	record_empties_for_order(order)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def decline_order(id=None, **kwargs):
	"""POST /seller/orders/{id}/decline - legal only from pending."""
	seller_name = require_approved_seller()
	order = _seller_order(seller_name, id)
	body = request_body()

	order_state.transition(
		order,
		C.REJECTED_BY_SELLER,
		C.ROLE_SELLER,
		rejection_reason=body.get("reason"),
	)

	from aqua_mart.api.orders import _refund_if_prepaid, _restore_stock

	_restore_stock(order)
	_refund_if_prepaid(order)

	realtime.emit_order_status(order)
	realtime.emit_seller_dashboard(order.seller)
	# The client has a dedicated screen keyed off this state - notify at once.
	notify_order_status(order, actor=frappe.session.user)

	return ok(serialize_order(order, for_role=C.ROLE_SELLER))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def assign_rider(id=None, **kwargs):
	"""POST /seller/orders/{id}/assign - adds a stop to that rider's run."""
	seller_name = require_approved_seller()
	order = _seller_order(seller_name, id)
	body = request_body()

	rider_id = body.get("rider_id")
	rider = frappe.db.get_value(
		"Aqua Rider Profile", rider_id, ["name", "seller", "status", "full_name", "rating"],
		as_dict=True,
	)
	# The rider must belong to THIS seller.
	if not rider or rider.seller != seller_name:
		not_found("We could not find that rider.")
	if rider.status not in ("idle", "onRun"):
		conflict("That rider is off duty right now.", code="rider_unavailable")

	from aqua_mart.services.runs import add_stop

	add_stop(rider.name, order)

	order.rider = rider.name
	order.rider_name = rider.full_name
	order.rider_rating = rider.rating
	order.save(ignore_permissions=True)

	frappe.db.set_value("Aqua Rider Profile", rider.name, "status", "onRun")

	realtime.emit_rider_assigned(order)
	rider_user = frappe.db.get_value("Aqua Rider Profile", rider.name, "user")
	notify(
		rider_user,
		"riderRun",
		"New stop added",
		f"{order.reference} · {order.address_area or ''}".strip(" ·"),
		"/rider/run",
		actor=frappe.session.user,
	)

	return no_content()


# --- 6.5 inventory --------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def inventory(**kwargs):
	"""GET /seller/inventory - INCLUDING hidden bottles (6.5)."""
	seller_name = require_approved_seller()
	names = frappe.get_all("Aqua Bottle", filters={"seller": seller_name}, pluck="name")
	bottles = sorted(
		(serialize_bottle(name) for name in names), key=lambda b: b["litres"], reverse=True
	)
	return ok(bottles)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def update_bottle(id=None, **kwargs):
	"""PUT /seller/inventory/{id} - body is the full bottle object."""
	seller_name = require_approved_seller()
	bottle = _seller_bottle(seller_name, id)
	body = request_body()

	mapping = {
		"name": "bottle_name",
		"refill_price": "refill_price",
		"new_price": "new_price",
		"deposit": "deposit",
		"description": "description",
		"filled_stock": "filled_stock",
		"empties_in_yard": "empties_in_yard",
		"photo_url": "photo_url",
		"is_visible": "is_visible",
	}
	for key, field in mapping.items():
		if key in body:
			value = body.get(key)
			if field in ("refill_price", "new_price", "deposit", "filled_stock", "empties_in_yard"):
				value = int(value or 0)
			if field == "is_visible":
				value = 1 if value else 0
			setattr(bottle, field, value)

	if "litres" in body:
		litres = int(body.get("litres") or 0)
		if litres not in C.BOTTLE_LITRES:
			invalid({"litres": "Choose 6, 10 or 25 litres."})
		bottle.litres = str(litres)

	bottle.save(ignore_permissions=True)
	return ok(serialize_bottle(bottle))


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def delete_bottle(id=None, **kwargs):
	"""DELETE /seller/inventory/{id}

	A bottle on a live order cannot be deleted - hide it instead (6.5).
	"""
	seller_name = require_approved_seller()
	bottle = _seller_bottle(seller_name, id)

	live = frappe.db.sql(
		"""select 1 from `tabAqua Order Line` line
		   join `tabAqua Order` o on o.name = line.parent
		   where line.bottle = %s and o.status not in %s limit 1""",
		(bottle.name, C.TERMINAL_STATUSES),
	)
	if live:
		conflict(
			"This bottle is on an order that is still running. Hide it instead.",
			code="bottle_in_use",
		)

	frappe.delete_doc("Aqua Bottle", bottle.name, ignore_permissions=True)
	return no_content()


def _seller_bottle(seller_name, bottle_id):
	row = frappe.db.get_value("Aqua Bottle", bottle_id, ["name", "seller"], as_dict=True)
	if not row or row.seller != seller_name:
		not_found("We could not find that bottle.")
	return frappe.get_doc("Aqua Bottle", bottle_id)


# --- 6.6 riders -----------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def riders(**kwargs):
	"""GET /seller/riders

	distance_from_customer and eta_minutes are only meaningful when the
	client is choosing a rider for a specific order - null otherwise (6.6).
	"""
	seller_name = require_approved_seller()
	order_id = frappe.local.form_dict.get("order_id")

	order = None
	if order_id:
		row = frappe.db.get_value("Aqua Order", order_id, ["name", "seller"], as_dict=True)
		if row and row.seller == seller_name:
			order = frappe.get_doc("Aqua Order", order_id)

	names = frappe.get_all(
		"Aqua Rider Profile",
		filters={"seller": seller_name, "approval_status": C.APPROVED},
		pluck="name",
	)

	out = []
	for name in names:
		rider = frappe.get_doc("Aqua Rider Profile", name)
		distance = eta = None
		if order and rider.latitude and order.address_latitude:
			from aqua_mart.services.geo import haversine_metres

			distance = haversine_metres(
				rider.latitude, rider.longitude, order.address_latitude, order.address_longitude
			)
			if distance is not None:
				# ~20 km/h through city traffic.
				eta = max(1, round(distance / 1000 / 20 * 60))
		out.append(serialize_rider(rider, distance_from_customer=distance, eta_minutes=eta))

	return ok(out)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def invite_rider(**kwargs):
	"""POST /seller/riders/invite - SMS the join code, create the invitation."""
	seller_name = require_approved_seller()
	body = request_body()

	from aqua_mart.services.phone import require_phone, send_sms

	phone = require_phone(body.get("phone"))

	code = frappe.db.get_value(
		"Aqua Rider Invite Code", {"seller": seller_name, "active": 1}, "code"
	) or _ensure_invite_code(seller_name)

	seller = frappe.get_doc("Aqua Seller Profile", seller_name)

	invitation = frappe.get_doc(
		{
			"doctype": "Aqua Rider Invitation",
			"seller": seller_name,
			"sent_by": seller.owner_name or seller.business_name,
			"sent_to": phone,
			"areas": body.get("areas"),
			"hours": body.get("hours"),
			"status": "pending",
		}
	).insert(ignore_permissions=True)

	send_sms(phone, f"Join {seller.business_name} on Aqua Mart with code {code}")

	return ok({"id": invitation.name}, status=201)


# --- 6.7 disputes ---------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def disputes(**kwargs):
	"""GET /seller/disputes"""
	seller_name = require_approved_seller()
	limit, offset = paginate(frappe.local.form_dict)

	names = frappe.get_all(
		"Aqua Dispute",
		filters={"seller": seller_name},
		order_by="raised_at desc",
		limit_page_length=limit,
		limit_start=offset,
		pluck="name",
	)
	return ok([serialize_dispute(name) for name in names])


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def dispute_detail(id=None, **kwargs):
	"""GET /seller/disputes/{id} - opening it must NOT touch raised_at (6.7)."""
	seller_name = require_approved_seller()
	return ok(serialize_dispute(_seller_dispute(seller_name, id)))


def _seller_dispute(seller_name, dispute_id):
	row = frappe.db.get_value("Aqua Dispute", dispute_id, ["name", "seller"], as_dict=True)
	if not row or row.seller != seller_name:
		not_found("We could not find that complaint.")
	return frappe.get_doc("Aqua Dispute", dispute_id)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def resolve_dispute(id=None, **kwargs):
	"""POST /seller/disputes/{id}/resolve"""
	seller_name = require_approved_seller()
	dispute = _seller_dispute(seller_name, id)
	body = request_body()

	resolution = body.get("resolution")
	if resolution not in C.DISPUTE_RESOLUTIONS:
		invalid({"resolution": "Choose a replacement, a refund, or escalate."})

	if dispute.status != "open":
		conflict("This complaint has already been settled.", code="dispute_closed")

	if resolution == "refund":
		from aqua_mart.services.wallet import credit

		credit(
			dispute.customer,
			dispute.amount,
			f"Complaint refund · {dispute.order_reference}",
			"Aqua Dispute",
			dispute.name,
		)
		dispute.status = "resolved"

	elif resolution == "replacement":
		_create_replacement_order(dispute)
		dispute.status = "resolved"

	else:
		# Escalate: the dispute stays open, the clock stops, and the
		# seller's rating is protected pending review (6.7).
		dispute.status = "escalated"

	dispute.resolution = resolution
	dispute.resolved_at = frappe.utils.now_datetime()
	dispute.save(ignore_permissions=True)

	notify(
		dispute.customer,
		"complaint",
		"Your complaint was reviewed",
		{
			"refund": "The amount has been credited to your wallet.",
			"replacement": "A replacement order is on its way.",
			"escalate": "Aqua Mart support is looking into this.",
		}[resolution],
		f"/customer/order/{dispute.order}/track",
		actor=frappe.session.user,
	)

	return no_content()


def _create_replacement_order(dispute):
	"""A new ZERO-COST order for the same lines (6.7)."""
	original = frappe.get_doc("Aqua Order", dispute.order)

	replacement = frappe.copy_doc(original)
	replacement.reference = f"{original.reference}-R"
	replacement.status = C.PENDING
	replacement.placed_at = frappe.utils.now_datetime()
	replacement.delivery_fee = 0
	replacement.rider = None
	replacement.rider_name = None
	replacement.rider_rating = None
	replacement.rating = None
	replacement.idempotency_key = None
	replacement.cancellation_reason = None
	replacement.rejection_reason = None
	for line in replacement.lines:
		line.unit_price = 0
	replacement.insert(ignore_permissions=True)

	order_state.log(replacement.name, C.PENDING)
	realtime.emit_order_new(replacement)
	return replacement


# --- 6.8 service area & hours ---------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def get_service_area(**kwargs):
	"""GET /seller/service-area"""
	seller = frappe.get_doc("Aqua Seller Profile", require_approved_seller())
	return ok(
		{
			"areas": [a.area for a in seller.areas],
			"radius_km": float(seller.radius_km or 0),
		}
	)


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def set_service_area(**kwargs):
	"""PUT /seller/service-area"""
	seller = frappe.get_doc("Aqua Seller Profile", require_approved_seller())
	body = request_body()

	areas = body.get("areas")
	if areas is not None:
		if not isinstance(areas, list):
			invalid({"areas": "Send the areas as a list."})
		seller.areas = []
		for area in areas:
			if (area or "").strip():
				seller.append("areas", {"area": area.strip()})

	if "radius_km" in body:
		seller.radius_km = float(body.get("radius_km") or 0)

	seller.save(ignore_permissions=True)
	return ok({"areas": [a.area for a in seller.areas], "radius_km": float(seller.radius_km or 0)})


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def get_hours(**kwargs):
	"""GET /seller/hours - days are 0=Monday ... 6=Sunday (6.8)."""
	seller = frappe.get_doc("Aqua Seller Profile", require_approved_seller())
	return ok(_hours_payload(seller))


def _hours_payload(seller):
	days = [int(d) for d in (seller.days or "").split(",") if d.strip().isdigit()]
	return {
		"days": days,
		"opens_at": _hhmm(seller.opens_at),
		"closes_at": _hhmm(seller.closes_at),
	}


def _hhmm(value):
	if not value:
		return None
	t = frappe.utils.get_time(value)
	return f"{t.hour:02d}:{t.minute:02d}"


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def set_hours(**kwargs):
	"""PUT /seller/hours - these drive is_open and opens_at automatically."""
	seller = frappe.get_doc("Aqua Seller Profile", require_approved_seller())
	body = request_body()

	if "days" in body:
		days = body.get("days") or []
		if not isinstance(days, list) or any(int(d) not in range(7) for d in days):
			invalid({"days": "Choose which days you open."})
		seller.days = ",".join(str(int(d)) for d in sorted(days))

	for field in ("opens_at", "closes_at"):
		if field in body and body.get(field):
			setattr(seller, field, f"{body.get(field)}:00"[:8])

	seller.save(ignore_permissions=True)
	return ok(_hours_payload(seller))


# --- 6.9 payouts ----------------------------------------------------------


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def payouts(**kwargs):
	"""GET /seller/payouts"""
	seller_name = require_approved_seller()
	limit, offset = paginate(frappe.local.form_dict)

	names = frappe.get_all(
		"Aqua Payout",
		filters={"seller": seller_name},
		order_by="week_start desc",
		limit_page_length=limit,
		limit_start=offset,
		pluck="name",
	)
	return ok([serialize_payout(name) for name in names])


@frappe.whitelist()
@aqua_endpoint(role=C.ROLE_SELLER)
def payout_detail(id=None, **kwargs):
	"""GET /seller/payouts/{id}"""
	seller_name = require_approved_seller()
	row = frappe.db.get_value("Aqua Payout", id, ["name", "seller"], as_dict=True)
	if not row or row.seller != seller_name:
		not_found("We could not find that statement.")
	return ok(serialize_payout(id))
