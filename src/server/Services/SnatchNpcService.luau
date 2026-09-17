--!strict
--[[
	Sneaky Sam and friends: NPC snatchers that rob players' bases.

	THIS EXISTS FOR A PRACTICAL REASON, not a design one (GDD 5.8). Philip is
	phone-only with no Studio, so two clients cannot be run side by side and
	snatching is otherwise impossible to test or to feel. These NPCs drive the
	same server code paths a real thief would: they take a creature out of a
	profile, carry it, and either escape with it or drop it when bubbled.

	They are also good design on their own. A player alone in a server still
	learns that their base can be robbed -- and learns it as something they can
	SURVIVE, which is the whole intent of the snatching design. Being bubbled by
	an NPC teaches the counter-play before a person ever takes anything.

	FAIRNESS IS BUILT IN AND DELIBERATELY GENEROUS:
	- Never robs a base with fewer than two Nomlings. Taking somebody's only
	  creature is a reset, not mischief.
	- Never robs a player inside the newcomer shield.
	- Moves slower than a player, so bubbling one is always possible for anyone
	  who reacts.
	- The victim gets a Comeback Egg either way.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Genome = require(Shared:WaitForChild("Logic"):WaitForChild("Genome"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))
local Snatch = require(Shared:WaitForChild("Config"):WaitForChild("Snatch"))
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local GateService = require(script.Parent:WaitForChild("GateService"))

local SnatchNpcService = {}
SnatchNpcService.Name = "SnatchNpcService"

local rng = Random.new()

export type Thief = {
	name: string,
	model: Model,
	root: BasePart,
	victim: Player,
	nomling: Profile.Nomling,
	--- Where it is heading right now.
	goal: Vector3,
	--- "flee" is the only state the player can interrupt.
	state: "approach" | "flee",
	deadline: number,
	bubbled: boolean,
}

local active: { Thief } = {}
local folder: Folder? = nil

local function notify(player: Player, text: string)
	local Net = require(Shared:WaitForChild("Net"))
	local remote = Net.get("Notify") :: RemoteEvent
	remote:FireClient(player, text)
end

--- A friendly masked bandit, not a villain. The design word is "friendly
--- snatchers" (GDD 5.8) and the whole intent is that being robbed feels
--- exciting rather than threatening -- which starts with the thief being
--- something a child finds funny rather than something they find menacing.
local function buildThief(name: string, at: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `Thief_{name}`

	local root = Instance.new("Part")
	root.Name = "Body"
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(2.8, 3.6, 2.4)
	root.CFrame = CFrame.new(at)
	root.Color = Color3.fromRGB(148, 156, 178)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model
	model.PrimaryPart = root

	local function attach(part: Part)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.CFrame = root.CFrame * CFrame.new(0, 2.8, 0)
	head.Color = Color3.fromRGB(206, 212, 226)
	head.Material = Enum.Material.SmoothPlastic
	attach(head)

	-- The mask. One band across the eyes is the entire "bandit" read, and it is
	-- funny rather than frightening.
	local mask = Instance.new("Part")
	mask.Name = "Mask"
	mask.Size = Vector3.new(2.3, 0.75, 1.5)
	mask.CFrame = head.CFrame * CFrame.new(0, 0.15, 0.5)
	mask.Color = Color3.fromRGB(62, 58, 74)
	mask.Material = Enum.Material.SmoothPlastic
	attach(mask)

	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.6, 0.6, 0.6)
		eye.CFrame = head.CFrame * CFrame.new(side * 0.55, 0.2, 1.05)
		eye.Color = Color3.fromRGB(252, 252, 255)
		eye.Material = Enum.Material.SmoothPlastic
		attach(eye)

		local ear = Instance.new("Part")
		ear.Name = "Ear"
		ear.Shape = Enum.PartType.Ball
		ear.Size = Vector3.new(0.9, 1, 0.5)
		ear.CFrame = head.CFrame * CFrame.new(side * 0.85, 1.05, -0.1)
		ear.Color = Color3.fromRGB(148, 156, 178)
		ear.Material = Enum.Material.SmoothPlastic
		attach(ear)
	end

	-- A striped swag sack. It says "up to no good" without saying "danger".
	local sack = Instance.new("Part")
	sack.Name = "Sack"
	sack.Shape = Enum.PartType.Ball
	sack.Size = Vector3.new(1.8, 1.9, 1.6)
	sack.CFrame = root.CFrame * CFrame.new(-1.6, 0.6, -0.4)
	sack.Color = Color3.fromRGB(246, 238, 220)
	sack.Material = Enum.Material.Fabric
	attach(sack)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromScale(9, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	gui.MaxDistance = 220
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomPink
	label.TextStrokeTransparency = 0.3
	label.Text = `🦝 {name}`
	label.Parent = gui

	model.Parent = folder
	return model, root
end

--- Picks a base worth robbing, and a creature in it. Returns nil when nobody
--- qualifies, which is the common case with one player on a fresh profile.
local function pickTarget(): (Player?, Profile.Nomling?, number?)
	local candidates: { { player: Player, nomling: Profile.Nomling, pedestal: number } } = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local plot = PlotService.plotFor(player)
		if not data or not plot then
			continue
		end
		if data.stats.playtime < Snatch.NEWCOMER_SHIELD_SECONDS then
			continue
		end
		if #data.nomlings < Snatch.NPC_MIN_TARGET_NOMLINGS then
			continue
		end
		-- THE GATE STOPS THE NPCs TOO. Sneaky Sam exists to exercise the same
		-- rules a real thief hits (Philip is phone-only and cannot run two
		-- clients), so a defence he ignores is a defence that is never actually
		-- tested -- and from inside the game it would read as the gate simply
		-- not working.
		if GateService.isUp(plot.index) then
			continue
		end
		for key, id in data.pedestals do
			local index = tonumber(key)
			-- Never the Vault.
			if index == Economy.VAULT_PEDESTAL then
				continue
			end
			local nomling = Profile.findNomling(data, id)
			if index and nomling then
				table.insert(candidates, { player = player, nomling = nomling, pedestal = index })
			end
		end
	end
	if #candidates == 0 then
		return nil, nil, nil
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	return pick.player, pick.nomling, pick.pedestal
end

local function carriedTag(thief: Thief)
	local anchor = Instance.new("Part")
	anchor.Name = "NomlingAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2.5, 2.5, 2.5)
	for key, value in Genome.attributes(thief.nomling :: any, Nomlings.BY_ID :: any, nil) do
		anchor:SetAttribute(key, value)
	end
	anchor.CFrame = thief.root.CFrame * CFrame.new(0, 5.4, 0)
	anchor.Parent = thief.model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = thief.root
	weld.Part1 = anchor
	weld.Parent = anchor
end

--- Gives the creature back and clears the thief.
local function dropAndLeave(thief: Thief, bubbled: boolean)
	for index, candidate in active do
		if candidate == thief then
			table.remove(active, index)
			break
		end
	end
	thief.model:Destroy()

	local data = DataService.get(thief.victim)
	if not data then
		return
	end

	if bubbled then
		-- It goes straight home. Bubbling has to feel like a clean save.
		local restored = Profile.addNomling(data, thief.nomling, Economy.INVENTORY_CAP)
		if restored then
			local free = PlotService.firstFreePedestal(data)
			if free then
				Profile.place(data, restored.id, free, Economy.PEDESTALS_BASE)
			end
		end
		PlotService.render(thief.victim)
		notify(
			thief.victim,
			`Bubbled! You saved your {thief.nomling.snack} {thief.nomling.animal}. 💙`
		)
		FeedbackService.fire(thief.victim, "purchase", thief.root.Position, {
			rarity = thief.nomling.rarity,
		})
	else
		-- It got away. The Comeback Egg is what keeps this exciting rather than
		-- punishing (GDD 5.8).
		if #data.incubators < Economy.INCUBATORS_BASE then
			table.insert(data.incubators, {
				eggKey = Snatch.COMEBACK_EGG,
				readyAt = os.time() + Snatch.COMEBACK_HATCH_SECONDS,
				total = Snatch.COMEBACK_HATCH_SECONDS,
			})
			notify(
				thief.victim,
				`{thief.name} got away with your {thief.nomling.snack} {thief.nomling.animal}! A Comeback Egg is hatching.`
			)
		else
			notify(
				thief.victim,
				`{thief.name} got away with your {thief.nomling.snack} {thief.nomling.animal}!`
			)
		end
	end
end

--- Bubbles the nearest fleeing thief to a position. Returns ok, reason.
function SnatchNpcService.bubbleNear(position: Vector3): (boolean, string?)
	local best: Thief? = nil
	local bestDistance = Snatch.BUBBLE_RANGE
	for _, thief in active do
		if thief.state ~= "flee" or thief.bubbled then
			continue
		end
		local distance = (thief.root.Position - position).Magnitude
		if distance <= bestDistance then
			best = thief
			bestDistance = distance
		end
	end
	if not best then
		return false, "Nothing to bubble — get closer!"
	end
	best.bubbled = true
	dropAndLeave(best, true)
	return true, nil
end

local function beginSnatch()
	local victim, nomling, pedestal = pickTarget()
	if not victim or not nomling or not pedestal then
		return
	end
	local data = DataService.get(victim)
	local plot = PlotService.plotFor(victim)
	if not data or not plot then
		return
	end

	-- Take it out of the profile now, so it cannot earn for the victim while it
	-- is being carried and cannot be fused out from under the thief.
	Profile.unplace(data, pedestal)
	for i, candidate in data.nomlings do
		if candidate.id == nomling.id then
			table.remove(data.nomlings, i)
			break
		end
	end
	PlotService.render(victim)

	local cx, cz, side = World.baseCenter(plot.index)
	local entry = Vector3.new(cx - side * (World.BASE_DEPTH / 2 + 6), 2.5, cz)
	local escape = Vector3.new(
		0,
		2.5,
		cz > 0 and World.STREET_LENGTH / 2 + 40 or -World.STREET_LENGTH / 2 - 40
	)

	local name = Snatch.NPC_NAMES[rng:NextInteger(1, #Snatch.NPC_NAMES)]
	local model, root = buildThief(name, entry)

	local thief: Thief = {
		name = name,
		model = model,
		root = root,
		victim = victim,
		nomling = nomling,
		goal = Vector3.new(cx, 2.5, cz),
		state = "approach",
		deadline = os.clock() + 8,
		bubbled = false,
	}
	table.insert(active, thief)

	notify(victim, `🦝 {name} is after your {nomling.snack} {nomling.animal}!`)
	FeedbackService.fire(victim, "snatched", nil, { rarity = nomling.rarity })

	-- Reaches the pedestal, grabs, then runs for the edge of the street. The
	-- flee leg is the only part the player can interrupt, and it is long.
	task.delay(2.5, function()
		if thief.bubbled or not thief.model.Parent then
			return
		end
		carriedTag(thief)
		thief.state = "flee"
		thief.goal = escape
		thief.deadline = os.clock() + Snatch.NPC_ESCAPE_SECONDS
		notify(victim, `Tap SAVE to bubble {name} before they reach the end of the street! 💙`)
	end)
end

function SnatchNpcService.start()
	if not Snatch.NPC_ENABLED then
		return
	end

	local created = Instance.new("Folder")
	created.Name = "Thieves"
	created.Parent = Workspace
	folder = created

	-- Movement. Straight-line, because the street is one flat open road and
	-- pathfinding would be machinery with nothing to solve.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local delta = now - last
			last = now

			for index = #active, 1, -1 do
				local thief = active[index]
				if not thief.model.Parent then
					table.remove(active, index)
					continue
				end
				local position = thief.root.Position
				local toGoal = thief.goal - position
				if toGoal.Magnitude > 1 then
					local step = toGoal.Unit * math.min(Snatch.NPC_SPEED * delta, toGoal.Magnitude)
					thief.root.CFrame = CFrame.new(position + step, thief.goal)
				end
				if os.clock() > thief.deadline then
					dropAndLeave(thief, false)
				end
			end
		end
	end)

	task.spawn(function()
		-- A quiet opening minute. Being robbed in the first thirty seconds of a
		-- session teaches the wrong lesson.
		task.wait(60)
		while true do
			task.wait(rng:NextNumber(Snatch.NPC_INTERVAL_MIN, Snatch.NPC_INTERVAL_MAX))
			if #active == 0 then
				local ok, err = pcall(beginSnatch :: () -> any)
				if not ok then
					warn(`[SnatchNpcService] snatch attempt failed: {err}`)
				end
			end
		end
	end)

	print("[SnatchNpcService] thieves active")
end

return SnatchNpcService
