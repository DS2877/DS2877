--!strict
--[[
	The Fusion Lab: two Nomlings in, one that has never existed out.

	This is the product (docs/TITLES.md). The market leader already has
	stealing, hatching, income pets and a fuse machine; what it does not have is
	a creature nobody has seen, with a generated name, and a permanent record of
	who made it first.

	THE SERVER DECIDES EVERYTHING. The client names two ids it owns. Which
	creature comes out, what tier it is, whether it mutated and whether it is a
	World First are all decided here, from the profile, and never trusted from
	the client.

	WORLD FIRST is claimed with a DataStore UpdateAsync -- first writer wins,
	across every server, forever. It stores a UserId and never a display name,
	so a Right-to-Erasure request can anonymise a person to "A Nomling
	Scientist" with one field write instead of deleting the record and letting
	someone re-claim a first that already happened (docs/DECISIONS.md D-013).
]]

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local FusionRules = require(Shared:WaitForChild("Logic"):WaitForChild("FusionRules"))
local NameGen = require(Shared:WaitForChild("Logic"):WaitForChild("NameGen"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local BookService = require(script.Parent:WaitForChild("BookService"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local FusionService = {}
FusionService.Name = "FusionService"

local firstsStore = DataStoreService:GetDataStore("WorldFirsts_v1")
local WORLD_FIRST_TOPIC = "NomlingWorldFirst"

local rng = Random.new()

local CONFIG: FusionRules.Config = {
	MAX_GEN = Economy.MAX_GEN,
	FUSION_UPGRADE_CHANCE_SAME_TIER = Economy.FUSION_UPGRADE_CHANCE_SAME_TIER,
	FUSION_UPGRADE_CHANCE_DIFF_TIER = Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER,
	FUSION_MUTATION_INHERIT_CHANCE = Economy.FUSION_MUTATION_INHERIT_CHANCE,
	RARITY_ORDER = Economy.RARITY_ORDER,
}

type Pending = {
	player: Player,
	child: FusionRules.Child,
	name: string,
	comboKey: string,
	readyAt: number,
	seed: number,
}

local pending: { [Player]: Pending } = {}

local function speciesFor(snack: string, animal: string)
	return Nomlings.BY_ID[`{snack}_{animal}`]
end

--- Tries to claim the World First for a combination. Returns true when this
--- player got it. Never errors: a DataStore outage must not cost a player the
--- creature they just made, so a failed claim simply is not a first.
local function claimWorldFirst(key: string, userId: number): boolean
	local won = false
	local ok, err = pcall(function()
		firstsStore:UpdateAsync(`firsts/{key}`, function(existing: any): any?
			if existing ~= nil then
				return nil -- somebody already has it; abort without writing
			end
			won = true
			-- UserId only, never a display name. See D-013.
			return { userId = userId, at = os.time() }
		end)
	end)
	if not ok then
		warn(`[FusionService] world-first claim failed for {key}: {err}`)
		return false
	end
	return won
end

function FusionService.start()
	local startRemote = Net.get("StartFusion") :: RemoteFunction
	startRemote.OnServerInvoke = function(player, idA, idB)
		return FusionService.start_(player, idA, idB)
	end

	local claimRemote = Net.get("ClaimFusion") :: RemoteFunction
	claimRemote.OnServerInvoke = function(player)
		return FusionService.claim(player)
	end

	-- A World First on another server should be seen on this one. The whole
	-- point is that it is the FIRST, anywhere.
	pcall(function()
		MessagingService:SubscribeAsync(WORLD_FIRST_TOPIC, function(message)
			local data = (message :: any).Data
			if type(data) ~= "table" then
				return
			end
			local remote = Net.get("WorldFirst") :: RemoteEvent
			remote:FireAllClients(data)
		end)
	end)
end

function FusionService.start_(player: Player, idA: unknown, idB: unknown): (boolean, string?)
	if not NetService.allow(player, "StartFusion") then
		return false, "One at a time!"
	end
	if type(idA) ~= "string" or type(idB) ~= "string" then
		return false, "Pick two Nomlings to fuse."
	end

	local data = DataService.get(player)
	if not data then
		return false, "Still loading your base -- try again in a second."
	end
	if pending[player] then
		return false, "The lab is already busy."
	end

	local a = Profile.findNomling(data, idA)
	local b = Profile.findNomling(data, idB)
	local ok, reason = FusionRules.check(a :: any, b :: any, CONFIG)
	if not ok or not a or not b then
		return false, reason or "You do not own those Nomlings."
	end

	local child = FusionRules.combine(a :: any, b :: any, CONFIG, {
		upgrade = rng:NextNumber(),
		mutation = rng:NextNumber(),
		mutationPick = rng:NextNumber(),
	})

	local snackSpecies = speciesFor(a.snack, a.animal)
	local animalSpecies = speciesFor(b.snack, b.animal)
	if not snackSpecies or not animalSpecies then
		return false, "One of those Nomlings is from an older version."
	end

	local seed = NameGen.seedFor(snackSpecies.id, animalSpecies.id, child.gen, child.mutation)
	local name = NameGen.build(
		snackSpecies,
		animalSpecies,
		child.gen,
		Nomlings.GEN3_AFFIXES,
		Nomlings.PUREBRED_AFFIX,
		seed
	)
	local affix = if child.gen >= 3 then NameGen.affixForSeed(seed, Nomlings.GEN3_AFFIXES) else nil
	local comboKey = NameGen.comboKey(snackSpecies.id, animalSpecies.id, child.gen, affix)

	-- The parents are consumed NOW, not on claim. Otherwise a player could
	-- start a fusion, sell or lose a parent, and claim a child built from a
	-- creature they no longer own.
	for _, id in { idA, idB } do
		local pedestal = Profile.pedestalOf(data, id)
		if pedestal then
			Profile.unplace(data, pedestal)
		end
		for i, candidate in data.nomlings do
			if candidate.id == id then
				table.remove(data.nomlings, i)
				break
			end
		end
	end
	PlotService.render(player)

	-- FUSION_SECONDS is keyed by RARITY, not by gen. Indexing it by gen quietly
	-- returned nil and fell through to the 8-second FTUE time for every fusion
	-- in the game, which would have collapsed the whole timing curve.
	local seconds = if data.stats.hatched <= 2
		then Economy.FUSION_FIRST_TIME_SECONDS
		else (Economy.FUSION_SECONDS[child.rarity] or Economy.FUSION_FIRST_TIME_SECONDS)

	pending[player] = {
		player = player,
		child = child,
		name = name,
		comboKey = comboKey,
		readyAt = os.time() + seconds,
		seed = seed,
	}

	data.stats.fusionsStarted += 1
	AnalyticsService.report(player, "fusion_started", seconds, {
		a_rarity = a.rarity,
		b_rarity = b.rarity,
		same_tier = a.rarity == b.rarity,
	})
	AnalyticsService.advanceFunnel(player, data)

	return true, nil
end

function FusionService.claim(player: Player): (boolean, string?)
	if not NetService.allow(player, "ClaimFusion") then
		return false, "One at a time!"
	end

	local entry = pending[player]
	if not entry then
		return false, "Nothing is fusing."
	end
	if os.time() < entry.readyAt then
		return false, "Still cooking!"
	end

	local data = DataService.get(player)
	if not data then
		return false, "Still loading -- try again in a second."
	end

	local free = PlotService.firstFreePedestal(data)
	if not free and #data.nomlings >= Economy.INVENTORY_CAP then
		return false, "Your Nomling book is full."
	end

	pending[player] = nil

	local stored = Profile.addNomling(data, {
		id = "",
		snack = entry.child.snack,
		animal = entry.child.animal,
		gen = entry.child.gen,
		mutation = entry.child.mutation,
		rarity = entry.child.rarity,
		seed = entry.seed,
	}, Economy.INVENTORY_CAP)
	if not stored then
		return false, "Your Nomling book is full."
	end
	if free then
		Profile.place(data, stored.id, free, Economy.PEDESTALS_BASE)
	end
	-- Recorded before the reveal fires, so the reveal can say whether this is
	-- a page the player has never filled in.
	local isNewToBook = BookService.record(data, stored)
	PlotService.render(player)

	-- The World First claim happens after the creature is safely theirs, so a
	-- DataStore problem can cost the accolade but never the Nomling.
	local isFirst = claimWorldFirst(entry.comboKey, player.UserId)

	data.stats.fusionsRevealed += 1
	AnalyticsService.report(player, "fusion_completed", 1, {
		result_rarity = stored.rarity,
		result_gen = stored.gen,
		new_to_book = isNewToBook,
	})
	if isFirst then
		-- The combo key, never the generated name: a name is player-adjacent
		-- content and telemetry carries none of that (docs/ANALYTICS.md 1).
		AnalyticsService.report(player, "world_first_claimed", 1, { combo_key = entry.comboKey })
	end
	AnalyticsService.advanceFunnel(player, data)

	local reveal = Net.get("FusionReveal") :: RemoteEvent
	reveal:FireClient(player, {
		name = entry.name,
		snack = entry.child.snack,
		animal = entry.child.animal,
		gen = entry.child.gen,
		mutation = entry.child.mutation,
		rarity = entry.child.rarity,
		upgraded = entry.child.upgraded,
		worldFirst = isFirst,
		-- A World First means nobody ANYWHERE has made it. This means the
		-- player personally has not -- a much commoner and still satisfying
		-- thing, and the reveal says so when it is not a world first.
		newToBook = isNewToBook,
		bookCount = Profile.bookCount(data),
		bookTotal = BookService.totals().all,
		nomlingId = stored.id,
	})

	FeedbackService.fire(player, "hatch", nil, {
		rarity = entry.child.rarity,
		mutation = entry.child.mutation,
	})

	if isFirst then
		local payload = {
			name = entry.name,
			userId = player.UserId,
			displayName = player.DisplayName,
			rarity = entry.child.rarity,
			gen = entry.child.gen,
		}
		local remote = Net.get("WorldFirst") :: RemoteEvent
		remote:FireAllClients(payload)
		pcall(function()
			MessagingService:PublishAsync(WORLD_FIRST_TOPIC, payload)
		end)
	end

	return true, nil
end

--- What the client needs to draw the lab's state.
function FusionService.statusFor(player: Player): { [string]: any }?
	local entry = pending[player]
	if not entry then
		return nil
	end
	return { readyAt = entry.readyAt, now = os.time() }
end

return FusionService
