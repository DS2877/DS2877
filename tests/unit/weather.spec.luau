--!strict
local h = require("./helpers")
local Economy = require("../../src/shared/Config/Economy")
local Weather = require("../../src/shared/Config/Weather")

h.suite("Weather")

h.test("every weather event maps to a real mutation", function()
	for name in Economy.WEATHER do
		local kind = Weather.KINDS[name]
		h.expectTrue(kind ~= nil, `weather '{name}' has no visual/mutation entry`)
		h.expectTrue(
			Economy.MUTATIONS[(kind :: Weather.Kind).mutation] ~= nil,
			`weather '{name}' maps to unknown mutation '{(kind :: Weather.Kind).mutation}'`
		)
	end
end)

h.test("every mutation is reachable from some weather event", function()
	-- A mutation no event can produce is a mutation no player can ever earn on
	-- a creature they already own.
	local reachable: { [string]: boolean } = {}
	for _, kind in Weather.KINDS do
		reachable[kind.mutation] = true
	end
	for mutation in Economy.MUTATIONS do
		h.expectTrue(reachable[mutation], `mutation '{mutation}' is unreachable from weather`)
	end
end)

h.test("REGRESSION: picking is deterministic for a given roll", function()
	-- Iterating a Luau table is order-undefined. Without the sort, two servers
	-- handed the same roll would pick different weather, and nothing would ever
	-- have flagged it.
	for i = 0, 20 do
		local roll = i / 20
		local first = Weather.pick(Economy.WEATHER, roll)
		for _ = 1, 5 do
			h.expectEqual(Weather.pick(Economy.WEATHER, roll), first, `roll {roll}`)
		end
	end
end)

h.test("the whole 0-1 range picks something valid", function()
	for i = 0, 100 do
		local name = Weather.pick(Economy.WEATHER, i / 100)
		h.expectTrue(Economy.WEATHER[name] ~= nil, `roll {i / 100} picked '{name}'`)
	end
end)

h.test("rarer weather is rarer", function()
	-- Counting hits across the range approximates the weights, which is what
	-- actually decides how often a player sees the good stuff.
	local counts: { [string]: number } = {}
	local samples = 2000
	for i = 0, samples do
		local name = Weather.pick(Economy.WEATHER, i / samples)
		counts[name] = (counts[name] or 0) + 1
	end
	h.expectTrue(
		(counts.golden_glaze or 0) > (counts.galaxy_jelly or 0),
		"the commonest weather should out-appear the rarest"
	)
	-- And the rarest must still be possible at all.
	h.expectTrue((counts.galaxy_jelly or 0) > 0, "galaxy_jelly is unreachable")
end)

h.test("a weather multiplier is always worth having", function()
	for name, entry in Economy.WEATHER do
		h.expectTrue(entry.mult > 1, `weather '{name}' multiplies income by {entry.mult}`)
	end
end)

h.test("players get a warning before it lands", function()
	-- The warning is the interesting decision -- run home and put your best
	-- creatures out. Without it, weather is something that merely happens.
	h.expectTrue(Weather.WARNING_SECONDS > 0, "there must be a warning window")
	h.expectTrue(
		Weather.WARNING_SECONDS < Economy.WEATHER_DURATION,
		"the warning must be shorter than the event"
	)
end)
