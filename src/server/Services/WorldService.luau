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
	local road = Instance.new("Folder")
	road.Name = "Road"

	part({
		Name = "Asphalt",
		Size = Vector3.new(World.STREET_WIDTH, 1, World.STREET_LENGTH),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(196, 186, 206),
		Material = Enum.Material.SmoothPlastic,
	}, road)

	-- Pavement either side, slightly raised, in a lighter stone. The step is
	-- 0.35 studs: visible as an edge, low enough that a phone player walks
	-- straight over it without ever having to jump.
	for _, side in { -1, 1 } do
		part({
			Name = "Pavement",
			Size = Vector3.new(6, 1.35, World.STREET_LENGTH),
			CFrame = CFrame.new(side * (World.KERB_X + 2), -0.325, 0),
			Color = Color3.fromRGB(252, 240, 214),
			Material = Enum.Material.SmoothPlastic,
		}, road)
		part({
			Name = "Kerb",
			Size = Vector3.new(0.8, 1.5, World.STREET_LENGTH),
			CFrame = CFrame.new(side * (World.KERB_X - 0.4), -0.25, 0),
			Color = Style.PALETTE.nomCream,
			Material = Enum.Material.Concrete,
		}, road)
	end

	-- Dashed markings between the belt and each pavement, which is what makes
	-- the middle read as a road rather than as a strip of floor.
	local dash = 9
	local gap = 7
	local lane = (World.BELT_WIDTH / 2 + World.KERB_X) / 2
	local z = -World.STREET_LENGTH / 2 + dash
	while z < World.STREET_LENGTH / 2 - dash do
		for _, side in { -1, 1 } do
			part({
				Name = "Dash",
				Size = Vector3.new(0.7, 0.06, dash),
				CFrame = CFrame.new(side * lane, 0.03, z),
				Color = Style.PALETTE.nomCream,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}, road)
		end
		z += dash + gap
	end

	road.Parent = parent
end

--- Lamp posts. These are the only scenery that collides, because they are tall
--- and obvious; everything else is walk-through so nobody is stopped by a
--- decoration. Each carries a warm PointLight, which is most of what makes the
--- street feel lit rather than merely bright.
local function buildLamps(parent: Instance)
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"

	local count = math.floor(World.STREET_LENGTH / World.LAMP_SPACING)
	for i = 0, count do
		local z = -World.STREET_LENGTH / 2 + 30 + i * World.LAMP_SPACING
		if z > World.STREET_LENGTH / 2 - 20 then
			break
		end
		for _, side in { -1, 1 } do
			local x = side * (World.KERB_X + 3.4)
			part({
				Name = "LampPost",
				Size = Vector3.new(0.7, World.LAMP_HEIGHT, 0.7),
				CFrame = CFrame.new(x, World.LAMP_HEIGHT / 2, z),
				Color = Style.PALETTE.nomCocoa,
				Material = Enum.Material.Wood,
			}, lamps)

			local head = part({
				Name = "LampHead",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = CFrame.new(x, World.LAMP_HEIGHT + 0.6, z),
				Color = Style.PALETTE.nomCream,
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, lamps)

			local glow = Instance.new("PointLight")
			glow.Brightness = 1.1
			glow.Range = 34
			glow.Color = Color3.fromRGB(255, 226, 172)
			glow.Shadows = false
			glow.Parent = head
		end
	end

	lamps.Parent = parent
end

--- Planters between the lamps. Non-colliding: a phone player running from a
--- snatch must never be stopped by shrubbery.
local function buildPlanters(parent: Instance)
	local planters = Instance.new("Folder")
	planters.Name = "Planters"

	local count = math.floor(World.STREET_LENGTH / World.PLANTER_SPACING)
	for i = 0, count do
		local z = -World.STREET_LENGTH / 2 + 22 + i * World.PLANTER_SPACING
		if z > World.STREET_LENGTH / 2 - 16 then
			break
		end
		-- Skip where a lamp already stands, or the pavement becomes clutter.
		if i % 2 == 0 then
			continue
		end
		for _, side in { -1, 1 } do
			local x = side * (World.KERB_X + 3.2)
			part({
				Name = "Planter",
				Size = Vector3.new(3.2, 2.2, 3.2),
				CFrame = CFrame.new(x, 1.1, z),
				Color = Style.PALETTE.nomCocoa,
				Material = Enum.Material.Wood,
				CanCollide = false,
			}, planters)
			for leaf = 1, 3 do
				local spread = 0.9
				part({
					Name = "Leaf",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2.4 - leaf * 0.3, 2.0 - leaf * 0.25, 2.4 - leaf * 0.3),
					CFrame = CFrame.new(
						x + (leaf - 2) * spread,
						2.6 + leaf * 0.35,
						z + (leaf % 2 == 0 and spread or -spread) * 0.6
					),
					Color = Color3.fromRGB(104 + leaf * 14, 164 + leaf * 10, 92),
					Material = Enum.Material.Grass,
					CanCollide = false,
				}, planters)
			end
		end
	end

	planters.Parent = parent
end

--- Silhouetted buildings past each end of the street, plus a low skyline along
--- the back. Pure parallax: it costs nothing and it stops the world visibly
--- ending at the last base, which is the single clearest "this is a prototype"
--- tell in a Roblox scene.
--- A toy-town skyline past each end of the street and behind both sides. Pure
--- parallax: it costs nothing and it stops the world visibly ending at the last
--- base, which is the clearest "this is a prototype" tell in a Roblox scene.
---
--- CANDY COLOURS, NOT CONCRETE. An earlier pass made these grey, which read as
--- a city and made a bright toy street look like it had been dropped into one.
--- Each building gets a coloured roof too, so none of them is one flat block.
local function buildBackdrop(parent: Instance)
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	local palette = Style.SKYLINE
	local roofs = Style.SKYLINE_ROOF

	local function tower(x: number, z: number, width: number, height: number, index: number)
		local colour = palette[(index % #palette) + 1]
		local roof = roofs[(index % #roofs) + 1]
		part({
			Name = "FarBuilding",
			Size = Vector3.new(width, height, 30),
			CFrame = CFrame.new(x, height / 2 - 2, z),
			Color = colour,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}, backdrop)
		-- A pitched roof cap, so the skyline has a silhouette instead of a
		-- flat top edge.
		part({
			Name = "FarRoof",
			Size = Vector3.new(width + 3, 5, 34),
			CFrame = CFrame.new(x, height - 0.5, z),
			Color = roof,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		}, backdrop)
	end

	local far = World.STREET_LENGTH / 2 + World.BACKDROP_DISTANCE
	local index = 0
	for _, endZ in { -far, far } do
		for slot = -3, 3 do
			local height = World.BACKDROP_HEIGHT * (0.55 + ((slot + 3) % 3) * 0.22)
			local width = 34 + ((slot + 5) % 4) * 12
			tower(slot * 46, endZ + (slot % 2) * 26, width, height, index)
			index += 1
		end
	end

	for _, side in { -1, 1 } do
		local x = side * (World.KERB_X + World.BASE_DEPTH + 60)
		for slot = -4, 4 do
			local height = World.BACKDROP_HEIGHT * (0.4 + ((slot + 4) % 4) * 0.16)
			tower(x + (slot % 2) * 22, slot * 64, 30, height, index)
			index += 1
		end
	end

	backdrop.Parent = parent
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

	-- Side rails, so the belt reads as machinery rather than as a painted strip.
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(0.8, 1.1, World.STREET_LENGTH),
			CFrame = CFrame.new(side * (World.BELT_WIDTH / 2 + 0.4), World.BELT_HEIGHT * 0.9, 0),
			Color = Style.PALETTE.nomCocoa,
			Material = Enum.Material.Metal,
			CanCollide = false,
		}, belt)
		part({
			Name = "RailGlow",
			Size = Vector3.new(0.3, 0.16, World.STREET_LENGTH),
			CFrame = CFrame.new(side * (World.BELT_WIDTH / 2 + 0.4), World.BELT_HEIGHT * 1.45, 0),
			Color = Style.PALETTE.nomMint,
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

	-- A stone path from the kerb to the back wall. It tells a new player where
	-- to walk without a single word of instruction.
	part({
		Name = "Path",
		Size = Vector3.new(World.BASE_DEPTH, 0.12, 10),
		CFrame = CFrame.new(cx, 0.06, cz),
		Color = Style.PALETTE.plazaStone,
		Material = Enum.Material.Concrete,
		CanCollide = false,
	}, model)

	-- A striped awning over the base front, alternating brand colours. This is
	-- the single cheapest thing that makes eight identical plots look like eight
	-- market stalls.
	local stripes = 9
	local stripeWidth = World.BASE_WIDTH / stripes
	for i = 0, stripes - 1 do
		part({
			Name = "Awning",
			Size = Vector3.new(11, 0.5, stripeWidth),
			CFrame = CFrame.new(
				cx - side * (World.BASE_DEPTH / 2 - 5),
				9.4,
				cz - World.BASE_WIDTH / 2 + stripeWidth * (i + 0.5)
			) * CFrame.Angles(0, 0, math.rad(side * -8)),
			Color = if i % 2 == 0 then Style.PALETTE.nomOrange else Style.PALETTE.nomCream,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, model)
	end
	for _, edge in { -1, 1 } do
		part({
			Name = "AwningPost",
			Size = Vector3.new(0.6, 9.4, 0.6),
			CFrame = CFrame.new(
				cx - side * (World.BASE_DEPTH / 2 - 9.5),
				4.7,
				cz + edge * (World.BASE_WIDTH / 2 - 1.5)
			),
			Color = Style.PALETTE.nomCocoa,
			Material = Enum.Material.Wood,
			CanCollide = false,
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

--- The two landmarks at either end of the street, so the road runs BETWEEN
--- somewhere and somewhere else instead of just ending.
---
--- HARD RULE (docs/COMPLIANCE.md 1): no casino visual language anywhere. The
--- Egg Market is a market stall and the Fusion Lab is a KITCHEN. No wheels, no
--- reels, no levers, nothing that spins. Gambling imagery forces a Moderate
--- maturity rating, which loses the Roblox Kids tier outright -- the cheapest
--- compliance win available and the easiest to lose in an art pass.
local function buildLandmark(parent: Instance, name: string, z: number, facing: number)
	local model = Instance.new("Model")
	model.Name = name

	local width = 46
	local depth = 24
	local height = 20

	part({
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = CFrame.new(0, -0.5, z),
		Color = Style.PALETTE.plazaStone,
		Material = Enum.Material.Concrete,
	}, model)

	part({
		Name = "Back",
		Size = Vector3.new(width, height, 1.5),
		CFrame = CFrame.new(0, height / 2, z + facing * depth / 2),
		Color = Style.PALETTE.nomCream,
		Material = Enum.Material.SmoothPlastic,
	}, model)

	for _, side in { -1, 1 } do
		part({
			Name = "Side",
			Size = Vector3.new(1.5, height, depth),
			CFrame = CFrame.new(side * width / 2, height / 2, z),
			Color = Style.PALETTE.nomCream,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end

	-- A pitched roof, built from two tilted slabs. Two parts, and the building
	-- stops reading as a box.
	for _, side in { -1, 1 } do
		part({
			Name = "Roof",
			Size = Vector3.new(width * 0.56, 1.2, depth + 4),
			CFrame = CFrame.new(side * width * 0.24, height + 3.4, z)
				* CFrame.Angles(0, 0, math.rad(side * -22)),
			Color = if name == "FusionLab" then Style.PALETTE.nomMint else Style.PALETTE.nomOrange,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, model)
	end

	-- The counter you walk up to. It carries a prompt, because a landmark you
	-- can walk into and that does nothing reads as unfinished -- and a child
	-- WILL walk up to the big building with the sign on it.
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(width * 0.7, 4.5, 4),
		CFrame = CFrame.new(0, 2.25, z - facing * (depth / 2 - 5)),
		Color = Style.PALETTE.nomCocoa,
		Material = Enum.Material.Wood,
	}, model)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Use"
	prompt.ActionText = if name == "FusionLab" then "Open the Kitchen" else "Open the Egg Market"
	prompt.ObjectText = if name == "FusionLab" then "Fusion Kitchen" else "Egg Market"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	-- Handled entirely on the client: it opens a panel and changes no state, so
	-- there is nothing for the server to validate.
	prompt.Parent = counter

	local signPost = part({
		Name = "SignAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, height + 8, z),
		Color = Style.PALETTE.nomCream,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Transparency = 1,
	}, model)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromScale(30, 8)
	gui.MaxDistance = 400
	gui.Parent = signPost

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomCream
	label.TextStrokeTransparency = 0.2
	label.Text = if name == "FusionLab" then "🧪 FUSION KITCHEN" else "🥚 EGG MARKET"
	label.Parent = gui

	if name == "FusionLab" then
		-- A reveal stage: a lit plinth the new creature appears on. This is
		-- where the whole game points.
		local stage = part({
			Name = "RevealStage",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 14, 14),
			CFrame = CFrame.new(0, 0.8, z + facing * 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Style.PALETTE.nomBlue,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)

		local glow = Instance.new("PointLight")
		glow.Brightness = 2.4
		glow.Range = 30
		glow.Color = Style.PALETTE.nomBlue
		glow.Parent = stage

		-- Cooking pots on the counter. A kitchen, not a machine.
		for i = -1, 1 do
			part({
				Name = "Pot",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3.2, 3.6, 3.6),
				CFrame = CFrame.new(i * 9, 6.2, z - facing * (depth / 2 - 5))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Style.PALETTE.shadow,
				Material = Enum.Material.Metal,
				CanCollide = false,
			}, model)
		end
	end

	model.Parent = parent
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
	buildLamps(street)
	buildPlanters(street)
	buildBackdrop(street)

	local landmarkZ = World.STREET_LENGTH / 2 + 16
	buildLandmark(street, "FusionLab", landmarkZ, 1)
	buildLandmark(street, "EggMarket", -landmarkZ, -1)

	-- A leaderboard on the road, where everybody walks past it. Seeing your own
	-- name on a board is worth a surprising amount to a nine-year-old, and it is
	-- the cheapest social pressure in the game (GDD 5.12).
	local boardPost = part({
		Name = "LeaderboardPost",
		Size = Vector3.new(1.4, 16, 1.4),
		CFrame = CFrame.new(-World.KERB_X - 4, 8, 0),
		Color = Style.PALETTE.nomCocoa,
		Material = Enum.Material.Wood,
	}, street)

	local board = part({
		Name = "Leaderboard",
		Size = Vector3.new(0.6, 13, 20),
		CFrame = CFrame.new(-World.KERB_X - 4, 17, 0),
		Color = Style.PALETTE.nomCream,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, street)
	local _ = boardPost

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Board"
	boardGui.Face = Enum.NormalId.Right
	boardGui.CanvasSize = Vector2.new(400, 260)
	boardGui.LightInfluence = 0
	boardGui.Parent = board

	local backing = Instance.new("Frame")
	backing.Size = UDim2.fromScale(1, 1)
	backing.BackgroundColor3 = Style.PALETTE.nomCream
	backing.BorderSizePixel = 0
	backing.Parent = boardGui

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -16, 0, 44)
	heading.Position = UDim2.new(0, 8, 0, 6)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.FredokaOne
	heading.TextScaled = true
	heading.TextColor3 = Style.PALETTE.ink
	heading.Text = "🏆 TOP NOMLERS"
	heading.Parent = backing

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.Size = UDim2.new(1, -16, 1, -56)
	rows.Position = UDim2.new(0, 8, 0, 52)
	rows.BackgroundTransparency = 1
	rows.Parent = backing

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 4)
	rowLayout.Parent = rows

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
