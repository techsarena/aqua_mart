"""Road geometry for the customer's tracking map (5.2).

The tracking screen draws the path from the rider to the door. A straight
line between the two crosses buildings and reads as wrong on a street map,
so the shape comes from a real routing engine.

The provider is called here rather than from the app: the key stays on the
server, one route is shared by every viewer of an order, and the result is
cached so a rider pinging every few seconds does not become a request per
ping to the provider.
"""

import frappe

# Nothing moves far enough in this window to change which streets the route
# uses, and it bounds the request rate to the provider per order.
_CACHE_SECONDS = 60

_DEFAULT_PROVIDER = "osrm"
_DEFAULT_OSRM_BASE = "https://router.project-osrm.org"


def route_line(from_point, to_point, order_name=None):
	"""[[lat, lng], ...] following the road, or None when unavailable.

	Never raises and never blocks the response for long: the tracking payload
	is useful without the line, so a provider that is slow, down, or
	unconfigured simply means the client draws no route.
	"""
	if not from_point or not to_point:
		return None
	if not all(_is_number(v) for v in (*from_point, *to_point)):
		return None

	cache_key = _cache_key(from_point, to_point, order_name)
	cached = frappe.cache().get_value(cache_key)
	if cached is not None:
		# An empty list is a cached "the provider had nothing" - honour it
		# rather than asking again on every poll.
		return cached or None

	line = _fetch(from_point, to_point)
	frappe.cache().set_value(cache_key, line or [], expires_in_sec=_CACHE_SECONDS)
	return line


def _fetch(from_point, to_point):
	settings = _settings()
	provider = (settings.get("provider") or _DEFAULT_PROVIDER).strip().lower()

	try:
		if provider == "osrm":
			return _fetch_osrm(from_point, to_point, settings)
		if provider == "mapbox":
			return _fetch_mapbox(from_point, to_point, settings)
	except Exception:
		# A missing route is a cosmetic loss; an order must still track.
		frappe.log_error(title="aqua route lookup failed")
	return None


def _fetch_osrm(from_point, to_point, settings):
	import requests

	base = (settings.get("osrm_base_url") or _DEFAULT_OSRM_BASE).rstrip("/")
	# OSRM takes lng,lat - the reverse of every other coordinate we handle.
	coords = f"{from_point[1]},{from_point[0]};{to_point[1]},{to_point[0]}"
	response = requests.get(
		f"{base}/route/v1/driving/{coords}",
		params={"overview": "full", "geometries": "geojson"},
		timeout=6,
	)
	response.raise_for_status()

	routes = (response.json() or {}).get("routes") or []
	if not routes:
		return None
	coordinates = ((routes[0] or {}).get("geometry") or {}).get("coordinates") or []
	return [[point[1], point[0]] for point in coordinates if len(point) >= 2] or None


def _fetch_mapbox(from_point, to_point, settings):
	import requests

	token = settings.get("mapbox_token")
	if not token:
		return None

	coords = f"{from_point[1]},{from_point[0]};{to_point[1]},{to_point[0]}"
	response = requests.get(
		f"https://api.mapbox.com/directions/v5/mapbox/driving/{coords}",
		params={"overview": "full", "geometries": "geojson", "access_token": token},
		timeout=6,
	)
	response.raise_for_status()

	routes = (response.json() or {}).get("routes") or []
	if not routes:
		return None
	coordinates = ((routes[0] or {}).get("geometry") or {}).get("coordinates") or []
	return [[point[1], point[0]] for point in coordinates if len(point) >= 2] or None


def _settings():
	"""Routing configuration from site_config, all of it optional."""
	return {
		"provider": frappe.conf.get("aqua_routing_provider"),
		"osrm_base_url": frappe.conf.get("aqua_osrm_base_url"),
		"mapbox_token": frappe.conf.get("aqua_mapbox_token"),
	}


def _cache_key(from_point, to_point, order_name):
	# Rounded to ~11 m: a rider inching forward should reuse the same route
	# rather than mint a new cache entry (and a new provider call) each ping.
	return "aqua:route:{}:{:.4f},{:.4f}:{:.4f},{:.4f}".format(
		order_name or "-", from_point[0], from_point[1], to_point[0], to_point[1]
	)


def _is_number(value):
	return isinstance(value, (int, float)) and not isinstance(value, bool)
