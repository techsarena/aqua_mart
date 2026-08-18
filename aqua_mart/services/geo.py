"""Distance and service-area rules (API_SPEC 5.3, 6.8).

An address is serviceable when its area is in the seller's named-area list
OR it falls within `radius_km` of the seller's location. Named areas win
because customers recognise them; the radius is the fallback for addresses
that don't match a name.
"""

import math

import frappe

from aqua_mart.services import constants as C

EARTH_RADIUS_M = 6371000


def has_location(latitude, longitude):
	"""True when a coordinate pair is a real place.

	A seller who never set their shop location stores 0.0/0.0, which is a
	valid coordinate in the Gulf of Guinea rather than a missing one. Treating
	it as real puts the shop 8,500 km from Lahore, so every distance and
	radius check silently fails instead of saying the location is unset.
	"""
	if latitude in (None, "") or longitude in (None, ""):
		return False
	try:
		return not (abs(float(latitude)) < 0.0001 and abs(float(longitude)) < 0.0001)
	except (TypeError, ValueError):
		return False


def haversine_metres(lat1, lng1, lat2, lng2):
	"""Great-circle distance in metres, or None when a coordinate is missing."""
	if None in (lat1, lng1, lat2, lng2):
		return None
	if not has_location(lat1, lng1) or not has_location(lat2, lng2):
		return None

	p1, p2 = math.radians(float(lat1)), math.radians(float(lat2))
	dp = math.radians(float(lat2) - float(lat1))
	dl = math.radians(float(lng2) - float(lng1))

	a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
	return int(EARTH_RADIUS_M * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)))


def _normalise(area):
	"""Lower-case, strip punctuation, collapse whitespace.

	Comparing raw strings fails on punctuation alone ("P.E.C.H.S." vs
	"PECHS"), so both sides are flattened the same way before matching.
	"""
	import re

	return re.sub(r"[^a-z0-9]+", " ", (area or "").lower()).strip()


def area_matches(seller_area, address_area):
	"""Does a seller's named area appear in this address?

	The two sides are written by different people for different purposes: a
	seller types a short neighbourhood ("Gulberg III"), while the address is
	whatever the geocoder returned, which is a full postal line -
	"Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, ... Karachi, Sindh".

	Exact equality therefore never matched, and every seller fell through to
	the radius check. Containment is checked on WORD boundaries so "model
	town" cannot match inside an unrelated word.
	"""
	seller_norm = _normalise(seller_area)
	address_norm = _normalise(address_area)
	if not seller_norm or not address_norm:
		return False

	if seller_norm == address_norm:
		return True

	# Word-boundary containment: the seller's area must appear as whole words
	# within the address, not as a fragment of a longer word.
	seller_words = seller_norm.split()
	address_words = address_norm.split()
	if len(seller_words) > len(address_words):
		return False

	for start in range(len(address_words) - len(seller_words) + 1):
		if address_words[start : start + len(seller_words)] == seller_words:
			return True

	# Initialisms survive punctuation differently on each side: a seller may
	# type "P.E.C.H.S." (which flattens to five single letters) while the
	# geocoder returns "PECHS" as one word. Compare the de-spaced forms when
	# the seller's area is all single letters.
	if all(len(word) == 1 for word in seller_words) and len(seller_words) > 1:
		joined = "".join(seller_words)
		return joined in address_words

	return False


def seller_covers(seller, address):
	"""Does this seller serve this address? Named area first, radius second."""
	for row in seller.get("areas") or []:
		if area_matches(row.area, address.area):
			return True

	if (
		seller.get("radius_km")
		and has_location(seller.get("latitude"), seller.get("longitude"))
		and has_location(address.latitude, address.longitude)
	):
		distance = haversine_metres(
			seller.get("latitude"), seller.get("longitude"), address.latitude, address.longitude
		)
		if distance is not None and distance <= float(seller.radius_km) * 1000:
			return True

	return False


def sellers_covering_address(address, limit=None):
	"""Approved, non-suspended sellers whose service area covers `address`.

	Closed sellers ARE included - the shelf greys them out rather than
	hiding them (5.1).
	"""
	if isinstance(address, str):
		address = frappe.get_doc("Aqua Address", address)

	candidates = frappe.get_all(
		"Aqua Seller Profile",
		filters={"verification_status": C.APPROVED, "is_suspended": 0},
		pluck="name",
	)

	covering = []
	for name in candidates:
		seller = frappe.get_doc("Aqua Seller Profile", name)
		if seller_covers(seller, address):
			covering.append(seller)
			if limit and len(covering) >= limit:
				break

	return covering


def distance_to_address(seller, address):
	return haversine_metres(
		seller.get("latitude"), seller.get("longitude"), address.latitude, address.longitude
	)
