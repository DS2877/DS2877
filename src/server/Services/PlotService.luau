--!strict
--[[
	Owns plots: who has which one, and what stands on it.

	A plot is one of the eight pads PlazaService built. A player gets one on
	join and keeps it until they leave. Pedestals are laid out on the pad and
	each holds at most one Nomling.

	Rendering here is DELIBERATELY A PLACEHOLDER -- a coloured block with a
	name over it. The real NomlingBuilder, which turns a genome into a model,
	is M2a work (docs/NOMLINGS.md 5). Everything below cares only about
	position and ownership, so replacing the visual later changes one function.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))
local Genome = require(Shared:WaitForChild("Logic"):WaitForChild("Genome"))
local Nameplate = require(Shared:WaitForChild("Nameplate"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local PlotService = {}
PlotService.Name = "PlotService"

local PEDESTAL_HEIGHT = World.PEDESTAL_HEIGHT
local PEDESTAL_SIZE = Vector3.new(4, PEDESTAL_HEIGHT, 4)
local PLOT_COUNT = World.BASE_COUNT

type Plot = {
	index: number,
	pad: BasePart,
	owner: Player?,
	pedestals: { BasePart },
	models: { [string]: Instance },
}

local plots: { Plot } = {}

--- Set by StealService. Called for every rendered Nomling so it can attach a
--- snatch prompt. A hook rather than a require, because StealService already
--- requires this module and the other direction would be a cycle.
local decorate: ((anchor: Instance, owner: Player, nomlingId: string) -> ())? = nil

function PlotService.onNomlingRendered(fn: (Instance, Player, string) -> ())
	decorate = fn
end

local function pedestalPositions(pad: BasePart): { CFrame }
	-- A ring inside the pad, facing outward from the pad's centre. Laid out in
	-- the pad's own space so it follows the pad's rotation around the plaza.
	local result: { CFrame } = {}
	local count = Economy.PEDESTALS_BASE
	local radius = math.min(pad.Size.X, pad.Size.Z) * 0.32
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local offset =
			Vector3.new(math.cos(angle) * radius, PEDESTAL_HEIGHT / 2, math.sin(angle) * radius)
		table.insert(result, pad.CFrame * CFrame.new(offset))
	end
	return result
end

local function buildPedestals(plot: Plot)
	local folder = Instance.new("Folder")
	folder.Name = `Pedestals_{plot.index}`

	for i, cframe in pedestalPositions(plot.index) do
		local post = Instance.new("Part")
		post.Name = `Pedestal{i}`
		post.Anchored = true
		post.CanCollide = true
		post.Size = PEDESTAL_SIZE
		post.CFrame = cframe
		post.Color = Style.PALETTE.plotEdge
		post.Material = Enum.Material.SmoothPlastic
		post.TopSurface = Enum.SurfaceType.Smooth
		post:SetAttribute("PedestalIndex", i)
		post.Parent = folder
		table.insert(plot.pedestals, post)
	end

	folder.Parent = plot.pad
end

--- Replicates a Nomling as an invisible ANCHOR carrying its genome. The client
--- builds the twenty-odd parts locally (docs/GDD.md 5.4) -- a genome is a
--- handful of strings, a model is twenty parts, and with 150 creatures visible
--- that difference is whether a phone can run this.
---
--- The anchor is also the only queryable part, so it owns interaction: the
--- visual parts the client makes cannot intercept a tap.
local function buildAnchor(nomling: Profile.Nomling, owner: Player): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "NomlingAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(3.5, 4, 3.5)

	for key, value in Genome.attributes(nomling :: any, Nomlings.BY_ID :: any, owner.UserId) do
		anchor:SetAttribute(key, value)
	end

	local rarity = Style.RARITY[nomling.rarity] or Style.RARITY.common

	-- Rarity is never colour alone -- the word is always on the detail line
	-- (GDD 5.16). A base holds eight of these and a street holds eight bases,
	-- so past MaxDistance the signs stop being information and become texture.
	local headline = if nomling.mutation
		then `✨ {string.upper(nomling.mutation)}`
		else `{nomling.snack} {nomling.animal}`
	Nameplate.build(anchor, {
		headline = headline,
		headlineColor = if nomling.mutation
			then Color3.fromRGB(255, 240, 170)
			else Style.PALETTE.nomCream,
		detail = rarity.label,
		detailColor = rarity.color,
		height = 3.4,
		maxDistance = 70,
	})

	-- TWO prompts, and the client enables whichever applies (see
	-- NomlingRenderController). A ProximityPrompt is replicated identically to
	-- everyone, so this is the only way to offer "Store" to the owner and
	-- "Snatch" to everybody else without two copies of the creature.
	local store = Instance.new("ProximityPrompt")
	store.Name = "Store"
	store.ActionText = "Put away"
	store.ObjectText = `{nomling.snack} {nomling.animal}`
	store.HoldDuration = 0
	store.MaxActivationDistance = 12
	store.RequiresLineOfSight = false
	-- Starts off. The owner's client turns it on; for everyone else it stays
	-- off and they see the Snatch prompt instead.
	store.Enabled = false
	store.Parent = anchor

	return anchor
end

--- Takes a placed Nomling back into the book. Returns ok, reason.
function PlotService.store(player: Player, nomlingId: unknown): (boolean, string?)
	if type(nomlingId) ~= "string" then
		return false, "That Nomling is not there."
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading -- try again in a second."
	end
	local pedestal = Profile.pedestalOf(data, nomlingId)
	if not pedestal then
		return false, "That one is already put away."
	end
	Profile.unplace(data, pedestal)
	PlotService.render(player)
	return true, nil
end

function PlotService.plotAt(x: number, z: number): Plot?
	for _, plot in plots do
		if World.isInsideBase(plot.index, x, z) then
			return plot
		end
	end
	return nil
end

--- Where this player's base is, in world space, or nil before one is assigned.
---
--- Sent to the client in the profile sync rather than looked up there, because
--- the client frequently does NOT have the pad instance. StreamingEnabled with
--- a 512-stud radius on a 520-stud street means a base at the far end is
--- simply not replicated -- so a client-side lookup fails exactly when the
--- player is far from home and most needs pointing at it.
function PlotService.baseCenter(player: Player): (number?, number?, number?)
	local plot = PlotService.plotFor(player)
	if not plot then
		return nil, nil, nil
	end
	local x, z = World.baseCenter(plot.index)
	return x, z, plot.index
end

function PlotService.plotFor(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == player then
			return plot
		end
	end
	return nil
end

--- Draws the profile's pedestals. Cheap enough to redraw wholesale after any
--- change, which is much harder to get wrong than incremental updates.
function PlotService.render(player: Player)
	local plot = PlotService.plotFor(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end

	for id, model in plot.models do
		model:Destroy()
		plot.models[id] = nil
	end

	for key, nomlingId in data.pedestals do
		local index = tonumber(key)
		local pedestal = index and plot.pedestals[index]
		local nomling = Profile.findNomling(data, nomlingId)
		if not pedestal or not nomling then
			continue
		end
		local anchor = buildAnchor(nomling, player)
		anchor.CFrame = pedestal.CFrame * CFrame.new(0, PEDESTAL_HEIGHT / 2 + 0.1, 0)
		anchor.Parent = plot.pad
		plot.models[nomlingId] = anchor :: any
		if decorate then
			local ok, err = pcall(decorate, anchor :: any, player, nomlingId)
			if not ok then
				warn(`[PlotService] decorate failed for {nomlingId}: {err}`)
			end
		end
	end
end

--- The lowest free pedestal, or nil when the base is full. Used to place a
--- newly hatched Nomling without asking -- one fewer tap in the first sixty
--- seconds, which is the part of the game we can least afford to complicate.
function PlotService.firstFreePedestal(data: Profile.Data): number?
	for i = 1, Economy.PEDESTALS_BASE do
		if not data.pedestals[tostring(i)] then
			return i
		end
	end
	return nil
end

--- The sign over the back wall. It is how you tell whose base you are standing
--- in, which matters a great deal once people are stealing from each other.
local function setSign(plot: Plot, text: string)
	local base = plot.pad.Parent
	local post = base and base:FindFirstChild("Sign")
	local gui = post and post:FindFirstChild("OwnerSign")
	local label = gui and gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

--- Updates an owned base's sign. Called by IncomeService, which is the only
--- thing that knows the live rate -- PlotService cannot ask it, because
--- IncomeService already requires this module and the other direction would be
--- a cycle.
function PlotService.setSignFor(player: Player, text: string)
	local plot = PlotService.plotFor(player)
	if plot then
		setSign(plot, text)
	end
end

local function moveToBase(player: Player, plot: Plot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local x, z, side = World.spawnCFrame(plot.index)
	-- Face the road, so the first thing a new player sees is the belt.
	root.CFrame = CFrame.new(Vector3.new(x, 4, z), Vector3.new(x - side * 40, 4, z))
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.pad:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, `{player.DisplayName}'s Base`)
			PlotService.render(player)
			moveToBase(player, plot)
			-- A respawn puts them back on the road spawn, so send them home again.
			player.CharacterAdded:Connect(function()
				task.wait(0.4)
				if plot.owner == player then
					moveToBase(player, plot)
				end
			end)
			return
		end
	end
	-- Tell the PLAYER, not just the log. A full server is a legitimate state,
	-- but from inside the game it is indistinguishable from the bug above:
	-- you are standing on a street with no home and nothing explains it.
	warn(`[PlotService] no free base for {player.Name}; all {PLOT_COUNT} are taken`)
	local notify = Net.get("Notify") :: RemoteEvent
	notify:FireClient(player, `All {PLOT_COUNT} bases are taken right now — try another server!`)
end

local function release(player: Player)
	local plot = PlotService.plotFor(player)
	if not plot then
		return
	end
	for id, model in plot.models do
		model:Destroy()
		plot.models[id] = nil
	end
	plot.owner = nil
	plot.pad:SetAttribute("OwnerUserId", nil)
	setSign(plot, "EMPTY BASE")
end

function PlotService.init()
	Players.PlayerRemoving:Connect(release)

	local remote = Net.get("StoreNomling") :: RemoteFunction
	remote.OnServerInvoke = function(player, nomlingId)
		return PlotService.store(player, nomlingId)
	end
end

--- Finding the pads belongs in start(), not init().
---
--- PlazaService builds the plaza in ITS start(), and Bootstrap runs every
--- service's init() before any service's start(). Doing this in init() waited
--- 30 seconds for a plaza that did not exist yet, gave up, and left `plots`
--- empty -- so nobody would ever have been given a plot and nothing would ever
--- have rendered. SERVICE_ORDER puts PlazaService first, so by the time this
--- runs the pads are there.
--- Finds the bases and builds their pedestals. Safe to call repeatedly: it
--- does nothing once `plots` is populated.
local function discoverPlots(): boolean
	if #plots > 0 then
		return true
	end
	-- WaitForChild, not FindFirstChild. WorldService builds the street in its
	-- own start(), and the bootstrap pcalls each start() in turn -- so anything
	-- that makes WorldService slow or throw leaves the street missing at this
	-- exact moment. ConveyorService already learned this and waits; this one
	-- did not, and gave up instead.
	local street = Workspace:WaitForChild("Street", 20)
	local folder = street and street:FindFirstChild("Bases")
	if not folder then
		return false
	end

	for i = 1, PLOT_COUNT do
		local base = folder:FindFirstChild(`Base{i}`)
		local pad = base and base:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			local plot: Plot = { index = i, pad = pad, owner = nil, pedestals = {}, models = {} }
			buildPedestals(plot)
			table.insert(plots, plot)
		end
	end
	return #plots > 0
end

function PlotService.start()
	-- REGISTERED FIRST, AND UNCONDITIONALLY. This used to sit after a world
	-- lookup that returned early when the street was missing -- so a single
	-- hiccup in WorldService meant this callback was never registered at all,
	-- and NOBODY on that server was ever assigned a base for as long as it
	-- lived. The symptom is a player wandering a street that has no home for
	-- them, with nothing in the game saying why. Nothing about finding the
	-- world should be able to stop base assignment from being wired up.
	DataService.onLoaded(function(player)
		-- Discovered here rather than at start, so a late or slow world still
		-- produces a base instead of a permanent silent failure.
		if not discoverPlots() then
			warn("[PlotService] no Bases folder; cannot assign a base")
			local notify = Net.get("Notify") :: RemoteEvent
			notify:FireClient(
				player,
				"Your base is still being built — please rejoin in a moment."
			)
			return
		end
		assign(player)
	end)

	-- Still done eagerly when possible: pedestals are dozens of parts per base
	-- and building them while a player waits to be teleported home is the one
	-- moment it would be felt.
	if discoverPlots() then
		print(`[PlotService] {#plots} bases ready`)
	else
		warn("[PlotService] no bases at start; will retry when a profile lands")
	end
end

return PlotService
