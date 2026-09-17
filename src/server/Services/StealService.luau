--!strict
--[[
	Snatching: lift a Nomling out of someone's base, run it home, keep it.

	The fair-play rules live in shared/Logic/SnatchRules (pure, unit-tested).
	This file does the world half: prompts, carrying, the walk home, the
	timeout, and telling the victim.

	THE SERVER OWNS THE WHOLE THING. The client never says which Nomling it
	took, where it is, or that it arrived -- it presses a prompt, and every
	consequence is decided here from server-side positions. A carried creature
	is the single most valuable thing a cheating client could lie about.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Net = require(Shared:WaitForChild("Net"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))
local Snatch = require(Shared:WaitForChild("Config"):WaitForChild("Snatch"))
local SnatchRules = require(Shared:WaitForChild("Logic"):WaitForChild("SnatchRules"))
local Genome = require(Shared:WaitForChild("Logic"):WaitForChild("Genome"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Style = require(Shared:WaitForChild("Style"))

local BookService = require(script.Parent:WaitForChild("BookService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local StealService = {}
StealService.Name = "StealService"

type Carry = {
	thief: Player,
	victim: Player,
	nomling: Profile.Nomling,
	model: Model,
	startedAt: number,
}

local carrying: { [Player]: Carry } = {}
--- thief -> victim userId -> os.clock() of the last attempt.
local attempts: { [Player]: { [number]: number } } = {}

local function notify(player: Player, text: string)
	local remote = Net.get("Notify") :: RemoteEvent
	remote:FireClient(player, text)
end

local IncomeService = require(script.Parent:WaitForChild("IncomeService"))

local function incomeOf(player: Player): number
	local data = DataService.get(player)
	return if data then IncomeService.perSecond(data) else 0
end

--- The carried creature, welded above the thief's head. It is a genome ANCHOR
--- like every other Nomling in the world, so the client builds the real
--- creature rather than a stand-in -- which matters because the whole point of
--- a chase is that everyone can see what is being carried off.
local function carriedModel(nomling: Profile.Nomling, thief: Player): Model?
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Carried"

	local anchor = Instance.new("Part")
	anchor.Name = "NomlingAnchor"
	anchor.CanCollide = false
	anchor.Massless = true
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2.5, 2.5, 2.5)
	anchor.CFrame = head.CFrame * CFrame.new(0, 3.2, 0)
	for key, value in Genome.attributes(nomling :: any, Nomlings.BY_ID :: any, nil) do
		anchor:SetAttribute(key, value)
	end
	anchor.Parent = model
	model.PrimaryPart = anchor

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = anchor
	weld.Parent = anchor

	-- A trail, so a thief is visible across the street. Being chased is the
	-- fun part and it cannot happen if nobody can tell who to chase.
	local glow = Instance.new("PointLight")
	glow.Brightness = 2
	glow.Range = 16
	glow.Color = (Style.RARITY[nomling.rarity] or Style.RARITY.common).color
	glow.Parent = anchor

	model.Parent = workspace
	return model
end

local function setSpeed(player: Player, factor: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16 * factor
	end
end

--- Puts a carried Nomling back where it came from.
local function returnHome(carry: Carry, reason: string?)
	carrying[carry.thief] = nil
	carry.model:Destroy()
	setSpeed(carry.thief, 1)

	local victimData = DataService.get(carry.victim)
	if victimData then
		local free = PlotService.firstFreePedestal(victimData)
		if free then
			Profile.place(victimData, carry.nomling.id, free, Economy.PEDESTALS_BASE)
		end
		PlotService.render(carry.victim)
	end
	if reason then
		notify(carry.thief, reason)
	end
end

--- The thief made it into their own base with it.
local function deposit(carry: Carry)
	local thiefData = DataService.get(carry.thief)
	if not thiefData then
		returnHome(carry, "Something went wrong -- it went home.")
		return
	end

	local free = PlotService.firstFreePedestal(thiefData)
	if not free then
		returnHome(carry, "No room in your base -- it went home.")
		return
	end

	carrying[carry.thief] = nil
	carry.model:Destroy()
	setSpeed(carry.thief, 1)

	local stored = Profile.addNomling(thiefData, carry.nomling, Economy.INVENTORY_CAP)
	if not stored then
		returnHome(carry, "Your Nomling book is full -- it went home.")
		return
	end
	Profile.place(thiefData, stored.id, free, Economy.PEDESTALS_BASE)
	BookService.record(thiefData, stored)

	PlotService.render(carry.thief)
	notify(carry.thief, `Got it! {carry.nomling.snack} {carry.nomling.animal} is yours.`)

	-- The loss softener (GDD 5.8). Being robbed must hand you something, not
	-- only take something -- this is the difference between "that was exciting"
	-- and "I lost my afternoon".
	local victimData = DataService.get(carry.victim)
	if victimData and #victimData.incubators < Economy.INCUBATORS_BASE then
		table.insert(victimData.incubators, {
			eggKey = Snatch.COMEBACK_EGG,
			readyAt = os.time() + Snatch.COMEBACK_HATCH_SECONDS,
		})
		notify(carry.victim, "You were snatched! A Comeback Egg is hatching for you.")
	else
		notify(carry.victim, "You were snatched!")
	end
end

function StealService.attempt(thief: Player, victim: Player, nomlingId: string): (boolean, string?)
	local thiefData = DataService.get(thief)
	local victimData = DataService.get(victim)
	if not thiefData or not victimData then
		return false, "Still loading -- try again in a second."
	end

	local nomling = Profile.findNomling(victimData, nomlingId)
	if not nomling then
		return false, "Too late -- it is gone."
	end

	local bucket = attempts[thief] or {}
	attempts[thief] = bucket

	local ok, reason = SnatchRules.check({
		thiefUserId = thief.UserId,
		targetUserId = victim.UserId,
		targetPlaytime = victimData.stats.playtime,
		thiefIncomePerSecond = incomeOf(thief),
		targetIncomePerSecond = incomeOf(victim),
		lastAttemptAt = bucket[victim.UserId],
		now = os.clock(),
		gateUp = false, -- the Laser Gate is M2b
		protected = false, -- the Vault is M2b
		thiefHasFreePedestal = PlotService.firstFreePedestal(thiefData) ~= nil,
		thiefCarrying = carrying[thief] ~= nil,
	}, Snatch)

	if not ok then
		return false, reason
	end
	bucket[victim.UserId] = os.clock()

	-- Take it off the victim's pedestal and out of their inventory NOW. While
	-- it is being carried it belongs to nobody, so it cannot earn for the
	-- victim or be snatched a second time.
	local pedestal = Profile.pedestalOf(victimData, nomlingId)
	if pedestal then
		Profile.unplace(victimData, pedestal)
	end
	for i, candidate in victimData.nomlings do
		if candidate.id == nomlingId then
			table.remove(victimData.nomlings, i)
			break
		end
	end
	PlotService.render(victim)

	local model = carriedModel(nomling, thief)
	if not model then
		return false, "Could not pick it up -- try again."
	end

	carrying[thief] = {
		thief = thief,
		victim = victim,
		nomling = nomling,
		model = model,
		startedAt = os.clock(),
	}
	setSpeed(thief, Snatch.CARRY_SPEED_FACTOR)

	notify(thief, "RUN! Get it back to your base!")
	notify(victim, `{thief.DisplayName} is taking your {nomling.snack} {nomling.animal}!`)

	local grabAt = model.PrimaryPart and model.PrimaryPart.Position
	FeedbackService.fire(thief, "grab", grabAt, { rarity = nomling.rarity })
	-- The victim gets the loudest cue in the game. Being robbed is the one
	-- event a player must notice instantly, even looking at something else.
	FeedbackService.fire(victim, "snatched", nil, { rarity = nomling.rarity })
	return true, nil
end

--- Bubbles the nearest PLAYER carrier to a position. Returns ok, reason.
--- Mirrors SnatchNpcService.bubbleNear so BubbleService can try both without
--- caring which kind of thief it found.
function StealService.bubbleNear(position: Vector3, firedBy: Player): (boolean, string?)
	local best: Carry? = nil
	local bestDistance = Snatch.BUBBLE_RANGE
	for thief, carry in carrying do
		-- You cannot bubble yourself out of a carry you started; putting it down
		-- is what walking home is for.
		if thief == firedBy then
			continue
		end
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		local distance = (root.Position - position).Magnitude
		if distance <= bestDistance then
			best = carry
			bestDistance = distance
		end
	end
	if not best then
		return false, nil
	end
	local carry = best :: Carry
	returnHome(carry, "Bubbled! You dropped it. 🫧")
	notify(carry.victim, "Someone bubbled the thief — your Nomling is home! 🫧")
	FeedbackService.fire(carry.victim, "purchase", position, { rarity = carry.nomling.rarity })
	return true, nil
end

function StealService.start()
	-- Offer a snatch prompt on every rendered Nomling. The prompt is created
	-- for everyone and filtered per player by the server when triggered, so a
	-- client cannot make one appear where it should not.
	PlotService.onNomlingRendered(function(anchor, owner, nomlingId)
		-- The anchor IS the interaction target: it is the only queryable part,
		-- because the visual parts are built client-side and set CanQuery false.
		if not anchor:IsA("BasePart") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Snatch"
		prompt.ActionText = "Snatch!"
		prompt.ObjectText = `{owner.DisplayName}'s Nomling`
		prompt.HoldDuration = Snatch.HOLD_SECONDS
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor

		prompt.Triggered:Connect(function(thief)
			local ok, reason = StealService.attempt(thief, owner, nomlingId)
			if not ok and reason then
				notify(thief, reason)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carry = carrying[player]
		if carry then
			returnHome(carry, nil)
		end
		for _, bucket in attempts do
			bucket[player.UserId] = nil
		end
		attempts[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			for thief, carry in carrying do
				-- Timed out, or the carrier disconnected mid-run.
				if os.clock() - carry.startedAt > Snatch.CARRY_TIMEOUT_SECONDS then
					returnHome(carry, "It wriggled free and went home!")
					continue
				end
				local character = thief.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") then
					continue
				end
				local plot = PlotService.plotAt(root.Position.X, root.Position.Z)
				if plot and plot.owner == thief then
					deposit(carry)
				end
			end
		end
	end)

	-- Playtime drives the newcomer shield, so it has to be counted somewhere.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.stats.playtime += 10
				end
			end
		end
	end)
end

return StealService
