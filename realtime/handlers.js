/**
 * Aqua Mart socket handlers (API_SPEC 8.3, 8.5).
 *
 * Frappe's socketio server loads apps/<app>/realtime/handlers.js for every
 * installed app and calls it with each authenticated socket. The socket has
 * already been authenticated by frappe's middleware, which calls back into
 * /api/method/frappe.realtime.get_user_info with the client's Authorization
 * header - so our Bearer JWT resolves to a real user before we get here.
 *
 * Rule from 8.3: a client may NEVER ask to join an arbitrary room. Every
 * join below is validated server-side against the authenticated identity by
 * calling aqua_mart.api.realtime.*, which re-derives the actor from the
 * session rather than trusting anything in the payload.
 */

function aqua_handlers(socket) {
	if (!socket.user || socket.user === "Guest") return;

	const call = async (method, args = {}) => {
		const res = await socket.frappe_request(`/api/method/${method}`, args);
		const body = await res.json();
		return body.message;
	};

	// Join the rooms this identity is entitled to: seller:{id} for a seller,
	// rider:{id} for a rider. user:{id} is already joined by frappe itself.
	call("aqua_mart.api.realtime.my_rooms")
		.then((rooms) => {
			(rooms || []).forEach((room) => socket.join(room));
		})
		.catch(() => {
			/* a rooms lookup failure must not kill the connection */
		});

	// --- subscribe:order ---------------------------------------------------
	// A customer joins order:{id} only for their OWN orders, and only while
	// the tracking screen is open. Ownership is validated on every call.
	socket.on("subscribe:order", async (payload) => {
		const order_id = payload && payload.order_id;
		if (!order_id) return;

		try {
			const allowed = await call("aqua_mart.api.realtime.can_watch_order", { order_id });
			if (allowed) socket.join(`order:${order_id}`);
		} catch (e) {
			/* denied - stay out of the room */
		}
	});

	socket.on("unsubscribe:order", (payload) => {
		const order_id = payload && payload.order_id;
		if (order_id) socket.leave(`order:${order_id}`);
	});

	// --- rider:ping --------------------------------------------------------
	// Riders push position every 10s while on a run. A rider not on a run
	// pinging locations is either a bug or someone probing - the server
	// drops it (8.5).
	socket.on("rider:ping", async (payload) => {
		if (!payload || payload.latitude == null || payload.longitude == null) return;

		try {
			await call("aqua_mart.api.realtime.rider_ping", {
				latitude: payload.latitude,
				longitude: payload.longitude,
				heading: payload.heading == null ? "" : payload.heading,
			});
		} catch (e) {
			/* dropped */
		}
	});
}

module.exports = aqua_handlers;
