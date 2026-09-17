--!strict
--[[
	Every event the game reports, and the onboarding funnel.

	WHY THIS MATTERS MORE THAN IT LOOKS. Phase 0 confirmed first-play bounce
	rate -- under 60 s, and 61-180 s -- is one of the most heavily weighted
	signals in Roblox discovery, and that "qualified play sessions" filter
	quick bounces out entirely. Without the funnel we can see that players
	leave and never where they stopped, which is the difference between fixing
	the game and guessing at it. docs/ANALYTICS.md is the spec; this is the
	implementation.

	ANALYTICS MUST NEVER BREAK THE GAME. Every call into Roblox is wrapped:
	a telemetry outage, a throttle or a bad argument has to cost us a data
	point and nothing else. A player losing their session because a metric
	failed would be the worst possible trade, so `report` swallows everything
	and warns once per event name rather than per call.

	NO IDENTIFYING CONTENT, EVER (docs/ANALYTICS.md 1). UserId only, and only
	where Roblox already has it. No display names, no creature names, no chat,
	no free text -- a Nomling's generated name is player-adjacent content and
	does not belong in telemetry.

	Verified against create.roblox.com/docs/reference/engine/classes/
	AnalyticsService on 2026-09-17; signatures are in docs/VERIFY.md.
]]

local AnalyticsService = {}
AnalyticsService.Name = "AnalyticsService"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Funnel = require(Shared:WaitForChild("Logic"):WaitForChild("Funnel"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

--- Roblox accepts a small number of custom fields per event and does not
--- publish the exact cap. Three is the number its own examples use, so that is
--- what we budget for; anything past it is dropped here rather than silently
--- by the service, where we would never find out.
local MAX_CUSTOM_FIELDS = 3

--- Warn once per event name. A broken event fires as often as the thing it
--- measures, and a per-call warning would bury the log it is trying to help.
local warned: { [string]: boolean } = {}

local sessionStart: { [Player]: number } = {}

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[AnalyticsService] {message}`)
end

--- Seconds this player has been in this server. Part of the standard context
--- block, and the only way to tell a bounce from a session.
function AnalyticsService.sessionSeconds(player: Player): number
	local started = sessionStart[player]
	return if started then math.floor(os.clock() - started) else 0
end

--- Trims a field table to what Roblox will accept, and stringifies values.
---
--- Cardinality is the trap here: Roblox limits how many DISTINCT values a
--- field can have, so a raw coin amount as a custom field would blow the
--- budget within an hour. Callers pass buckets and keys, never quantities;
--- amounts go through the value argument, which is numeric and aggregated.
local function fields(raw: { [string]: any }?): { [string]: string }
	local out: { [string]: string } = {}
	if not raw then
		return out
	end
	local keys: { string } = {}
	for key in raw do
		table.insert(keys, key)
	end
	-- Sorted, so which three survive is deterministic rather than dependent on
	-- Luau's undefined table order -- otherwise two servers would report
	-- different fields for the same event.
	table.sort(keys)
	local count = 0
	for _, key in keys do
		if count >= MAX_CUSTOM_FIELDS then
			break
		end
		local value = raw[key]
		if value ~= nil then
			out[key] = tostring(value)
			count += 1
		end
	end
	return out
end

--- One custom event. `value` is the numeric quantity Roblox aggregates.
function AnalyticsService.report(
	player: Player,
	eventName: string,
	value: number?,
	custom: { [string]: any }?
)
	local ok, err = pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1, fields(custom))
	end)
	if not ok then
		warnOnce(eventName, `event '{eventName}' failed: {err}`)
	end
end

--- Advances the onboarding funnel to wherever this profile has got to.
---
--- Safe to call as often as you like -- after any action that might have moved
--- a player forward -- because Funnel.pending() returns only steps that have
--- not been logged, and this writes each one back into the profile as it goes.
--- That is what stops a rejoin re-entering the funnel at the top.
function AnalyticsService.advanceFunnel(player: Player, data: Profile.Data)
	local progress: Funnel.Progress = {
		hatched = data.stats.hatched,
		placed = data.stats.placed,
		-- Having earned anything at all IS the collect step: income accrues
		-- without a tap, so there is no separate action to hook.
		collected = data.stats.coinsEarned > 0,
		eggsBought = data.stats.eggsBought,
		fusionsStarted = data.stats.fusionsStarted,
		fusionsRevealed = data.stats.fusionsRevealed,
	}

	for _, entry in Funnel.pending(progress, data.funnel) do
		-- Marked BEFORE the call, not after. If Roblox throws we lose one data
		-- point; if we marked after and it threw, the step would retry on
		-- every tick for the rest of the session and hammer the service.
		data.funnel[entry.step] = true
		local ok, err = pcall(function()
			RobloxAnalytics:LogOnboardingFunnelStepEvent(player, entry.step, entry.name, {})
		end)
		if not ok then
			warnOnce(entry.name, `funnel step '{entry.name}' failed: {err}`)
		end
	end
end

--- Where coins came from and where they went (docs/ANALYTICS.md 6). Buckets,
--- never raw quantities, in the custom field -- the amount is the value.
function AnalyticsService.coinFlow(
	player: Player,
	direction: "source" | "sink",
	bucket: string,
	amount: number
)
	if amount <= 0 then
		return
	end
	AnalyticsService.report(player, `coins_{direction}`, math.floor(amount), { bucket = bucket })
end

function AnalyticsService.init()
	Players.PlayerAdded:Connect(function(player)
		sessionStart[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
	end)
	-- Anyone already here when the service starts, which is every player on a
	-- server that reloaded scripts and the reason the HUD had this bug once.
	for _, player in Players:GetPlayers() do
		if not sessionStart[player] then
			sessionStart[player] = os.clock()
		end
	end
end

return AnalyticsService
