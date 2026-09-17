--!strict
--[[
	The Laser Gate: 60 seconds of "not today", then 90 seconds of recharge.

	A base is open to the road by design (GDD 5.3) -- no walls, no doors,
	because walking into someone's base has to be effortless or nobody ever
	tries it. The Gate is the entire defence, and it is deliberately a MOMENT
	rather than a wall: it cannot be held, so choosing when to spend it is the
	whole skill of defending.

	WHAT THE GATE ACTUALLY DOES is refuse snatches. It does NOT collide. A solid
	barrier would trap the owner on whichever side they were standing, and it
	would put client physics in charge of who gets robbed. The lasers are how a
	thief sees it from the road; SnatchRules is what stops them.

	THE TIME ARITHMETIC LIVES IN shared/Logic/GateRules -- pure, and unit-tested
	at its boundaries, because the interesting cases here last one frame and
	are impossible to stand on by hand in a live server.

	THE STATE IS NOT SAVED, on purpose. A cooldown only matters while you are in
	the server, and leaving releases your base anyway (PlotService.release), so
	there is nothing to gain by rejoining to reset it -- you would be rejoining
	into a different base with nothing on it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GateRules = require(Shared:WaitForChild("Logic"):WaitForChild("GateRules"))
local Net = require(Shared:WaitForChild("Net"))
local Snatch = require(Shared:WaitForChild("Config"):WaitForChild("Snatch"))
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))

local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local FeedbackService = require(script.Parent:WaitForChild("FeedbackService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local GateService = {}
GateService.Name = "GateService"

local CONFIG: GateRules.Config = {
	GATE_SECONDS = Snatch.GATE_SECONDS,
	GATE_COOLDOWN_SECONDS = Snatch.GATE_COOLDOWN_SECONDS,
}

--- base index -> os.clock() when its gate last went up.
---
--- Keyed by BASE, not by player. A gate belongs to the plot: if the owner
--- leaves mid-gate the lasers must come down with them, and the next person to
--- take that plot must not inherit either a raised gate or a cooldown.
local raisedAt: { [number]: number } = {}

--- What every client was last told, so the broadcast only goes out on a change
--- rather than every tick. Eight bases is a small payload, but a payload sent
--- four times a second is still a payload sent four times a second.
local broadcast: { [number]: boolean } = {}

--- Is this base's gate up right now? The one question snatching asks.
function GateService.isUp(baseIndex: number): boolean
	return GateRules.isUp(raisedAt[baseIndex], os.clock(), CONFIG)
end

--- Is this PLAYER's base gated? The form StealService and the NPCs want, since
--- they know a victim rather than a plot.
function GateService.isUpFor(player: Player): boolean
	local plot = PlotService.plotFor(player)
	if not plot then
		return false
	end
	return GateService.isUp(plot.index)
end

local function bars(baseIndex: number): Folder?
	local street = workspace:FindFirstChild("Street")
	local folder = street and street:FindFirstChild("Bases")
	local base = folder and folder:FindFirstChild(`Base{baseIndex}`)
	local found = base and base:FindFirstChild("GateBars")
	return if found and found:IsA("Folder") then found else nil
end

local function lamp(baseIndex: number): BasePart?
	local street = workspace:FindFirstChild("Street")
	local folder = street and street:FindFirstChild("Bases")
	local base = folder and folder:FindFirstChild(`Base{baseIndex}`)
	local found = base and base:FindFirstChild("GateLamp")
	return if found and found:IsA("BasePart") then found else nil
end

--- Shows or hides one base's lasers.
local function paint(baseIndex: number, up: boolean)
	local folder = bars(baseIndex)
	if folder then
		for _, bar in folder:GetChildren() do
			if bar:IsA("BasePart") then
				bar.Transparency = if up then 0.15 else 1
			end
		end
	end

	-- The lamp is the part you can read from your own base while standing at
	-- the button: lit means armed, dark means recharging. A player needs to
	-- know whether their defence is available BEFORE somebody walks in.
	local light = lamp(baseIndex)
	if light then
		local state = GateRules.state(raisedAt[baseIndex], os.clock(), CONFIG)
		light.Color = if up
			then Style.PALETTE.nomPink
			elseif state.ready then Style.PALETTE.nomMint
			else Style.PALETTE.nomCocoa
		light.Material = if state.ready or up then Enum.Material.Neon else Enum.Material.Slate
	end
end

--- Tells every client which bases are gated, so a thief can see a locked base
--- from the road rather than discovering it by being refused.
local function push()
	local remote = Net.get("GateSync") :: RemoteEvent
	local payload: { [string]: boolean } = {}
	for index = 1, World.BASE_COUNT do
		payload[tostring(index)] = GateService.isUp(index)
	end
	remote:FireAllClients(payload)
end

--- Raises the gate over `player`'s own base. Returns ok, reason.
---
--- Every check is here rather than at the caller, because there are two ways
--- in -- the button in the world and the HUD button -- and a rule enforced in
--- one of them is not a rule.
function GateService.raise(player: Player): (boolean, string?)
	if not NetService.allow(player, "RaiseGate") then
		return false, "One at a time!"
	end

	local plot = PlotService.plotFor(player)
	if not plot then
		return false, "You do not have a base yet."
	end

	-- PROXIMITY, server-side. Defending has to mean being home, or it is a
	-- button you press from across the street while robbing somebody else.
	-- Measured flat: the beam and the awning make the vertical distance
	-- meaningless, and a player standing on their own pedestal is not far away.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "Get back to your base first!"
	end
	local bx, bz = World.baseCenter(plot.index)
	local flat = Vector2.new(root.Position.X - bx, root.Position.Z - bz).Magnitude
	if flat > World.BASE_WIDTH / 2 + Snatch.GATE_RANGE then
		return false, "Get back to your base first!"
	end

	local ok, reason = GateRules.canRaise(raisedAt[plot.index], os.clock(), CONFIG)
	if not ok then
		return false, reason
	end

	raisedAt[plot.index] = os.clock()
	paint(plot.index, true)
	push()

	AnalyticsService.report(player, "gate_raised", 1, { base_index = plot.index })

	local notify = Net.get("Notify") :: RemoteEvent
	notify:FireClient(player, `🔒 Laser Gate up for {Snatch.GATE_SECONDS}s!`)
	FeedbackService.fire(player, "purchase", root.Position, nil)
	return true, nil
end

--- Drops a base's gate and clears its cooldown. Called when the plot changes
--- hands, so nobody inherits somebody else's defence or somebody else's wait.
function GateService.clear(baseIndex: number)
	raisedAt[baseIndex] = nil
	broadcast[baseIndex] = nil
	paint(baseIndex, false)
	push()
end

function GateService.init()
	local remote = Net.get("RaiseGate") :: RemoteFunction
	remote.OnServerInvoke = function(player)
		return GateService.raise(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local plot = PlotService.plotFor(player)
		if plot then
			GateService.clear(plot.index)
		end
	end)
end

function GateService.start()
	-- The button in the world. A ProximityPrompt fires SERVER-side, so this is
	-- the same trusted path as the remote -- and its return value goes nowhere,
	-- which is why the refusal has to be pushed to the player explicitly.
	for index = 1, World.BASE_COUNT do
		local street = workspace:WaitForChild("Street", 20)
		local folder = street and street:FindFirstChild("Bases")
		local base = folder and folder:FindFirstChild(`Base{index}`)
		local button = base and base:FindFirstChild("GateButton")
		if not button or not button:IsA("BasePart") then
			continue
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RaiseGate"
		prompt.ActionText = "Laser Gate"
		prompt.ObjectText = "Your base"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = button

		prompt.Triggered:Connect(function(player)
			local ok, reason = GateService.raise(player)
			if not ok and reason then
				local notify = Net.get("Notify") :: RemoteEvent
				notify:FireClient(player, reason)
			end
		end)

		paint(index, false)
	end

	-- One loop for every base. A gate drops on its own after GATE_SECONDS and
	-- the lamp turns from recharging to armed at the cooldown, and neither is
	-- an event anything fires -- they are both just a time passing.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			local changed = false
			for index = 1, World.BASE_COUNT do
				local up = GateRules.isUp(raisedAt[index], now, CONFIG)
				if up ~= (broadcast[index] == true) then
					broadcast[index] = up
					paint(index, up)
					changed = true
				elseif not up then
					-- Still down, but the lamp may have just gone from
					-- recharging to armed. Cheap enough to repaint.
					paint(index, false)
				end
			end
			if changed then
				push()
			end
		end
	end)
end

return GateService
