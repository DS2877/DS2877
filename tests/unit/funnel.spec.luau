--!strict
local h = require("./helpers")
local Funnel = require("../../src/shared/Logic/Funnel")

h.suite("Onboarding funnel")

local function progress(over: { [string]: any }?): Funnel.Progress
	local base: Funnel.Progress = {
		hatched = 0,
		placed = 0,
		collected = false,
		eggsBought = 0,
		fusionsStarted = 0,
		fusionsRevealed = 0,
	}
	for key, value in (over or {}) do
		(base :: any)[key] = value
	end
	return base
end

h.test("the step list matches docs/ANALYTICS.md and never renumbers", function()
	-- Renaming or renumbering a live step breaks the history irreparably: the
	-- dashboard has no way to know that old step 4 and new step 4 are
	-- different things. Pinning them here makes that an explicit decision
	-- rather than a refactor somebody does on a Tuesday.
	h.expectEqual(#Funnel.STEPS, 7, "seven beats")
	local expected = {
		"ftue_spawned",
		"ftue_first_hatch",
		"ftue_first_placed",
		"ftue_first_collect",
		"ftue_second_egg_bought",
		"ftue_first_fusion_started",
		"ftue_first_fusion_revealed",
	}
	for index, name in expected do
		h.expectEqual(Funnel.STEPS[index].step, index, `step {index} number`)
		h.expectEqual(Funnel.STEPS[index].name, name, `step {index} name`)
	end
end)

h.test("a player who has just spawned is at step 1", function()
	h.expectEqual(Funnel.reached(progress()), 1)
end)

h.test("progress advances one beat at a time", function()
	h.expectEqual(Funnel.reached(progress({ hatched = 1 })), 2)
	h.expectEqual(Funnel.reached(progress({ hatched = 1, placed = 1 })), 3)
	h.expectEqual(Funnel.reached(progress({ hatched = 1, placed = 1, collected = true })), 4)
	h.expectEqual(
		Funnel.reached(progress({ hatched = 1, placed = 1, collected = true, eggsBought = 1 })),
		5
	)
end)

h.test("REGRESSION: a later beat cannot skip an earlier one", function()
	-- Fusing without ever having collected a coin would otherwise report step
	-- 6 while steps 4 and 5 never fired, and the funnel would show more
	-- players at the bottom than in the middle.
	local leapfrog = progress({ hatched = 1, fusionsStarted = 3, fusionsRevealed = 3 })
	h.expectEqual(Funnel.reached(leapfrog), 2, "still only at hatch")
end)

h.test("REGRESSION: a step is never logged twice", function()
	-- Roblox counts a player once per onboarding step. A second log of step 3
	-- inflates it past step 2 and the funnel reads as though players move
	-- backwards through onboarding.
	local full = progress({
		hatched = 1,
		placed = 1,
		collected = true,
		eggsBought = 2,
		fusionsStarted = 1,
		fusionsRevealed = 1,
	})
	local logged: { [number]: boolean } = {}
	local first = Funnel.pending(full, logged)
	h.expectEqual(#first, 7, "all seven on the first pass")
	for _, entry in first do
		logged[entry.step] = true
	end
	h.expectEqual(#Funnel.pending(full, logged), 0, "nothing pending on the second pass")
end)

h.test("REGRESSION: rejoining does not re-enter the funnel at the top", function()
	-- Progress lives in the profile. A player who left after placing their
	-- first Nomling and came back must not log steps 1-3 again, or every early
	-- step is inflated by however often people rejoin.
	local returning = progress({ hatched = 1, placed = 1 })
	local logged = { [1] = true, [2] = true, [3] = true }
	h.expectEqual(#Funnel.pending(returning, logged), 0, "already recorded")
end)

h.test("a leap forward still records every step in between, in order", function()
	local leapt = progress({ hatched = 1, placed = 1, collected = true, eggsBought = 1 })
	local pending = Funnel.pending(leapt, { [1] = true, [2] = true })
	h.expectEqual(#pending, 3, "steps 3, 4 and 5")
	h.expectEqual(pending[1].step, 3)
	h.expectEqual(pending[2].step, 4)
	h.expectEqual(pending[3].step, 5)
end)

h.test("onboarding is complete only at the last step", function()
	h.expectTrue(not Funnel.isComplete({ [1] = true, [6] = true }), "six is not seven")
	h.expectTrue(Funnel.isComplete({ [7] = true }), "seven finishes it")
end)
