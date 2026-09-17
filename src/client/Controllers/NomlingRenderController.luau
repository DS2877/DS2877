--!strict
--[[
	Builds every visible Nomling, on the client, from its genome.

	The server replicates an invisible ANCHOR part carrying the genome as
	attributes, and never a built model -- which is what docs/GDD.md 5.4
	specifies and why: a genome is a handful of strings, a model is twenty
	parts. With eight players and 150 creatures visible that is the difference
	between a playable phone and a slideshow.

	The model is parented to the anchor, so lifecycle is free: when the server
	removes the anchor the creature goes with it and there is no bookkeeping to
	get wrong.

	IDLE MOTION IS DISTANCE-CULLED. A gentle bob is most of what makes these
	read as alive rather than as props, but bobbing 150 assemblies every frame
	on a phone is not affordable. Only the ones near the camera move, at 20 Hz.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NomlingSpec = require(Shared:WaitForChild("Logic"):WaitForChild("NomlingSpec"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local NomlingRenderController = {}
NomlingRenderController.Name = "NomlingRenderController"

local ANCHOR_NAME = "NomlingAnchor"
--- Bob only what the player can actually see move.
local MOTION_RANGE = 70
local MOTION_HZ = 20

local SHAPES: { [string]: Enum.PartType } = {
	block = Enum.PartType.Block,
	ball = Enum.PartType.Ball,
	cylinder = Enum.PartType.Cylinder,
}

local MATERIALS: { [string]: Enum.Material } = {
	plastic = Enum.Material.Plastic,
	smooth = Enum.Material.SmoothPlastic,
	neon = Enum.Material.Neon,
	fabric = Enum.Material.Fabric,
}

type Live = {
	anchor: BasePart,
	root: BasePart,
	phase: number,
	--- The anchor CFrame this creature was last placed at. Comparing against it
	--- is how a MOVING anchor (a belt item, a carried creature) is told apart
	--- from a static one on a pedestal.
	lastOrigin: CFrame,
}

local live: { [BasePart]: Live } = {}
--- Prompts this client has already wired. Tracked here rather than by writing
--- an attribute onto a server-owned instance, which is a local-only write and
--- not something to rely on.
local bound: { [Instance]: boolean } = {}

local function readGenome(anchor: BasePart): NomlingSpec.Genome?
	local snack = anchor:GetAttribute("Snack")
	local animal = anchor:GetAttribute("Animal")
	if type(snack) ~= "string" or type(animal) ~= "string" then
		return nil
	end
	local mutation = anchor:GetAttribute("Mutation")
	return {
		snack = snack,
		animal = animal,
		gen = tonumber(anchor:GetAttribute("Gen")) or 1,
		mutation = if type(mutation) == "string" and #mutation > 0 then mutation else nil,
		seed = tonumber(anchor:GetAttribute("Seed")) or 0,
		archetype = tostring(anchor:GetAttribute("Archetype") or "quadruped_small"),
	}
end

local function paletteFor(genome: NomlingSpec.Genome)
	-- The species id is snack_animal, which is how Config/Nomlings keys itself.
	local species = Nomlings.BY_ID[`{genome.snack}_{genome.animal}`]
	local name = species and species.palette
	return (name and Style.SPECIES_PALETTE[name]) or Style.SPECIES_PALETTE.rice_salmon
end

local function lerp(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

local function colourFor(role: string, palette: any, mutation: string?): (Color3, number)
	-- Eyes are fixed across every species and take no mutation tint: a
	-- creature reads as alive because of its eyes, and recolouring them makes
	-- it read as dead instead.
	if role == "eye" then
		return Style.EYE.white, 0
	elseif role == "pupil" then
		return Style.EYE.pupil, 0
	end

	local BY_ROLE: { [string]: Color3 } = {
		primary = palette.primary,
		secondary = palette.secondary,
		snack = palette.snack,
		accent = palette.snack,
		dark = Style.PALETTE.ink,
	}
	local base = BY_ROLE[role] or palette.primary

	-- A mutation tints the whole creature toward its colour and adds glow. It
	-- has to be obvious from across the street -- that is the point of it.
	local mutationSpec = mutation and Style.MUTATION[mutation]
	if mutationSpec then
		return lerp(base, mutationSpec.tint, 0.45), mutationSpec.glow
	end
	return base, 0
end

local function build(anchor: BasePart)
	if live[anchor] then
		return
	end
	local genome = readGenome(anchor)
	if not genome then
		return
	end

	local palette = paletteFor(genome)
	local scale = NomlingSpec.scaleFor(genome)
	local specs = NomlingSpec.build(genome)

	local model = Instance.new("Model")
	model.Name = "NomlingModel"

	-- The root carries the whole assembly. Everything else is welded to it and
	-- massless, so one CFrame write moves the creature.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = anchor.CFrame
	root.Parent = model
	model.PrimaryPart = root

	local mutationGlow = 0

	for _, spec in specs do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		-- The anchor owns interaction (its ProximityPrompt is server-made), so
		-- the visual parts must not intercept taps or raycasts.
		part.CanQuery = false
		part.CanTouch = false
		part.Shape = SHAPES[spec.shape] or Enum.PartType.Block
		part.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z) * scale
		part.Material = MATERIALS[spec.material] or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth

		local colour, glow = colourFor(spec.role, palette, genome.mutation)
		part.Color = colour
		if glow > 0 and spec.role ~= "eye" and spec.role ~= "pupil" then
			mutationGlow = math.max(mutationGlow, glow)
		end

		local offset = Vector3.new(spec.offset.x, spec.offset.y, spec.offset.z) * scale
		part.CFrame = anchor.CFrame
			* CFrame.new(offset)
			* CFrame.Angles(math.rad(spec.tilt.x), math.rad(spec.tilt.y), math.rad(spec.tilt.z))
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	-- Mutation aura. One PointLight and one sparkle emitter, not per part --
	-- 150 creatures with per-part effects is how a phone catches fire.
	if mutationGlow > 0 then
		local light = Instance.new("PointLight")
		light.Name = "Aura"
		light.Brightness = mutationGlow * 2.2
		light.Range = 10 + mutationGlow * 8
		light.Color = (Style.MUTATION[genome.mutation :: string] or {}).tint or Color3.new(1, 1, 1)
		light.Parent = root

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Rate = 4 + mutationGlow * 8
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Size = NumberSequence.new(0.28)
		sparkle.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparkle.Color = ColorSequence.new(light.Color)
		sparkle.LightEmission = 0.8
		sparkle.Parent = root
	end

	-- Ownership decides which prompt this player sees. Both exist on the
	-- anchor; enabling one locally does not replicate, so every player gets the
	-- right verb on the same creature.
	local owner = tonumber(anchor:GetAttribute("OwnerUserId")) or 0
	local mine = owner == Players.LocalPlayer.UserId
	local store = anchor:FindFirstChild("Store")
	local snatch = anchor:FindFirstChild("Snatch")
	if store and store:IsA("ProximityPrompt") then
		store.Enabled = mine
		if mine and not bound[store] then
			bound[store] = true
			local nomlingId = tostring(anchor:GetAttribute("NomlingId") or "")
			store.Triggered:Connect(function()
				local remote = Net.get("StoreNomling") :: RemoteFunction
				remote:InvokeServer(nomlingId)
			end)
		end
	end
	if snatch and snatch:IsA("ProximityPrompt") then
		-- Never offer to steal from yourself. The server refuses it anyway, but
		-- a prompt that always fails is noise on the one creature you look at
		-- most.
		snatch.Enabled = not mine
	end

	model.Parent = anchor
	live[anchor] = {
		anchor = anchor,
		root = root,
		-- A per-creature phase, so a plot of eight does not bob in lockstep --
		-- synchronised idle motion reads as mechanical immediately.
		phase = (genome.seed % 1000) / 1000 * math.pi * 2,
		lastOrigin = anchor.CFrame,
	}
end

local function destroy(anchor: BasePart)
	live[anchor] = nil
end

local function watch(instance: Instance)
	if instance:IsA("BasePart") and instance.Name == ANCHOR_NAME then
		-- Attributes may land a frame after the part does.
		task.defer(build, instance)
	end
end

function NomlingRenderController.start()
	for _, descendant in Workspace:GetDescendants() do
		watch(descendant)
	end
	Workspace.DescendantAdded:Connect(watch)
	Workspace.DescendantRemoving:Connect(function(instance)
		if instance:IsA("BasePart") then
			destroy(instance)
		end
	end)

	local camera = Workspace.CurrentCamera
	local accumulator = 0
	local step = 1 / MOTION_HZ

	RunService.RenderStepped:Connect(function(delta)
		accumulator += delta
		if accumulator < step then
			return
		end
		accumulator = 0

		camera = Workspace.CurrentCamera or camera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local clock = os.clock()

		for anchor, entry in live do
			if not anchor.Parent then
				live[anchor] = nil
				continue
			end

			local origin = anchor.CFrame
			-- A MOVED anchor must always be followed, however far away it is.
			-- Belt creatures ride the length of the street and a carried one
			-- runs off with a thief; syncing only what is near the camera left
			-- those visually detached from their anchors, which was a real bug
			-- and an obvious one on screen.
			local moved = (origin.Position - entry.lastOrigin.Position).Magnitude > 0.01
			local near = (origin.Position - eye).Magnitude <= MOTION_RANGE

			if not moved and not near then
				continue
			end
			entry.lastOrigin = origin

			if near then
				-- A slow bob and a slight sway. Small numbers on purpose: this
				-- should read as breathing, not as floating.
				local t = clock * 1.6 + entry.phase
				entry.root.CFrame = origin
					* CFrame.new(0, math.sin(t) * 0.16, 0)
					* CFrame.Angles(0, math.rad(math.sin(t * 0.5) * 2.5), 0)
			else
				-- Far away: follow exactly, and spend nothing on animation
				-- nobody can see.
				entry.root.CFrame = origin
			end
		end
	end)
end

return NomlingRenderController
