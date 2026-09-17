--!strict
--[[
	Weather: a server-wide income boost and the only way a creature a player
	already owns can become something rarer.

	THE WARNING IS THE DESIGN. An event is announced fifteen seconds before it
	lands, which turns weather from something that merely happens into a
	decision: run home, get your best creatures out of the book and onto
	pedestals, because only what is placed can mutate. The event itself is the
	payoff; the fifteen seconds are the game.

	MUTATIONS ARE PERMANENT AND SERVER-DECIDED. Each placed Nomling gets one
	roll per event. A mutation multiplies that creature's income forever, so
	this is the single most valuable thing the server hands out for free -- and
	it never touches a creature that already has one, because stacking would
	compound past anything the economy model accounts for.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Net = require(Shared:WaitForChild("Net"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))
local Weather = require(Shared:WaitForChild("Config"):WaitForChild("Weather"))

local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local WeatherService = {}
WeatherService.Name = "WeatherService"

local rng = Random.new()

local activeKind: string? = nil
local activeUntil = 0
--- os.clock() when the next event is expected. The board counts down to it,
--- which is the difference between "weather happens sometimes" and a reason to
--- still be here in four minutes.
local nextEventAt = 0

--- The live income multiplier. IncomeService asks every tick.
function WeatherService.factor(): number
	local kind = activeKind
	if not kind or os.clock() > activeUntil then
		return 1
	end
	local entry = Economy.WEATHER[kind]
	return if entry then entry.mult else 1
end

function WeatherService.current(): (string?, number)
	if not activeKind or os.clock() > activeUntil then
		return nil, 0
	end
	return activeKind, activeUntil - os.clock()
end

--- Seconds until the next event, or nil before the opening quiet period has
--- even been scheduled. Never negative: a due event that has not fired yet
--- reads as 0 rather than counting upwards into nonsense.
function WeatherService.secondsUntilNext(): number?
	if nextEventAt <= 0 then
		return nil
	end
	return math.max(0, nextEventAt - os.clock())
end

local function announce(phase: string, kind: string, seconds: number)
	local spec = Weather.KINDS[kind]
	-- Looked up once and branched on, rather than `(Economy.WEATHER[kind] or {}).mult`.
	-- That `or {}` makes the type a union with an empty table, which has no `mult`
	-- at all -- so the fallback that was meant to make it safe was the thing that
	-- made it unsound.
	local event = Economy.WEATHER[kind]
	local remote = Net.get("Weather") :: RemoteEvent
	remote:FireAllClients({
		phase = phase,
		kind = kind,
		label = if spec then spec.label else kind,
		mutation = if spec then spec.mutation else nil,
		multiplier = if event then event.mult else 1,
		seconds = seconds,
	})
end

--- Rolls mutations across every placed Nomling in the server.
local function applyMutations(kind: string)
	local spec = Weather.KINDS[kind]
	if not spec then
		return
	end

	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end

		local gained = 0
		for key, id in data.pedestals do
			-- The Vault is skipped, and that is the trade the whole feature
			-- turns on (GDD 5.7): vaulted Nomlings are safe but do NOT mutate.
			-- Weather is the only way a creature a player already owns becomes
			-- something rarer, so putting your best one in the fridge costs you
			-- its chance at that as well as its income.
			if tonumber(key) == Economy.VAULT_PEDESTAL then
				continue
			end
			local nomling = Profile.findNomling(data, id)
			-- Never touches a creature that already has one. Stacking mutations
			-- would compound income past anything the economy model accounts for.
			if nomling and not nomling.mutation then
				if rng:NextNumber() < Economy.MUTATION_CHANCE_PER_EVENT then
					nomling.mutation = spec.mutation
					gained += 1
				end
			end
		end

		if gained > 0 then
			-- Re-render so the creature visibly changes: it gains the glow and
			-- the sparkle the moment it mutates, which is the whole reward.
			PlotService.render(player)
			local remote = Net.get("Notify") :: RemoteEvent
			remote:FireClient(
				player,
				`✨ {spec.label} mutated {gained} of your Nomlings! They earn more now.`
			)
			FeedbackService.fire(player, "hatch", nil, {
				rarity = "legendary",
				mutation = spec.mutation,
			})
			-- The VALUE is how many this player gained, so Roblox aggregates a
			-- meaningful total; the mutation goes in a field because it has five
			-- distinct values and fields are cardinality-limited.
			AnalyticsService.report(player, "mutation_gained", gained, {
				mutation = spec.mutation,
				weather_type = kind,
			})
		end
	end
end

local function runEvent()
	local kind = Weather.pick(Economy.WEATHER, rng:NextNumber())

	-- The warning. Only what is on a pedestal can mutate, so this window is a
	-- real decision rather than a courtesy.
	announce("incoming", kind, Weather.WARNING_SECONDS)
	task.wait(Weather.WARNING_SECONDS)

	activeKind = kind
	activeUntil = os.clock() + Economy.WEATHER_DURATION
	announce("started", kind, Economy.WEATHER_DURATION)

	-- Per player, because Roblox custom events are per player -- there is no
	-- server-wide event. Once every 12-20 minutes each, which is cheap, and it
	-- is the only way to learn whether people are PRESENT for weather or
	-- whether it keeps firing into an empty street.
	local event = Economy.WEATHER[kind]
	for _, player in Players:GetPlayers() do
		AnalyticsService.report(player, "weather_started", if event then event.mult else 1, {
			weather_type = kind,
		})
	end

	applyMutations(kind)

	task.wait(Economy.WEATHER_DURATION)
	activeKind = nil
	activeUntil = 0
	announce("ended", kind, 0)
end

function WeatherService.start()
	task.spawn(function()
		-- A quiet opening, so a joining player is not immediately hit with a
		-- banner they have no context for.
		nextEventAt = os.clock() + 120
		task.wait(120)
		while true do
			local ok, err = pcall(runEvent :: () -> any)
			if not ok then
				warn(`[WeatherService] event failed: {err}`)
				activeKind = nil
				activeUntil = 0
			end
			local gap = rng:NextNumber(Economy.WEATHER_INTERVAL_MIN, Economy.WEATHER_INTERVAL_MAX)
			nextEventAt = os.clock() + gap
			task.wait(gap)
		end
	end)
end

return WeatherService
