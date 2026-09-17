--!strict
--[[
	A replay-safe subscriber list.

	THE BUG THIS EXISTS TO KILL. DataService fires "this profile is ready" to
	whatever callbacks are registered at that instant. Services register during
	their own start(), but PlayerAdded is connected during init() -- and every
	init() runs before any start(). So a player who joins while the server is
	still booting has their profile loaded against a callback list that is
	empty or half-built, and every service that subscribed later simply never
	hears about them. For the rest of that session.

	It presents as the worst kind of bug: nothing errors, the profile is fine,
	the HUD shows the right coins -- and the player has no base, because
	PlotService was two services later in the start order. A playtester reported
	it as "I don't get assigned a base" and every base sign still read
	"Empty Base", which is exactly what a never-fired callback looks like.

	The fix is that SUBSCRIBING IS ALSO A DELIVERY. A late subscriber is
	immediately given everything that already happened, so registration order
	stops mattering -- which is what DataService's own comment always promised.

	DEPENDENCY-FREE (CLAUDE.md), so Lune can test the ordering properties that
	are impossible to reproduce by hand in a live server.
]]

local Subscribers = {}

export type Registry<K, V> = {
	--- Callbacks, in registration order.
	listeners: { (K, V) -> () },
	--- What has already been delivered, by key, so a late subscriber can be
	--- caught up. The value is kept, not just the fact of it.
	delivered: { [K]: V },
	--- Keys in the order they arrived, because replay must not depend on Luau's
	--- undefined table iteration order -- two servers would otherwise catch a
	--- subscriber up in different orders.
	order: { K },
}

function Subscribers.new<K, V>(): Registry<K, V>
	return { listeners = {}, delivered = {}, order = {} }
end

--- Delivers `value` for `key` to everyone currently listening, and remembers it
--- so anyone who subscribes afterwards is caught up.
---
--- `call` runs each listener; the caller supplies it so this module never
--- needs pcall or any engine API. A listener that throws must not stop the
--- others: one broken service is not allowed to take the rest down with it.
function Subscribers.publish<K, V>(
	registry: Registry<K, V>,
	key: K,
	value: V,
	call: ((K, V) -> (), K, V) -> ()
)
	if registry.delivered[key] == nil then
		table.insert(registry.order, key)
	end
	registry.delivered[key] = value
	for _, listener in registry.listeners do
		call(listener, key, value)
	end
end

--- Registers a listener AND immediately replays everything already delivered.
---
--- This is the whole point: a service that starts late is not punished for it.
function Subscribers.subscribe<K, V>(
	registry: Registry<K, V>,
	listener: (K, V) -> (),
	call: ((K, V) -> (), K, V) -> ()
)
	table.insert(registry.listeners, listener)
	for _, key in registry.order do
		local value = registry.delivered[key]
		if value ~= nil then
			call(listener, key, value)
		end
	end
end

--- Forgets a key, so a player who leaves is not replayed to a service that
--- subscribes after they have gone.
function Subscribers.forget<K, V>(registry: Registry<K, V>, key: K)
	if registry.delivered[key] == nil then
		return
	end
	registry.delivered[key] = nil
	for index, existing in registry.order do
		if existing == key then
			table.remove(registry.order, index)
			break
		end
	end
end

return Subscribers
