--!strict
--[[
	Builds the street: one road, a delivery belt down the middle, and eight
	open bases lining both sides.

	REPLACES PlazaService. That built the GDD's ring of plots around a central
	plaza, and the first playtest killed it in one sentence: "I can't reach any
	of the bases." The pads had empty space between them, so the stealing half
	of the game was not reachable on foot. See src/shared/Config/World.luau.

	Every base is OPEN to the road on purpose. Nothing here has a wall or a
	door: walking into someone's base has to be effortless or nobody will ever
	try it, and defending is meant to be the Laser Gate (GDD 5.8), not geometry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))

local WorldService = {}
WorldService.Name = "WorldService"

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function buildRoad(parent: Instance)
	part({
		Name = "Road",
		Size = Vector3.new(World.STREET_WIDTH, 1, World.STREET_LENGTH),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = Style.PALETTE.plazaStoneAlt,
		Material = Enum.Material.Concrete,
	}, parent)

	-- Kerbs. Low enough to walk straight over -- they mark the edge of the
	-- road, they do not stop anyone. A phone player should never have to jump.
	for _, side in { -1, 1 } do
		part({
			Name = "Kerb",
			Size = Vector3.new(2, 0.6, World.STREET_LENGTH),
			CFrame = CFrame.new(side * World.KERB_X, -0.2, 0),
			Color = Style.PALETTE.plazaStone,
			Material = Enum.Material.Concrete,
		}, parent)
	end
end

local function buildBelt(parent: Instance)
	local belt = Instance.new("Folder")
	belt.Name = "Belt"

	part({
		Name = "Track",
		Size = Vector3.new(World.BELT_WIDTH, World.BELT_HEIGHT, World.STREET_LENGTH),
		CFrame = CFrame.new(0, World.BELT_HEIGHT / 2, 0),
		Color = Style.PALETTE.nomCocoa,
		Material = Enum.Material.Fabric,
	}, belt)

	-- Chevrons pointing the way the belt runs, so which direction things move
	-- is readable at a glance instead of something you work out by watching.
	local spacing = 24
	local count = math.floor(World.STREET_LENGTH / spacing)
	for i = 0, count do
		local z = -World.STREET_LENGTH / 2 + i * spacing
		part({
			Name = "Chevron",
			Size = Vector3.new(World.BELT_WIDTH * 0.5, 0.08, 2.4),
			CFrame = CFrame.new(0, World.BELT_HEIGHT + 0.04, z),
			Color = Style.PALETTE.nomOrange,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, belt)
	end

	belt.Parent = parent
end

local function buildBase(index: number, parent: Instance): BasePart
	local cx, cz, side = World.baseCenter(index)

	local model = Instance.new("Model")
	model.Name = `Base{index}`

	local pad = part({
		Name = "Pad",
		Size = Vector3.new(World.BASE_DEPTH, 1, World.BASE_WIDTH),
		CFrame = CFrame.new(cx, -0.5, cz),
		Color = Style.PALETTE.plotPad,
		Material = Enum.Material.Grass,
	}, model)
	pad:SetAttribute("BaseIndex", index)

	-- A back wall and two low side walls. The road side stays wide open.
	part({
		Name = "BackWall",
		Size = Vector3.new(1.5, 14, World.BASE_WIDTH),
		CFrame = CFrame.new(cx + side * World.BASE_DEPTH / 2, 7, cz),
		Color = Style.PALETTE.nomCream,
		Material = Enum.Material.SmoothPlastic,
	}, model)
	for _, edge in { -1, 1 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(World.BASE_DEPTH, 3, 1.5),
			CFrame = CFrame.new(cx, 1.5, cz + edge * World.BASE_WIDTH / 2),
			Color = Style.PALETTE.plotEdge,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end

	-- Owner sign, over the back wall, readable from the road.
	local signPost = part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 22),
		CFrame = CFrame.new(cx + side * (World.BASE_DEPTH / 2 - 1), 15, cz),
		Color = Style.PALETTE.nomCocoa,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Transparency = 1,
	}, model)

	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerSign"
	gui.Size = UDim2.fromScale(22, 5)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 260
	gui.Parent = signPost

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomCream
	label.TextStrokeTransparency = 0.3
	label.Text = "EMPTY BASE"
	label.Parent = gui

	model.Parent = parent
	return pad
end

function WorldService.start()
	local existing = Workspace:FindFirstChild("Street")
	if existing then
		existing:Destroy()
	end

	local street = Instance.new("Model")
	street.Name = "Street"

	buildRoad(street)
	buildBelt(street)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	for index = 1, World.BASE_COUNT do
		buildBase(index, bases)
	end
	bases.Parent = street

	street.Parent = Workspace

	-- One spawn on the road. Players are moved to their own base as soon as
	-- their profile lands, but they must never fall through the void first.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StreetSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, -World.STREET_LENGTH / 2 + 20)
	spawn.Color = Style.PALETTE.nomPink
	spawn.Material = Enum.Material.Neon
	spawn.Parent = street

	print(`[WorldService] street built: {World.BASE_COUNT} bases, {World.STREET_LENGTH} studs`)
end

return WorldService
