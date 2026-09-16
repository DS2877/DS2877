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

local DataService = require(script.Parent:WaitForChild("DataService"))

local PlotService = {}
PlotService.Name = "PlotService"

local PEDESTAL_HEIGHT = 3
local PEDESTAL_SIZE = Vector3.new(4, PEDESTAL_HEIGHT, 4)
local PLOT_COUNT = 8

type Plot = {
	index: number,
	pad: BasePart,
	owner: Player?,
	pedestals: { BasePart },
	models: { [string]: Model },
}

local plots: { Plot } = {}

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

	for i, cframe in pedestalPositions(plot.pad) do
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

--- Placeholder visual. Replaced by NomlingBuilder at M2a; the genome is
--- already passed in full so the swap needs nothing new.
local function buildNomlingModel(nomling: Profile.Nomling): Model
	local model = Instance.new("Model")
	model.Name = `Nomling_{nomling.id}`

	local rarity = Style.RARITY[nomling.rarity] or Style.RARITY.common

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.6, 2.6, 2.6)
	body.Color = rarity.color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model
	model.PrimaryPart = body

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(6, 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = false
	-- A phone screen is small and a plot holds eight of these. Past this
	-- distance the labels turn into noise.
	gui.MaxDistance = 60
	gui.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomCream
	label.TextStrokeTransparency = 0.4
	-- Rarity is never colour alone -- the label carries the word too
	-- (docs/GDD.md 5.16).
	label.Text = `{nomling.snack} {nomling.animal}\n{rarity.label}`
	label.Parent = gui

	return model
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
		local model = buildNomlingModel(nomling)
		model:PivotTo(pedestal.CFrame * CFrame.new(0, PEDESTAL_HEIGHT / 2 + 1.4, 0))
		model.Parent = plot.pad
		plot.models[nomlingId] = model
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

local function assign(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.pad:SetAttribute("OwnerUserId", player.UserId)
			PlotService.render(player)
			return
		end
	end
	warn(`[PlotService] no free plot for {player.Name}; {PLOT_COUNT} plots, all taken`)
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
end

function PlotService.init()
	Players.PlayerRemoving:Connect(release)
end

--- Finding the pads belongs in start(), not init().
---
--- PlazaService builds the plaza in ITS start(), and Bootstrap runs every
--- service's init() before any service's start(). Doing this in init() waited
--- 30 seconds for a plaza that did not exist yet, gave up, and left `plots`
--- empty -- so nobody would ever have been given a plot and nothing would ever
--- have rendered. SERVICE_ORDER puts PlazaService first, so by the time this
--- runs the pads are there.
function PlotService.start()
	local plaza = Workspace:FindFirstChild("Plaza")
	local folder = plaza and plaza:FindFirstChild("Plots")
	if not folder then
		warn("[PlotService] no Plots folder; is PlazaService before PlotService in SERVICE_ORDER?")
		return
	end

	for i = 1, PLOT_COUNT do
		local pad = folder:FindFirstChild(`Plot{i}`)
		if pad and pad:IsA("BasePart") then
			local plot: Plot = { index = i, pad = pad, owner = nil, pedestals = {}, models = {} }
			buildPedestals(plot)
			table.insert(plots, plot)
		end
	end

	-- A plot is assigned when the profile lands, not when the player joins --
	-- there is nothing to draw before then.
	DataService.onLoaded(function(player)
		assign(player)
	end)
end

return PlotService
