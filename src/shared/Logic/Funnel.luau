--!strict
--[[
	The onboarding funnel: which first-play beats a player has reached.

	"The most important instrumentation in the project" (docs/ANALYTICS.md 2).
	Phase 0 confirmed first-play bounce rate -- under 60 s, and 61-180 s -- is
	one of the most heavily weighted discovery signals Roblox publishes, and
	that "qualified play sessions" filter quick bounces out entirely. If we
	cannot see where a new player stops, we cannot fix the reason they left,
	and that is the difference between a game being found and not.

	DEPENDENCY-FREE (CLAUDE.md), so Lune tests it without a DataModel. The
	server owns the Roblox API call; this owns the part that can actually be
	wrong.

	THREE PROPERTIES THIS GUARANTEES, and each is a bug that otherwise shows up
	as unexplainable data months later:

	1. EACH STEP FIRES ONCE, EVER. Roblox's onboarding funnel counts a player
	   once per step; firing step 3 twice would inflate it above step 2 and
	   make the funnel read as though players go backwards.

	2. STEPS FIRE IN ORDER. A player who buys a second egg before the tutorial
	   notices they placed their first must still record 3 then 4 then 5, or
	   the drop-off between any two steps is meaningless.

	3. IT SURVIVES A REJOIN. Progress lives in the profile, so a player who
	   leaves after step 3 and comes back does not re-enter the funnel at the
	   top and quietly double every early step.
]]

local Funnel = {}

--- In order. `step` is what Roblox records; `name` is what we read in the
--- dashboard. NEVER renumber or rename a live step -- the history breaks and
--- there is no way to repair it after the fact (docs/ANALYTICS.md 1).
export type Step = {
	step: number,
	name: string,
	--- Target time from spawn, in seconds. Not enforced anywhere: it is the
	--- number the funnel is judged against when we read it back.
	target: number,
}

Funnel.STEPS = {
	{ step = 1, name = "ftue_spawned", target = 0 },
	{ step = 2, name = "ftue_first_hatch", target = 5 },
	{ step = 3, name = "ftue_first_placed", target = 30 },
	{ step = 4, name = "ftue_first_collect", target = 45 },
	{ step = 5, name = "ftue_second_egg_bought", target = 60 },
	{ step = 6, name = "ftue_first_fusion_started", target = 90 },
	{ step = 7, name = "ftue_first_fusion_revealed", target = 120 },
} :: { Step }

Funnel.LAST_STEP = 7

--- What a player has reached, given the counters a profile already keeps.
---
--- Derived from state rather than from events, for the same reason the
--- tutorial is: a derived step cannot get stuck, cannot drift from what the
--- player can actually see, and is correct immediately on a rejoin.
export type Progress = {
	hatched: number,
	placed: number,
	collected: boolean,
	eggsBought: number,
	fusionsStarted: number,
	fusionsRevealed: number,
}

--- The highest step this progress satisfies. 0 means not even spawned, which
--- only happens before the server has seen the player at all.
function Funnel.reached(progress: Progress): number
	local highest = 1
	if progress.hatched >= 1 then
		highest = 2
	end
	if progress.placed >= 1 and highest == 2 then
		highest = 3
	elseif progress.placed >= 1 and highest > 2 then
		highest = math.max(highest, 3)
	end
	if progress.collected and highest >= 3 then
		highest = math.max(highest, 4)
	end
	-- The SECOND egg: the first one is granted, so buying one is the first
	-- real economic decision a player makes.
	if progress.eggsBought >= 1 and highest >= 4 then
		highest = math.max(highest, 5)
	end
	if progress.fusionsStarted >= 1 and highest >= 5 then
		highest = math.max(highest, 6)
	end
	if progress.fusionsRevealed >= 1 and highest >= 6 then
		highest = math.max(highest, 7)
	end
	return highest
end

--- Which steps still need logging, given what has already been logged.
---
--- Returns them in ascending order and never returns one already in `logged`,
--- which is what holds properties 1 and 2 above. A player who leaps from step
--- 2 to step 5 in one action still gets 3, 4 and 5 recorded in sequence, so
--- the funnel reads as a funnel rather than as a cliff.
function Funnel.pending(progress: Progress, logged: { [number]: boolean }): { Step }
	local reached = Funnel.reached(progress)
	local out: { Step } = {}
	for _, entry in Funnel.STEPS do
		if entry.step <= reached and not logged[entry.step] then
			table.insert(out, entry)
		end
	end
	return out
end

--- True once a player has finished onboarding. Part of the standard context
--- block on every other event, so every metric can be split by whether the
--- player had found their feet yet.
function Funnel.isComplete(logged: { [number]: boolean }): boolean
	return logged[Funnel.LAST_STEP] == true
end

return Funnel
