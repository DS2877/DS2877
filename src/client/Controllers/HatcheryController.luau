--!strict
--[[
	The eggs, in the world, in a nest in your own base.

	STRAIGHT FROM A PLAYTEST: "the 'tap to hatch' should be grounded on
	something next to what's about to hatch." Before this, an egg was a button
	in a tray at the bottom of the screen -- a label reading TAP TO HATCH with
	nothing under it and no connection to anything you could see. The same
	playtest also said "the buttons and layout on the screen is way too much",
	and both complaints have one answer: put the egg where the egg is.

	So the bench and its cups are real objects, built by WorldService in every
	base. This draws an egg in each occupied cup, counts it down on a sign above
	it, and puts a prompt on it the moment it is ready.

	CLIENT-SIDE AND LOCAL-ONLY. What is in your nest is a private fact about
	your profile, and these parts are created on this client and never
	replicate, so nobody else sees your eggs and no server round-trip is needed
	to draw one. The one thing that does cross the wire is the claim itself,
	which is a RemoteFunction the server re-checks from scratch.

	For Philip: a ProximityPrompt is Roblox's "walk up and press" widget. On a
	phone it draws its own button when you are close enough, which is why the
	egg needs no on-screen button of its own.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local Fault = require(script.Parent.Parent:WaitForChild("Fault"))
local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))
local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local HatcheryController = {}
HatcheryController.Name = "HatcheryController"

type Egg = {
	part: BasePart,
	label: TextLabel,
	prompt: ProximityPrompt,
	--- True once the countdown has hit zero, so the pop only fires once.
	ready: boolean,
	--- Where it rests, so the wobble has something to be relative to.
	home: CFrame,
}

local eggs: { [number]: Egg } = {}
local snapshot: { [string]: any }? = nil
--- The base these eggs were built into. A re-assignment (rejoin, or somebody
--- else's plot being freed) has to move them.
local builtForBase: number? = nil

--- How close you have to be to hatch. Generous: you are standing in your own
--- base and there is nothing here to be careful about.
local PROMPT_RANGE = 16

local function nestFor(baseIndex: number, slot: number): BasePart?
	local street = Workspace:FindFirstChild("Street")
	local bases = street and street:FindFirstChild("Bases")
	local base = bases and bases:FindFirstChild(`Base{baseIndex}`)
	local hatchery = base and base:FindFirstChild("Hatchery")
	local cup = hatchery and hatchery:FindFirstChild(`Nest{slot}`)
	return if cup and cup:IsA("BasePart") then cup else nil
end

local function destroyEgg(slot: number)
	local egg = eggs[slot]
	if not egg then
		return
	end
	eggs[slot] = nil
	egg.part:Destroy()
end

local function buildEgg(baseIndex: number, slot: number): Egg?
	local cup = nestFor(baseIndex, slot)
	if not cup then
		return nil
	end

	local at = CFrame.new(cup.Position + Vector3.new(0, 2.1, 0))

	local shell = Instance.new("Part")
	shell.Name = `ClientEgg{slot}`
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(2.7, 3.5, 2.7)
	shell.Anchored = true
	-- Solid, like everything else in the base. An egg you walk through is
	-- exactly the sort of thing the "physics needs to be correct" note was
	-- about, and it is sitting at knee height where you will meet it.
	shell.CanCollide = true
	shell.CastShadow = false
	shell.Color = Style.PALETTE.nomCream
	shell.Material = Enum.Material.SmoothPlastic
	shell.CFrame = at
	shell.Parent = Workspace

	local speckle = Instance.new("SpecialMesh")
	speckle.MeshType = Enum.MeshType.Sphere
	speckle.Parent = shell

	local sign = Instance.new("BillboardGui")
	sign.Name = "EggSign"
	sign.Size = UDim2.fromScale(11, 3)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	sign.MaxDistance = 180
	sign.Parent = shell

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Style.PALETTE.nomCream
	label.TextStrokeTransparency = 0.15
	label.Text = ""
	label.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Hatch"
	prompt.ActionText = "Hatch!"
	prompt.ObjectText = "Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	-- OFF until the countdown finishes. The prompt APPEARING is the "it's
	-- ready" signal -- which is what the tutorial used to promise with "wait
	-- for the green button" and then never deliver.
	prompt.Enabled = false
	prompt.Parent = shell

	prompt.Triggered:Connect(function()
		local ok, reason, fault = Net.invoke("ClaimHatch", slot)
		if fault then
			Fault.report(fault)
		end
		if ok then
			JuiceController.pop(label, 0.3)
		elseif reason then
			BaseHudController.toast(reason)
		end
	end)

	local egg: Egg = {
		part = shell,
		label = label,
		prompt = prompt,
		ready = false,
		home = at,
	}
	eggs[slot] = egg
	return egg
end

--- Server time, adjusted for how long ago the snapshot arrived.
local function serverNow(snap: { [string]: any }): number
	return (snap.now or os.time()) + (os.clock() - (snap.at or os.clock()))
end

local function refresh()
	local snap = snapshot
	if not snap then
		return
	end
	local baseIndex = tonumber(snap.baseIndex)
	if not baseIndex then
		return
	end

	-- Moved base: throw everything away rather than trying to shuffle it.
	if builtForBase ~= baseIndex then
		for slot in eggs do
			destroyEgg(slot)
		end
		builtForBase = baseIndex
	end

	local incubators = snap.incubators or {}
	local now = serverNow(snap)

	-- Anything no longer in the profile has hatched or been cleared.
	for slot in eggs do
		if not incubators[slot] then
			destroyEgg(slot)
		end
	end

	for slot, entry in incubators do
		local egg = eggs[slot] or buildEgg(baseIndex, slot)
		if not egg then
			continue
		end

		local remaining = math.max(0, (entry.readyAt or 0) - now)
		local tier = Style.EGG_LABEL[entry.tier] or "Egg"

		if remaining <= 0 then
			egg.label.Text = "TAP TO HATCH!"
			egg.label.TextColor3 = Style.PALETTE.nomCream
			egg.part.Color = Style.PALETTE.nomPink
			egg.part.Material = Enum.Material.Neon
			egg.prompt.Enabled = true
			egg.prompt.ObjectText = tier
			if not egg.ready then
				egg.ready = true
				JuiceController.pop(egg.label, 0.35)
			end
		else
			egg.ready = false
			egg.label.Text = `{tier} — {math.ceil(remaining)}s`
			egg.label.TextColor3 = Style.PALETTE.nomCream
			egg.part.Color = Style.PALETTE.nomCream
			egg.part.Material = Enum.Material.SmoothPlastic
			egg.prompt.Enabled = false
		end
	end
end

function HatcheryController.start()
	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		snap.at = os.clock()
		snapshot = snap
	end)

	-- The countdown has to tick between syncs, and the nest may not exist on
	-- this client the first time a profile lands -- the world is built at run
	-- time, so the base can arrive after the profile does. Retrying every tick
	-- is what makes that a non-issue instead of a race.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(refresh)
			if not ok then
				Fault.report(`HatcheryController.refresh -- {err}`)
				-- Back off hard: a fault that repeats four times a second would
				-- bury the first line of the panel, which is the useful one.
				task.wait(5)
			end
		end
	end)

	-- A ready egg rocks in its cup. Movement in the corner of the eye is the
	-- part a player notices from across their own base; the sign is what they
	-- read once they have looked.
	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		for slot, egg in eggs do
			if egg.ready and egg.part.Parent then
				egg.part.CFrame = egg.home
					* CFrame.Angles(0, 0, math.sin(clock * 6 + slot) * 0.24)
					* CFrame.new(0, math.abs(math.sin(clock * 6 + slot)) * 0.3, 0)
			end
		end
	end)
end

return HatcheryController
