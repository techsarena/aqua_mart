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


def haversine_metres(lat1, lng1, lat2, lng2):
	"""Great-circle distance in metres, or None when a coordinate is missing."""
	if None in (lat1, lng1, lat2, lng2):
		return None

	p1, p2 = math.radians(float(lat1)), math.radians(float(lat2))
	dp = math.radians(float(lat2) - float(lat1))
	dl = math.radians(float(lng2) - float(lng1))

	a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
	return int(EARTH_RADIUS_M * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)))


def _normalise(area):
	return (area or "").strip().lower()


def seller_covers(seller, address):
	"""Does this seller serve this address? Named area first, radius second."""
	areas = {_normalise(a.area) for a in (seller.get("areas") or [])}
	if areas and _normalise(address.area) in areas:
		return True

	if seller.get("radius_km") and address.latitude and address.longitude:
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
