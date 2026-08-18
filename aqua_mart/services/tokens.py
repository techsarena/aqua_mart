"""JWT access/refresh tokens (API_SPEC 1.4, 4.2, 4.3).

Access tokens are stateless HS256 JWTs (60 min). Refresh tokens are also
JWTs but are additionally tracked in `Aqua Refresh Token` so they can be
rotated and revoked - a stateless refresh token cannot be invalidated on
logout, and logout must actually revoke (4.5).

Signing key: the site's `aqua_jwt_secret`, falling back to Frappe's own
secret so a fresh site works without extra configuration.
"""

import hashlib
import uuid
from datetime import datetime, timedelta, timezone

import frappe
import jwt

from aqua_mart.aqua_mart.doctype.aqua_settings.aqua_settings import get_settings
from aqua_mart.services.response import unauthorised

ALGORITHM = "HS256"
ACCESS = "access"
REFRESH = "refresh"


def _secret():
	"""The HS256 signing key.

	Prefer an explicit `aqua_jwt_secret` in site config so tokens survive a
	site restore; fall back to the site's own encryption key so a fresh
	install works without extra setup. The import is local because
	frappe.utils.password is not loaded by `import frappe` alone - relying
	on that only works inside a web request that already imported it.
	"""
	configured = frappe.conf.get("aqua_jwt_secret")
	if configured:
		return configured

	from frappe.utils.password import get_encryption_key

	return get_encryption_key()


def _now():
	return datetime.now(timezone.utc)


def _encode(user, role, kind, ttl, jti):
	payload = {
		"sub": user,
		"role": role,
		"kind": kind,
		"jti": jti,
		"iat": int(_now().timestamp()),
		"exp": int((_now() + ttl).timestamp()),
	}
	return jwt.encode(payload, _secret(), algorithm=ALGORITHM)


def _hash(token):
	"""Refresh tokens are stored hashed - a leaked table must not be usable."""
	return hashlib.sha256(token.encode()).hexdigest()


def issue_pair(user, role, device=None):
	"""Mint a fresh access+refresh pair and record the refresh token."""
	settings = get_settings()
	access_ttl = int(settings.access_token_ttl_minutes)
	refresh_ttl = int(settings.refresh_token_ttl_days)

	access = _encode(user, role, ACCESS, timedelta(minutes=access_ttl), uuid.uuid4().hex)

	jti = uuid.uuid4().hex
	refresh = _encode(user, role, REFRESH, timedelta(days=refresh_ttl), jti)

	doc = frappe.get_doc(
		{
			"doctype": "Aqua Refresh Token",
			"user": user,
			"jti": jti,
			"token_hash": _hash(refresh),
			"device": device,
			"expires_at": frappe.utils.add_days(frappe.utils.now(), refresh_ttl),
		}
	)
	doc.insert(ignore_permissions=True)

	return {"access_token": access, "refresh_token": refresh}


def decode(token, expected_kind=ACCESS):
	"""Decode and validate a token, or raise 401 (never 403 - see 1.3)."""
	try:
		payload = jwt.decode(token, _secret(), algorithms=[ALGORITHM])
	except jwt.ExpiredSignatureError:
		unauthorised("Your session has expired.", code="token_expired")
	except jwt.InvalidTokenError:
		unauthorised("Your session is no longer valid.", code="token_invalid")

	if payload.get("kind") != expected_kind:
		unauthorised("Your session is no longer valid.", code="token_invalid")
	return payload


def rotate(refresh_token):
	"""Verify a refresh token, revoke it, and issue a new pair.

	Rotation means a stolen refresh token is useful only until the real client
	next refreshes - at which point the theft surfaces as a failed refresh.
	"""
	payload = decode(refresh_token, expected_kind=REFRESH)

	row = frappe.db.get_value(
		"Aqua Refresh Token",
		{"jti": payload.get("jti")},
		["name", "revoked", "user"],
		as_dict=True,
	)
	if not row or row.revoked:
		unauthorised("Please sign in again.", code="token_revoked")

	frappe.db.set_value("Aqua Refresh Token", row.name, "revoked", 1)

	role = frappe.db.get_value("Aqua Profile", {"user": row.user}, "role")
	return issue_pair(row.user, role)


def revoke_all(user):
	"""Sign out every device for this user (4.5)."""
	frappe.db.set_value(
		"Aqua Refresh Token",
		{"user": user, "revoked": 0},
		"revoked",
		1,
		update_modified=False,
	)


def resolve_request():
	"""before_request hook: turn `Authorization: Bearer <jwt>` into a session.

	Frappe's own auth runs on cookies; the app is token-only. Setting
	frappe.local.session.user here lets every downstream permission check,
	and Frappe's socket.io handshake, work unchanged.

	A bad token is left alone rather than raising - the endpoint's own guard
	produces the 401, so /auth/* paths (which must never 401 for an expired
	token, 1.4) stay reachable.
	"""
	request = getattr(frappe.local, "request", None)
	if not request:
		return

	header = request.headers.get("Authorization") or ""
	if not header.startswith("Bearer "):
		return

	token = header[7:].strip()
	if not token:
		return

	try:
		payload = jwt.decode(token, _secret(), algorithms=[ALGORITHM])
	except jwt.InvalidTokenError:
		return

	if payload.get("kind") != ACCESS:
		return

	user = payload.get("sub")
	if not user or not frappe.db.exists("User", user):
		return

	frappe.set_user(user)
