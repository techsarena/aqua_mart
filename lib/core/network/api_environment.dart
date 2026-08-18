/// Where the backend lives, and the three facts the Frappe handshake needs.
///
/// The backend is an ERPNext/Frappe app: `/v1/*` is served straight off the
/// site root by a `before_request` hook, so [baseUrl] carries the `/v1`
/// prefix and nothing rewrites it.
///
/// Socket.IO is a **separate port** (Frappe's own realtime server, 9000/9001),
/// never the web port — see [socketUrl].
abstract final class ApiEnvironment {
  static const baseUrl = String.fromEnvironment(
    'AQUA_API_BASE_URL',
    defaultValue: 'http://192.168.1.39:8001/v1',
  );

  /// Socket.IO origin. Frappe's realtime server listens on its own port
  /// (`socketio_port` in common_site_config.json), not the web port.
  static const socketUrl = String.fromEnvironment(
    'AQUA_SOCKET_URL',
    defaultValue: 'http://192.168.1.39:9001',
  );

  /// The Frappe site name — load-bearing for sockets, not decoration.
  ///
  /// Frappe's socket.io middleware namespaces every connection by site and
  /// rejects a mismatch with `Invalid namespace`, so the client must connect
  /// to `/{siteName}` and send it as `X-Frappe-Site-Name`.
  static const siteName = String.fromEnvironment(
    'AQUA_SITE_NAME',
    defaultValue: 'aqua.mart',
  );

  /// The `Origin` sent on the socket handshake.
  ///
  /// This is **not** a CORS formality — Frappe's socket middleware builds the
  /// URL it calls back into (`frappe.realtime.get_user_info`, which is what
  /// turns our Bearer JWT into a user) out of this exact header. Point it at
  /// a host that does not serve the site and the callback 404s, the handshake
  /// fails with `Unauthorized`, and the socket never connects — verified
  /// against a live bench.
  ///
  /// So it must be an origin that **serves the site**. It defaults to the
  /// REST origin, which is correct whenever the API host resolves to the
  /// site (the normal deployment). Override it when they differ — e.g.
  /// hitting the API by IP, or an emulator's `10.0.2.2` alias.
  static const socketOrigin = String.fromEnvironment('AQUA_SOCKET_ORIGIN');

  /// The REST origin without the `/v1` suffix.
  static String get origin {
    if (socketOrigin.isNotEmpty) return socketOrigin;
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }
}
