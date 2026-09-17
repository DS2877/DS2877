--!strict
local h = require("./helpers")
local Subscribers = require("../../src/shared/Logic/Subscribers")

h.suite("Replay-safe subscribers")

--- A `call` that just invokes, so tests see ordering rather than scheduling.
local function direct(listener: (string, number) -> (), key: string, value: number)
	listener(key, value)
end

h.test("REGRESSION: a listener that subscribes LATE still hears about it", function()
	-- The bug this module exists for. DataService connects PlayerAdded in
	-- init(), every init() runs before any start(), and PlotService subscribes
	-- in ITS start() -- so a player who joins while the server boots loaded
	-- their profile against an empty listener list and was never assigned a
	-- base. Nothing errored. Every base sign just stayed "Empty Base".
	local registry = Subscribers.new()
	local seen: { string } = {}

	Subscribers.publish(registry, "philip", 1, direct)
	Subscribers.subscribe(registry, function(key)
		table.insert(seen, key)
	end, direct)

	h.expectEqual(#seen, 1, "the late subscriber was caught up")
	h.expectEqual(seen[1], "philip")
end)

h.test("an early listener hears it once, not twice", function()
	local registry = Subscribers.new()
	local count = 0
	Subscribers.subscribe(registry, function()
		count += 1
	end, direct)
	Subscribers.publish(registry, "philip", 1, direct)
	h.expectEqual(count, 1, "delivered exactly once")
end)

h.test("replay is in arrival order, not table order", function()
	-- Luau's table iteration order is undefined, so replaying from the map
	-- would catch a late service up in a different order on different servers.
	local registry = Subscribers.new()
	for _, name in { "a", "b", "c", "d" } do
		Subscribers.publish(registry, name, 1, direct)
	end
	local seen: { string } = {}
	Subscribers.subscribe(registry, function(key)
		table.insert(seen, key)
	end, direct)
	h.expectEqual(table.concat(seen, ""), "abcd", "arrival order preserved")
end)

h.test("a forgotten key is not replayed", function()
	-- A player who left must not be handed to a service that subscribes
	-- afterwards, or it would assign a base to somebody who is gone.
	local registry = Subscribers.new()
	Subscribers.publish(registry, "philip", 1, direct)
	Subscribers.forget(registry, "philip")

	local seen = 0
	Subscribers.subscribe(registry, function()
		seen += 1
	end, direct)
	h.expectEqual(seen, 0, "nothing replayed")
end)

h.test("re-publishing the same key does not duplicate its replay", function()
	-- A profile can be re-delivered (a reload, a re-acquire). The replay list
	-- must still name that player once, or a late subscriber assigns twice.
	local registry = Subscribers.new()
	Subscribers.publish(registry, "philip", 1, direct)
	Subscribers.publish(registry, "philip", 2, direct)

	local seen: { number } = {}
	Subscribers.subscribe(registry, function(_, value)
		table.insert(seen, value)
	end, direct)
	h.expectEqual(#seen, 1, "replayed once")
	h.expectEqual(seen[1], 2, "with the latest value")
end)

h.test("one broken listener does not stop the others", function()
	-- `call` is supplied by the caller precisely so the engine-side can pcall.
	local registry = Subscribers.new()
	local reached = false
	local guarded = function(listener: (string, number) -> (), key: string, value: number)
		pcall(listener, key, value)
	end
	Subscribers.subscribe(registry, function()
		error("this service is broken")
	end, guarded)
	Subscribers.subscribe(registry, function()
		reached = true
	end, guarded)
	Subscribers.publish(registry, "philip", 1, guarded)
	h.expectTrue(reached, "the second listener still ran")
end)
