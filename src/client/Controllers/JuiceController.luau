--!strict
--[[
	Game feel: the pops, bursts, shakes and flying coins.

	None of this changes what the game does. All of it changes whether the game
	feels expensive, and it is the cheapest quality-per-line work available --
	a purchase that answers with a burst, a sound and a number that punches
	reads as a different product from one that silently increments a label.

	FOUR RULES, and they are why this reads as polish rather than as noise:

	1. EVERY PLAYER ACTION GETS AN ANSWER inside 100 ms. Buying, hatching,
	   snatching, being snatched from.
	2. NOTHING BLOCKS. Every effect is fire-and-forget; a dropped cue costs a
	   sparkle, never a state change.
	3. EFFECTS ARE BUDGETED. Particles are capped and pooled, shake is clamped,
	   and coin flights collapse when many arrive at once -- 150 creatures each
	   throwing a coin per second would otherwise be 150 tweens per second.
	4. IT SCALES WITH THE EVENT. A common Nomling gets a small pop; a mutated
	   mythic gets the screen flash. If everything is loud, nothing is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local JuiceController = {}
JuiceController.Name = "JuiceController"

local player = Players.LocalPlayer
local rng = Random.new()

local screen: ScreenGui
local flash: Frame
--- Where flying coins land. Set by the HUD once it exists.
local purseTarget: GuiObject? = nil

--- Caps. A phone has a particle budget and this is where it is spent.
local MAX_COIN_FLIGHTS = 8
local MAX_SHAKE = 1.2
local activeFlights = 0

local shakeAmount = 0
local shakeDecay = 0

-- --- UI feel ---------------------------------------------------------------

--- A scale punch. Overshoot then settle: the overshoot is what makes it read as
--- a physical object rather than an animation.
function JuiceController.pop(target: GuiObject, strength: number?)
	local amount = strength or 0.18
	local base = target:GetAttribute("JuiceBaseSize")
	if typeof(base) ~= "UDim2" then
		base = target.Size
		target:SetAttribute("JuiceBaseSize", base)
	end
	local grown = UDim2.new(
		base.X.Scale * (1 + amount),
		base.X.Offset * (1 + amount),
		base.Y.Scale * (1 + amount),
		base.Y.Offset * (1 + amount)
	)
	target.Size = grown
	TweenService:Create(
		target,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = base }
	):Play()
end

--- A brief full-screen tint. Reserved for genuinely rare events.
function JuiceController.flash(colour: Color3, strength: number?)
	flash.BackgroundColor3 = colour
	flash.BackgroundTransparency = 1 - (strength or 0.35)
	flash.Visible = true
	TweenService:Create(
		flash,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

function JuiceController.setPurseTarget(target: GuiObject)
	purseTarget = target
end

--- A coin that flies from a world position into the purse. Collapses silently
--- once the cap is reached rather than queueing -- a backlog of coin tweens is
--- worse than a missing coin.
function JuiceController.flyCoin(worldPosition: Vector3)
	local target = purseTarget
	local camera = Workspace.CurrentCamera
	if not target or not camera or activeFlights >= MAX_COIN_FLIGHTS then
		return
	end

	local point, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen then
		return
	end

	activeFlights += 1
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromOffset(point.X, point.Y)
	coin.Size = UDim2.fromOffset(16, 16)
	coin.BackgroundColor3 = Color3.fromRGB(255, 208, 92)
	coin.BorderSizePixel = 0
	coin.ZIndex = 50
	coin.Parent = screen

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = coin

	local destination = target.AbsolutePosition + target.AbsoluteSize / 2
	local tween = TweenService:Create(
		coin,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromOffset(destination.X, destination.Y),
			Size = UDim2.fromOffset(8, 8),
		}
	)
	tween.Completed:Connect(function()
		coin:Destroy()
		activeFlights -= 1
		if purseTarget then
			JuiceController.pop(purseTarget, 0.08)
		end
	end)
	tween:Play()
end

-- --- world feel ------------------------------------------------------------

--- A one-shot particle burst at a world position. The emitter destroys itself,
--- so nothing accumulates.
function JuiceController.burst(worldPosition: Vector3, colour: Color3, count: number)
	local origin = Instance.new("Part")
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.Size = Vector3.new(0.2, 0.2, 0.2)
	origin.CFrame = CFrame.new(worldPosition)
	origin.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.45, 0.9)
	emitter.Speed = NumberRange.new(9, 17)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 0.7
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.Parent = origin
	emitter:Emit(math.clamp(count, 1, 40))

	task.delay(1.4, function()
		origin:Destroy()
	end)
end

--- Camera shake. Clamped, and it decays rather than stopping abruptly.
function JuiceController.shake(strength: number, seconds: number?)
	shakeAmount = math.min(MAX_SHAKE, shakeAmount + strength)
	shakeDecay = shakeAmount / math.max(0.1, seconds or 0.45)
end

-- --- cues ------------------------------------------------------------------
-- The server names an event; this decides how loud it is. Scaling by rarity is
-- what keeps the loud effects meaningful.

local RARITY_WEIGHT: { [string]: number } = {
	common = 0.2,
	uncommon = 0.32,
	rare = 0.5,
	epic = 0.68,
	legendary = 0.84,
	mythic = 1.0,
	secret = 1.0,
}

local function cueColour(rarity: string?): Color3
	local spec = rarity and Style.RARITY[rarity]
	return (spec and spec.color) or Style.PALETTE.nomOrange
end

local function handle(kind: string, position: Vector3?, extra: { [string]: any }?)
	local info = extra or {}
	local rarity = if type(info.rarity) == "string" then info.rarity else nil
	local weight = RARITY_WEIGHT[rarity or "common"] or 0.2
	local colour = cueColour(rarity)
	local mutated = type(info.mutation) == "string" and #info.mutation > 0

	if kind == "coin" and position then
		JuiceController.flyCoin(position)
	elseif kind == "purchase" and position then
		JuiceController.burst(position, colour, 10 + math.floor(weight * 18))
		JuiceController.shake(0.06 + weight * 0.14, 0.3)
	elseif kind == "hatch" and position then
		JuiceController.burst(position, colour, 14 + math.floor(weight * 24))
		JuiceController.shake(0.1 + weight * 0.25, 0.4)
		-- The screen flash is reserved: only a genuinely rare creature, or any
		-- mutation, earns it. If everything flashes, nothing does.
		if weight >= 0.68 or mutated then
			JuiceController.flash(colour, 0.2 + weight * 0.3)
		end
	elseif kind == "snatched" then
		-- Being robbed. The loudest cue in the game, because it is the one the
		-- player most needs to notice immediately.
		JuiceController.shake(0.9, 0.7)
		JuiceController.flash(Style.PALETTE.nomPink, 0.3)
	elseif kind == "grab" and position then
		JuiceController.burst(position, Style.PALETTE.nomPink, 14)
		JuiceController.shake(0.35, 0.4)
	elseif kind == "deny" then
		JuiceController.shake(0.12, 0.2)
	end
end

function JuiceController.start()
	screen = Instance.new("ScreenGui")
	screen.Name = "Juice"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 100
	flash.Visible = false
	-- Never swallows a tap: the flash covers the whole screen and the HUD
	-- lives under it.
	flash.Active = false
	flash.Parent = screen

	local remote = Net.get("Feedback") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind, position, extra)
		if type(kind) ~= "string" then
			return
		end
		local ok, err = pcall(handle, kind, position, extra)
		if not ok then
			warn(`[JuiceController] cue '{kind}' failed: {err}`)
		end
	end)

	-- Shake is applied after Roblox's own camera script has run, so it offsets
	-- the final camera rather than fighting it.
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, function(delta)
		if shakeAmount <= 0.001 then
			return
		end
		shakeAmount = math.max(0, shakeAmount - shakeDecay * delta)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local a = shakeAmount
		camera.CFrame = camera.CFrame
			* CFrame.new(rng:NextNumber(-a, a) * 0.5, rng:NextNumber(-a, a) * 0.5, 0)
			* CFrame.Angles(
				math.rad(rng:NextNumber(-a, a) * 0.6),
				math.rad(rng:NextNumber(-a, a) * 0.6),
				math.rad(rng:NextNumber(-a, a) * 0.4)
			)
	end)
end

return JuiceController
