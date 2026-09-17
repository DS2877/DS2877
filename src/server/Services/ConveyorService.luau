--!strict
--[[
	The delivery belt: Nomlings ride down the middle of the street, each with a
	visible rarity, a possible mutation and a price, and you buy the ones you
	want as they pass.

	Added after the first playtest -- "the game doesn't have a highway in the
	middle with the animals and mutations in the middle." It is the genre's
	acquisition loop and it does something eggs cannot: it makes the good stuff
	VISIBLE, to everyone, before anyone owns it. That is what makes a base worth
	looking at, and therefore worth stealing from.

	COMPLIANCE NOTE, and it is a good one: a belt Nomling is NOT a paid random
	item. You see exactly what you are buying, at a stated price, before you
	pay. No odds disclosure applies, and none of the paid-random-item rules in
	docs/COMPLIANCE.md are engaged. The eggs remain the random half of the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local NameGen = require(Shared:WaitForChild("Logic"):WaitForChild("NameGen"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Odds = require(Shared:WaitForChild("Logic"):WaitForChild("Odds"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))
local Genome = require(Shared:WaitForChild("Logic"):WaitForChild("Genome"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local ConveyorService = {}
ConveyorService.Name = "ConveyorService"

local rng = Random.new()

type Item = {
	id: string,
	nomling: Profile.Nomling,
	price: number,
	model: BasePart,
	--- Studs travelled along Z. The belt runs from -half to +half.
	z: number,
	--- Set the instant someone buys it, so two players tapping the same
	--- Nomling at the same moment cannot both get it.
	claimed: boolean,
}

local items: { Item } = {}
local nextId = 1
local beltFolder: Folder? = nil

local MUTATION_NAMES: { string } = {}
for name in Economy.MUTATIONS do
	table.insert(MUTATION_NAMES, name)
end
table.sort(MUTATION_NAMES) -- stable order, so a seed means the same thing twice

local function incomeOf(nomling: Profile.Nomling): number
	return Income.forOne(nomling :: any, Economy.BASE_INCOME, Economy.MUTATIONS)
end

local function priceOf(nomling: Profile.Nomling): number
	return math.max(1, math.floor(incomeOf(nomling) * World.BELT_PAYBACK_SECONDS))
end

--- A belt Nomling is an anchor with its genome on it, same as one on a
--- pedestal. The client builds the creature; the server owns the price tag and
--- the prompt.
local function buildAnchor(item: Item): BasePart
	local nomling = item.nomling
	local rarity = Style.RARITY[nomling.rarity] or Style.RARITY.common

	local anchor = Instance.new("Part")
	anchor.Name = "NomlingAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 4.5, 4)

	for key, value in Genome.attributes(nomling :: any, Nomlings.BY_ID :: any, nil) do
		anchor:SetAttribute(key, value)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromScale(10, 3.8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 160
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomCream
	label.TextStrokeTransparency = 0.2
	-- The mutation is the loudest line on the sign, because it is the reason to
	-- buy this one rather than wait for the next.
	local mutationLine = if nomling.mutation
		then `\n✨ {string.upper(nomling.mutation)} ✨`
		else ""
	label.Text = `{nomling.snack} {nomling.animal}{mutationLine}\n{rarity.label} · {Income.format(
		incomeOf(nomling)
	)}/s`
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Buy"
	prompt.ActionText = `Buy · {Income.format(item.price)}`
	prompt.ObjectText = "Nomling"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		ConveyorService.buy(player, item.id)
	end)

	return anchor
end

local function spawnItem()
	if #items >= World.BELT_MAX_ITEMS then
		return
	end
	local folder = beltFolder
	if not folder then
		return
	end

	local species = Nomlings.SPECIES[rng:NextInteger(1, #Nomlings.SPECIES)]
	-- Rarity uses the Basic egg's disclosed table rather than a new one, so the
	-- belt cannot drift away from numbers the economy simulator knows about.
	local rarity = Odds.pick(Economy.EGGS.basic.odds, rng:NextInteger(0, 999_999))

	local mutation: string? = nil
	if rng:NextNumber() < World.BELT_MUTATION_CHANCE and #MUTATION_NAMES > 0 then
		mutation = MUTATION_NAMES[rng:NextInteger(1, #MUTATION_NAMES)]
	end

	local nomling: Profile.Nomling = {
		id = "",
		snack = species.snack,
		animal = species.animal,
		gen = 1,
		affix = nil,
		mutation = mutation,
		rarity = rarity,
		seed = NameGen.seedFor(species.id, species.id, 1, mutation),
	}

	local item: Item = {
		id = tostring(nextId),
		nomling = nomling,
		price = priceOf(nomling),
		model = nil :: any,
		z = -World.STREET_LENGTH / 2,
		claimed = false,
	}
	nextId += 1
	item.model = buildAnchor(item)
	item.model.CFrame = CFrame.new(0, World.BELT_HEIGHT + 0.6, item.z)
	item.model.Parent = folder
	table.insert(items, item)
end

local function findItem(id: string): Item?
	for _, item in items do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function removeItem(item: Item)
	for i, candidate in items do
		if candidate == item then
			table.remove(items, i)
			break
		end
	end
	item.model:Destroy()
end

function ConveyorService.buy(player: Player, id: unknown): (boolean, string?)
	if not NetService.allow(player, "BuyFromBelt") then
		return false, "One at a time!"
	end
	if type(id) ~= "string" then
		return false, "That one is gone."
	end

	local item = findItem(id)
	-- `claimed` is checked and set with no yield between, so two players
	-- tapping the same Nomling in the same frame cannot both be sold it.
	if not item or item.claimed then
		return false, "Someone got there first!"
	end

	local data = DataService.get(player)
	if not data then
		return false, "Still loading your base -- try again in a second."
	end

	local free = PlotService.firstFreePedestal(data)
	if not free then
		-- Names the way out. A refusal that does not is a dead end.
		return false, "Base full — tap one of yours and Put away to free a spot."
	end
	if #data.nomlings >= Economy.INVENTORY_CAP then
		return false, "Your Nomling book is full."
	end
	if not Profile.spendCoins(data, item.price) then
		return false, `You need {Income.format(item.price)} coins.`
	end

	item.claimed = true

	local stored = Profile.addNomling(data, item.nomling, Economy.INVENTORY_CAP)
	if not stored then
		-- Refund rather than swallow the coins. Should be unreachable given the
		-- cap check above, but a silent charge is the worst possible outcome.
		Profile.addCoins(data, item.price)
		item.claimed = false
		return false, "Your Nomling book is full."
	end

	Profile.place(data, stored.id, free, Economy.PEDESTALS_BASE)

	-- Answer the tap before anything else, at the belt where their eyes are.
	FeedbackService.fire(player, "purchase", item.model.Position, {
		rarity = item.nomling.rarity,
		mutation = item.nomling.mutation,
	})

	removeItem(item)
	PlotService.render(player)
	return true, nil
end

function ConveyorService.init()
	local remote = Net.get("BuyFromBelt") :: RemoteFunction
	remote.OnServerInvoke = function(player, id)
		return ConveyorService.buy(player, id)
	end
end

function ConveyorService.start()
	local street = Workspace:WaitForChild("Street", 20)
	if not street then
		warn("[ConveyorService] no Street; is WorldService before ConveyorService?")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "BeltItems"
	folder.Parent = street
	beltFolder = folder

	task.spawn(function()
		while true do
			task.wait(World.BELT_SPAWN_SECONDS)
			spawnItem()
		end
	end)

	-- Movement is time-based, not frame-based, so the belt runs at the same
	-- speed on a busy server as an empty one.
	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local delta = now - last
			last = now

			local finish = World.STREET_LENGTH / 2
			for index = #items, 1, -1 do
				local item = items[index]
				item.z += World.BELT_SPEED * delta
				if item.z >= finish then
					removeItem(item)
				else
					item.model.CFrame = CFrame.new(0, World.BELT_HEIGHT + 0.6, item.z)
				end
			end
		end
	end)

	-- Start with a few already riding, so a joining player never sees an empty
	-- belt and conclude nothing happens here.
	for _ = 1, 4 do
		spawnItem()
		for _, item in items do
			item.z += 40
		end
	end
	print(`[ConveyorService] belt running at {World.BELT_SPEED} studs/s`)
end

return ConveyorService
