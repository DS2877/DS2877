--!strict
--[[
	Buying and hatching eggs.

	THE SERVER DECIDES EVERYTHING. The client sends a tier key and nothing
	else -- no price, no rarity, no roll. Price comes from Config, the roll
	happens here, and both are re-derived on every call rather than trusted
	from anything the client said (docs/TECH.md, brief 5.1).

	THE ROLL HAPPENS ON CLAIM, not on purchase. If the outcome were decided at
	purchase and merely revealed later, a client that could read its own memory
	would know what it got before the reveal -- and the reveal is the product.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Odds = require(Shared:WaitForChild("Logic"):WaitForChild("Odds"))
local NameGen = require(Shared:WaitForChild("Logic"):WaitForChild("NameGen"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local BookService = require(script.Parent:WaitForChild("BookService"))
-- Safe at the top: FusionService requires DataService, FeedbackService,
-- NetService and PlotService, none of which require this module back.
local FusionService = require(script.Parent:WaitForChild("FusionService"))
local RebirthService = require(script.Parent:WaitForChild("RebirthService"))
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local EggService = {}
EggService.Name = "EggService"

local rng = Random.new()

--- Every refusal is a sentence a child can read. "Invalid request" is not an
--- acceptable message for a nine-year-old (docs/COMPLIANCE.md 8).
local function refuse(reason: string): (boolean, string)
	return false, reason
end

function EggService.buy(player: Player, eggKey: unknown): (boolean, string?)
	if not NetService.allow(player, "BuyEgg") then
		return refuse("One at a time!")
	end
	if type(eggKey) ~= "string" then
		return refuse("That egg does not exist.")
	end

	local data = DataService.get(player)
	if not data then
		return refuse("Still loading your base -- try again in a second.")
	end

	local egg = Economy.EGGS[eggKey]
	if not egg then
		return refuse("That egg does not exist.")
	end
	if data.rebirths < egg.unlockRebirth then
		return refuse(`Unlocks at Re-Nom {egg.unlockRebirth}.`)
	end
	if #data.incubators >= Economy.INCUBATORS_BASE then
		return refuse("Your incubators are full.")
	end
	if #data.nomlings >= Economy.INVENTORY_CAP then
		return refuse("Your Nomling book is full.")
	end

	-- Price is computed here, never sent by the client. It scales with rebirth
	-- count (docs/DECISIONS.md D-010), so a client-supplied price would be a
	-- free discount.
	local price = Economy.eggPrice(eggKey, data.rebirths)
	if not Profile.spendCoins(data, price) then
		return refuse("Not enough coins yet.")
	end

	data.stats.eggsBought += 1
	AnalyticsService.report(player, "egg_bought", price, { egg_tier = eggKey, source = "market" })
	AnalyticsService.coinFlow(player, "sink", "egg", price)
	AnalyticsService.advanceFunnel(player, data)

	table.insert(data.incubators, {
		eggKey = eggKey,
		readyAt = os.time()
			+ (if data.stats.hatched == 0 then Economy.FIRST_EGG_HATCH_SECONDS else egg.hatch),
	})

	EggService.sync(player)
	return true, nil
end

function EggService.claim(player: Player, slot: unknown): (boolean, string?)
	if not NetService.allow(player, "ClaimHatch") then
		return refuse("One at a time!")
	end

	local data = DataService.get(player)
	if not data then
		return refuse("Still loading your base -- try again in a second.")
	end

	local index = tonumber(slot)
	if not index or index % 1 ~= 0 then
		return refuse("That egg is not there.")
	end
	local incubator = data.incubators[index]
	if not incubator then
		return refuse("That egg is not there.")
	end
	if os.time() < incubator.readyAt then
		return refuse("Not ready yet!")
	end

	local egg = Economy.EGGS[incubator.eggKey]
	if not egg then
		-- A tier removed by a content update. Drop the incubator rather than
		-- leaving the player with a slot they can never clear.
		table.remove(data.incubators, index)
		EggService.sync(player)
		return refuse("That egg is no longer available -- your slot is free again.")
	end

	-- The roll. Integer ppm out of exactly 1,000,000, which is the disclosed
	-- number (docs/COMPLIANCE.md 2). Odds.assertValid would have failed CI long
	-- before here if the table did not sum.
	local roll = rng:NextInteger(0, 999_999)
	local rarity = Odds.pick(egg.odds, roll)

	local species = Nomlings.SPECIES[rng:NextInteger(1, #Nomlings.SPECIES)]
	local hatched: Profile.Nomling = {
		id = "",
		snack = species.snack,
		animal = species.animal,
		gen = 1,
		affix = nil,
		mutation = nil,
		rarity = rarity,
		seed = NameGen.seedFor(species.id, species.id, 1, nil),
	}

	local stored = Profile.addNomling(data, hatched, Economy.INVENTORY_CAP)
	if not stored then
		return refuse("Your Nomling book is full.")
	end
	local isNew = BookService.record(data, stored)

	table.remove(data.incubators, index)

	-- Auto-place if there is room. One fewer tap in the first sixty seconds,
	-- which is the stretch of the game we can least afford to complicate.
	local free = PlotService.firstFreePedestal(data)
	if free then
		Profile.place(data, stored.id, free, Economy.PEDESTALS_BASE)
	end

	AnalyticsService.report(player, "egg_hatched", 1, {
		egg_tier = incubator.eggKey,
		rarity = rarity,
		was_skipped = false,
	})
	if free then
		AnalyticsService.report(player, "nomling_placed", 1, { rarity = rarity, gen = 1 })
	end
	-- After both, so a hatch that also auto-places advances two steps at once
	-- and still records them in order.
	AnalyticsService.advanceFunnel(player, data)

	PlotService.render(player)
	EggService.sync(player)

	-- The reveal. Position is the character, because a hatch has no world
	-- object of its own until the creature lands.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	FeedbackService.fire(
		player,
		"hatch",
		if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 3, 0) else nil,
		{ rarity = rarity, mutation = hatched.mutation }
	)

	if isNew then
		local notify = Net.get("Notify") :: RemoteEvent
		notify:FireClient(player, `📖 NEW! {stored.snack} {stored.animal} added to your book.`)
	end

	return true, nil
end

--- The client-visible snapshot. Sent whole because it is small, which removes
--- a class of "client and server disagree" bugs that partial updates invite.
function EggService.snapshot(data: Profile.Data): { [string]: any }
	local prices: { [string]: number } = {}
	for eggKey, egg in Economy.EGGS do
		if data.rebirths >= egg.unlockRebirth then
			prices[eggKey] = Economy.eggPrice(eggKey, data.rebirths)
		end
	end
	return {
		coins = data.coins,
		-- Computed here from the pure Income module rather than asked of
		-- IncomeService, which requires this module -- the other direction
		-- would be a cycle.
		perSecond = Income.perSecond(
			Profile.placedNomlings(data) :: any,
			Economy.BASE_INCOME,
			Economy.MUTATIONS,
			Economy.rebirthMultiplier(data.rebirths),
			-- The live weather factor, so the HUD's rate matches what the
			-- player is actually being paid during an event.
			WeatherService.factor(),
			-- Pocket money, so the HUD's rate matches what IncomeService pays.
			-- Two places computing income from the same module must pass the
			-- same arguments or the purse ticks at a rate the player is not
			-- actually earning.
			Economy.STIPEND_PER_SECOND
		),
		rebirths = data.rebirths,
		nomlings = #data.nomlings,
		-- The actual roster, so the fusion picker can show what the player
		-- owns. Trimmed to what the UI draws: no seeds, no ids beyond the
		-- handle it needs to send back.
		roster = (function()
			local list = {}
			for _, n in data.nomlings do
				table.insert(list, {
					id = n.id,
					snack = n.snack,
					animal = n.animal,
					gen = n.gen,
					mutation = n.mutation,
					rarity = n.rarity,
					placed = Profile.pedestalOf(data, n.id) ~= nil,
				})
			end
			return list
		end)(),
		-- The tutorial reads these to work out which step the player is on,
		-- so progress survives a rejoin instead of restarting the lesson.
		hatched = data.stats.hatched,
		playtime = data.stats.playtime,
		placed = data.pedestals,
		-- A COUNT as well as the map. `placed` is a pedestal-index -> id
		-- table, so any client that wants "how many are out?" either walks it
		-- or, as the HUD first did, compares a table against a number and
		-- throws. One number on the wire is cheaper than both.
		placedCount = #Profile.placedNomlings(data),
		incubators = data.incubators,
		prices = prices,
		-- The best tier this player has unlocked, so the buy button follows
		-- their progress instead of being wired to "basic" forever.
		bestEgg = RebirthService.bestEgg(data.rebirths),
		rebirthCost = Economy.rebirthCost(data.rebirths),
		rebirthMultiplier = Economy.rebirthMultiplier(data.rebirths),
		nextMultiplier = Economy.rebirthMultiplier(data.rebirths + 1),
		now = os.time(),
		-- Filled in by EggService.sync, which can see FusionService. The
		-- snapshot builder itself stays free of that dependency.
		fusion = nil,
	}
end

function EggService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local snapshot = EggService.snapshot(data)
	snapshot.fusion = FusionService.statusFor(player)

	-- WHERE HOME IS, sent rather than looked up on the client. Under
	-- StreamingEnabled with a 512-stud radius on a 520-stud street, a base at
	-- the far end is simply not replicated -- so the client's own search for
	-- its pad fails exactly when the player is furthest from home and most
	-- needs pointing at it. "I don't seem to get a base, or it's not obvious
	-- how to find it" is what that looks like from the outside.
	local baseX, baseZ, baseIndex = PlotService.baseCenter(player)
	snapshot.baseX = baseX
	snapshot.baseZ = baseZ
	snapshot.baseIndex = baseIndex

	local remote = Net.get("ProfileSync") :: RemoteEvent
	remote:FireClient(player, snapshot)
end

function EggService.init()
	local buy = Net.get("BuyEgg") :: RemoteFunction
	buy.OnServerInvoke = function(player, eggKey)
		return EggService.buy(player, eggKey)
	end

	local claim = Net.get("ClaimHatch") :: RemoteFunction
	claim.OnServerInvoke = function(player, slot)
		return EggService.claim(player, slot)
	end
end

function EggService.start()
	DataService.onLoaded(function(player)
		EggService.sync(player)
	end)

	-- Keep clients' incubator timers honest without them asking.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				EggService.sync(player)
			end
		end
	end)
end

return EggService
