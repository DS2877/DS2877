--!strict
--[[
	Re-Nom: trade the whole base for a permanent multiplier.

	This is the long game. Everything else in the session loop -- the belt, the
	kitchen, the weather -- feeds a number that eventually buys one of these, and
	each one makes the next hour worth more than the last.

	IT IS IRREVERSIBLE, so it gets more care than anything else in the codebase:
	the cost is re-derived from Config on the server, the profile is saved
	IMMEDIATELY afterwards rather than at the next autosave, and the free restart
	egg is granted in the same breath. A server that crashed between wiping the
	base and granting the egg would leave a player permanently unable to act.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Net = require(Shared:WaitForChild("Net"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local RebirthService = {}
RebirthService.Name = "RebirthService"

--- The best egg tier this rebirth count has unlocked. Used for the restart egg,
--- so a rebirth visibly hands back something better than a Basic.
local function bestEgg(rebirths: number): string
	local best = Economy.STARTER_EGG or "basic"
	local bestUnlock = -1
	-- Sorted for determinism: iterating a Luau table is order-undefined, and two
	-- servers handing out different restart eggs for the same profile would be a
	-- genuinely confusing bug to chase.
	local keys: { string } = {}
	for key in Economy.EGGS do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local egg = Economy.EGGS[key]
		if egg.unlockRebirth <= rebirths and egg.unlockRebirth > bestUnlock then
			best = key
			bestUnlock = egg.unlockRebirth
		end
	end
	return best
end

RebirthService.bestEgg = bestEgg

function RebirthService.perform(player: Player): (boolean, string?)
	if not NetService.allow(player, "Rebirth") then
		return false, "Steady on!"
	end

	local data = DataService.get(player)
	if not data then
		return false, "Still loading -- try again in a second."
	end

	-- Re-derived here, never sent by the client.
	local cost = Economy.rebirthCost(data.rebirths)
	if data.coins < cost then
		local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
		return false, `Re-Nom costs {Income.format(cost)} coins.`
	end

	if not Profile.rebirth(data, cost) then
		return false, "Could not Re-Nom right now."
	end

	-- Reported BEFORE the wipe reads the counters, because Profile.rebirth has
	-- already zeroed the coins this event is meant to describe.
	AnalyticsService.report(player, "rebirth", data.rebirths, {
		rebirth_number = data.rebirths,
		playtime_bucket = if data.stats.playtime < 1800
			then "under_30m"
			elseif data.stats.playtime < 7200 then "under_2h"
			else "over_2h",
	})
	AnalyticsService.coinFlow(player, "sink", "rebirth", cost)

	-- The restart egg, in the same breath as the wipe. Without it the player has
	-- no coins, no income and no way to buy anything (D-008).
	local egg = bestEgg(data.rebirths)
	local seconds = Economy.FIRST_EGG_HATCH_SECONDS
	Profile.grantStarterEgg(data, egg, os.time() + seconds, seconds)

	PlotService.render(player)

	-- Saved immediately. A crash between the wipe and the next autosave would
	-- cost a player their whole base and give nothing back.
	DataService.save(player, false)

	local remote = Net.get("Notify") :: RemoteEvent
	remote:FireClient(
		player,
		`✨ Re-Nom {data.rebirths}! Everything earns ×{string.format(
			"%.1f",
			Economy.rebirthMultiplier(data.rebirths)
		)} now, and a {egg} egg is hatching.`
	)
	FeedbackService.fire(player, "hatch", nil, { rarity = "mythic" })

	return true, nil
end

function RebirthService.start()
	local remote = Net.get("Rebirth") :: RemoteFunction
	remote.OnServerInvoke = function(player)
		return RebirthService.perform(player)
	end
end

return RebirthService
