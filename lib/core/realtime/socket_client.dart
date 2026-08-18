import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/api_environment.dart';
import '../storage/token_storage.dart';
import 'socket_events.dart';

/// Connection state, for the "reconnecting…" affordances.
enum SocketStatus { disconnected, connecting, connected }

/// The app's single Socket.IO connection (API_SPEC 8).
///
/// Sockets are an **accelerator, never a source of truth** (8.6): every screen
/// still works over REST alone. Nothing here is the only way the app learns
/// something — listeners refresh state that a REST call could equally supply.
///
/// ### Why the handshake looks like this
///
/// The server is Frappe's own Socket.IO server, whose auth middleware
/// (`frappe/realtime/middlewares/authenticate.js`) is stricter than the bare
/// spec suggests, and all three of these are rejections rather than warnings:
///
/// 1. **Namespace = site name.** It compares the connection namespace against
///    the resolved site and fails with `Invalid namespace` otherwise — so we
///    connect to `/{siteName}`, not `/`.
/// 2. **Auth travels in the `Authorization` header**, not in `auth.token`.
///    The middleware forwards that header verbatim to
///    `/api/method/frappe.realtime.get_user_info` to identify the user; a
///    payload-only token never reaches it, and the socket resolves to Guest.
/// 3. **`Origin` must match `Host`.** It compares hostnames and rejects a
///    mismatch, so the origin is pinned to the REST host.
class SocketClient {
  SocketClient({required TokenStorage tokens}) : _tokens = tokens;

  final TokenStorage _tokens;

  io.Socket? _socket;

  final _status = StreamController<SocketStatus>.broadcast();

  /// Rooms are joined server-side, but `order:{id}` is opt-in per screen.
  /// Tracked so a reconnect can re-subscribe — the server does not remember.
  final _watchedOrders = <String>{};

  /// Fan-out per event name, so many widgets can watch one event.
  final _streams = <String, StreamController<Map<String, dynamic>>>{};

  Stream<SocketStatus> get status => _status.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Events for [event], as broadcast JSON maps.
  ///
  /// Subscribing does not connect — call [connect] once the user is signed in.
  Stream<Map<String, dynamic>> on(String event) {
    final controller = _streams.putIfAbsent(
      event,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );

    // A socket that is already up needs the handler attached now; otherwise
    // `_bind` picks the event up when the connection is built.
    final socket = _socket;
    if (socket != null && !_bound.contains(event)) _listen(socket, event);

    return controller.stream;
  }

  final _bound = <String>{};

  /// Opens the connection. Safe to call repeatedly — a live socket is kept.
  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) return; // Signed out: nothing to join.

    _status.add(SocketStatus.connecting);

    // The namespace IS the site name (see the class doc).
    final url = '${ApiEnvironment.socketUrl}/${ApiEnvironment.siteName}';

    final socket = io.io(
      url,
      io.OptionBuilder()
          // Skip the HTTP long-poll upgrade dance; the headers below are
          // what authenticate us and they ride on the websocket request.
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            'Authorization': 'Bearer $token',
            'Origin': ApiEnvironment.origin,
            'X-Frappe-Site-Name': ApiEnvironment.siteName,
          })
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      _status.add(SocketStatus.connected);
      // On reconnect the server has no memory of our order subscriptions
      // (8.6), so they are replayed rather than assumed.
      for (final id in _watchedOrders) {
        socket.emit(SocketEvents.subscribeOrder, {'order_id': id});
      }
    });

    socket.onDisconnect((_) => _status.add(SocketStatus.disconnected));

    // A refused handshake is usually an expired token. Reconnecting with the
    // same one would just spin, so the socket is torn down and the next
    // connect() reads a freshly refreshed token from storage.
    socket.onConnectError((_) {
      _status.add(SocketStatus.disconnected);
      _teardown();
    });

    for (final event in _streams.keys) {
      _listen(socket, event);
    }

    socket.connect();
  }

  void _listen(io.Socket socket, String event) {
    _bound.add(event);
    socket.on(event, (payload) {
      if (payload is Map) {
        _streams[event]?.add(Map<String, dynamic>.from(payload));
      }
    });
  }

  /// Watch one order's room — only while its tracking screen is open (8.3).
  void subscribeToOrder(String orderId) {
    _watchedOrders.add(orderId);
    _socket?.emit(SocketEvents.subscribeOrder, {'order_id': orderId});
  }

  void unsubscribeFromOrder(String orderId) {
    _watchedOrders.remove(orderId);
    _socket?.emit(SocketEvents.unsubscribeOrder, {
      'order_id': orderId,
    });
  }

  /// A rider's position, at most every 10s while on a run (8.5). The server
  /// drops pings from a rider who is not on an active run.
  void sendRiderPing({
    required double latitude,
    required double longitude,
    double? heading,
  }) {
    _socket?.emit(SocketEvents.riderPing, {
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
    });
  }

  /// Drops the connection but keeps the event streams, so a later [connect]
  /// (after a token refresh, or a new sign-in) resumes every subscriber.
  void _teardown() {
    _socket?.dispose();
    _socket = null;
    _bound.clear();
  }

  /// Called on sign-out — also forgets which orders were being watched.
  void disconnect() {
    _watchedOrders.clear();
    _teardown();
    _status.add(SocketStatus.disconnected);
  }

  /// Reconnects with a fresh token, after a refresh or a role switch.
  Future<void> reconnect() async {
    _teardown();
    await connect();
  }

  void dispose() {
    _teardown();
    for (final controller in _streams.values) {
      controller.close();
    }
    _streams.clear();
    _status.close();
  }
}
