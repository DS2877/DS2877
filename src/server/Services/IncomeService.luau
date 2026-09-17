--!strict
--[[
	Pays out coins: the steady tick while playing, and the lump sum for time
	spent away.

	The tick is SERVER-SIDE and time-based, never frame-based. A client cannot
	earn faster by running at 120 fps, and a laggy phone does not earn slower.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EggService = require(script.Parent:WaitForChild("EggService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))

local IncomeService = {}
IncomeService.Name = "IncomeService"

local TICK_SECONDS = 1

--- Mutation income multipliers, flattened out of Config once at startup so the
--- per-tick path stays a plain table lookup.
local MUTATION_MULTIPLIER: { [string]: number } = {}
for name, spec in Economy.MUTATIONS do
	MUTATION_MULTIPLIER[name] = if type(spec) == "table"
		then ((spec :: any).incomeMultiplier or 1)
		else spec :: any
end

function IncomeService.perSecond(data: Profile.Data): number
	return Income.perSecond(
		-- The Vault slot is skipped: a vaulted Nomling is safe and does not
		-- earn, which is the whole trade (D-024).
		Profile.placedNomlings(data, Economy.VAULT_PEDESTAL) :: any,
		Economy.BASE_INCOME,
		MUTATION_MULTIPLIER,
		Economy.rebirthMultiplier(data.rebirths),
		WeatherService.factor(),
		Economy.STIPEND_PER_SECOND
	)
end

--- Pays for time spent offline, once, on load.
local function payOffline(player: Player, data: Profile.Data)
	local elapsed = os.time() - data.lastSeen
	local earned = Income.offline(
		IncomeService.perSecond(data),
		elapsed,
		Economy.OFFLINE_EFFICIENCY,
		Economy.OFFLINE_CAP_SECONDS
	)
	if earned > 0 then
		Profile.addCoins(data, earned)
		AnalyticsService.coinFlow(player, "source", "offline", earned)
		print(`[IncomeService] {player.Name} away {elapsed}s, paid {earned}`)
	end
	-- Earning anything at all IS the collect step, and offline pay is the one
	-- moment a returning player's balance moves before they touch anything.
	AnalyticsService.advanceFunnel(player, data)
end

function IncomeService.start()
	DataService.onLoaded(function(player, data)
		payOffline(player, data)
		EggService.sync(player)
	end)

	task.spawn(function()
		-- Measure real elapsed time rather than assuming the wait was exact --
		-- a busy server drifts, and drift would quietly underpay everyone.
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			local delta = now - last
			last = now

			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if not data then
					continue
				end
				local earned = IncomeService.perSecond(data) * delta
				if earned > 0 then
					Profile.addCoins(data, earned)
					-- Earning the first coin is funnel step 4, and income
					-- accrues without a tap, so there is no other moment to
					-- hook it to. Cheap when there is nothing pending: it walks
					-- seven table entries and makes no API call at all.
					AnalyticsService.advanceFunnel(player, data)
				end
			end
		end
	end)

	-- The HUD updates once a second; the tick is separate so the payout rate
	-- and the refresh rate can change independently.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				EggService.sync(player)
			end
		end
	end)

	-- The owner sign, showing name and coins per second (GDD 5.1). It is how you
	-- decide whose base is worth walking into -- a sign with only a name tells a
	-- thief nothing, and a street of identical signs is a street with no targets.
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					local rate = IncomeService.perSecond(data)
					PlotService.setSignFor(
						player,
						`{player.DisplayName}\n{Income.format(rate)}/s · {#data.nomlings} Nomlings`
					)
				end
			end
		end
	end)

	-- One coin flies to the purse roughly every second, from ONE of the
	-- player's Nomlings rather than all of them. Eight coins a second from a
	-- full base would be noise, and the client would cap it anyway.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(1.1)
			for _, player in Players:GetPlayers() do
				local plot = PlotService.plotFor(player)
				local data = DataService.get(player)
				if not plot or not data then
					continue
				end
				local pedestals: { number } = {}
				for key in data.pedestals do
					local index = tonumber(key)
					if index then
						table.insert(pedestals, index)
					end
				end
				if #pedestals == 0 then
					continue
				end
				local pedestal = plot.pedestals[pedestals[rng:NextInteger(1, #pedestals)]]
				if pedestal then
					FeedbackService.fire(player, "coin", pedestal.Position + Vector3.new(0, 4, 0))
				end
			end
		end
	end)
end

return IncomeService
