--!strict
--[[
	Builds the M0 plaza: a central hub with eight plot pads around it.

	Built in code rather than loaded from a .rbxm on purpose. The brief plans a
	worldgen/ Lune pipeline that emits static models, and that is still the
	right destination -- but putting an asset-serialisation pipeline on the
	critical path for the very first deploy buys risk we do not need yet.
	Revisit at M2, when the plaza gains real content. Logged in DECISIONS.md.

	Everything here is decoration. No gameplay, no remotes, no data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Style = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Style"))

local PlazaService = {}
PlazaService.Name = "PlazaService"

local PLOT_COUNT = 8
local PLAZA_RADIUS = 48
local PLOT_RADIUS = 96
local PLOT_SIZE = Vector3.new(44, 1, 44)

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function buildPlazaFloor(parent: Instance)
	local floor = makePart({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		-- A cylinder's length runs along X, so rotate it to lie flat.
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Style.PALETTE.plazaStone,
		Material = Style.MATERIAL.plaza,
	})
	floor.Parent = parent

	local ring = makePart({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, PLAZA_RADIUS * 2 + 8, PLAZA_RADIUS * 2 + 8),
		CFrame = CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Style.PALETTE.plazaStoneAlt,
		Material = Style.MATERIAL.plaza,
	})
	ring.Parent = parent
end

--- A market stall, deliberately NOT a prize wheel. See the hard rule in Style.
local function buildEggMarket(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "EggMarket"

	local counter = makePart({
		Name = "Counter",
		Size = Vector3.new(14, 4, 5),
		CFrame = CFrame.new(0, 2, -26),
		Color = Style.PALETTE.nomCream,
		Material = Style.MATERIAL.prop,
	})
	counter.Parent = model

	local canopy = makePart({
		Name = "Canopy",
		Size = Vector3.new(16, 0.8, 7),
		CFrame = CFrame.new(0, 7.5, -26),
		Color = Style.PALETTE.nomOrange,
		Material = Style.MATERIAL.prop,
	})
	canopy.Parent = model

	for _, side in { -1, 1 } do
		local post = makePart({
			Name = "Post",
			Size = Vector3.new(0.6, 7, 0.6),
			CFrame = CFrame.new(side * 7.2, 3.5, -26),
			Color = Style.PALETTE.nomCocoa,
			Material = Style.MATERIAL.prop,
		})
		post.Parent = model
	end

	model.Parent = parent
end

--- A kitchen, deliberately NOT a slot machine. See the hard rule in Style.
local function buildFusionLab(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "FusionLab"

	local base = makePart({
		Name = "Base",
		Size = Vector3.new(18, 6, 10),
		CFrame = CFrame.new(0, 3, 26),
		Color = Style.PALETTE.nomMint,
		Material = Style.MATERIAL.prop,
	})
	base.Parent = model

	local screen = makePart({
		Name = "RevealScreen",
		Size = Vector3.new(16, 9, 0.6),
		CFrame = CFrame.new(0, 11, 29),
		Color = Style.PALETTE.nomBlue,
		Material = Style.MATERIAL.accent,
	})
	screen.Parent = model

	model.Parent = parent
end

local function buildPlots(parent: Instance)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"

	for index = 1, PLOT_COUNT do
		local angle = (index - 1) / PLOT_COUNT * math.pi * 2
		local position =
			Vector3.new(math.cos(angle) * PLOT_RADIUS, -0.5, math.sin(angle) * PLOT_RADIUS)

		local pad = makePart({
			Name = `Plot{index}`,
			Size = PLOT_SIZE,
			CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0),
			Color = Style.PALETTE.plotPad,
			Material = Style.MATERIAL.plot,
		})
		pad:SetAttribute("PlotIndex", index)
		pad.Parent = plots
	end

	plots.Parent = parent
end

function PlazaService.start()
	local existing = Workspace:FindFirstChild("Plaza")
	if existing then
		existing:Destroy()
	end

	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"

	buildPlazaFloor(plaza)
	buildEggMarket(plaza)
	buildFusionLab(plaza)
	buildPlots(plaza)

	plaza.Parent = Workspace

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlazaSpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 1.5, 0)
	spawnLocation.Color = Style.PALETTE.nomPink
	spawnLocation.Material = Style.MATERIAL.prop
	spawnLocation.Parent = plaza

	print(`[PlazaService] plaza built with {PLOT_COUNT} plots`)
end

return PlazaService
