--!strict
--[[
	What weather looks like.

	Three phases, and the middle one is the point: an incoming banner that gives
	the player fifteen seconds to run home and get their best creatures onto
	pedestals, because only what is placed can mutate.

	The visual is deliberately restrained. A weather event has to be READABLE --
	which event is it, how long is left -- and an effect strong enough to obscure
	the street would make the fifteen-second scramble harder rather than more
	exciting. So: a tint on the colour grade, a fall of particles from above the
	camera, and a banner with a countdown. Nothing that hides a thief.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))
local Weather = require(Shared:WaitForChild("Config"):WaitForChild("Weather"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))
local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local WeatherController = {}
WeatherController.Name = "WeatherController"

local player = Players.LocalPlayer
--- Off the top of its slot, and filling it. Named so the two tweens and the
--- initial state cannot drift apart.
local HIDDEN = UDim2.new(0.5, 0, 0, -80)
local SHOWN = UDim2.new(0.5, 0, 0, 0)

local banner: Frame
local bannerText: TextLabel
local emitterPart: Part? = nil
local endsAt = 0
local activeLabel = ""

local function rgb(triplet: { number }): Color3
	return Color3.fromRGB(triplet[1], triplet[2], triplet[3])
end

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function showBanner(text: string, colour: Color3)
	bannerText.Text = text
	banner.BackgroundColor3 = colour
	banner.Position = HIDDEN
	banner.Visible = true
	TweenService:Create(
		banner,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = SHOWN }
	):Play()
end

local function hideBanner()
	local tween = TweenService:Create(
		banner,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = HIDDEN }
	)
	tween.Completed:Connect(function()
		banner.Visible = false
	end)
	tween:Play()
end

--- Particles fall from a plane above the camera and follow it, so the effect is
--- everywhere the player looks without emitting across the whole street.
local function startParticles(kind: Weather.Kind)
	if emitterPart then
		emitterPart:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "WeatherEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(90, 1, 90)
	part.Parent = Workspace
	emitterPart = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = kind.rate
	emitter.Lifetime = NumberRange.new(2.4, 3.6)
	emitter.Speed = NumberRange.new(14, 22)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Size = NumberSequence.new(0.42)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(rgb(kind.particle))
	emitter.LightEmission = 0.6
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	emitter.Parent = part

	task.spawn(function()
		while emitterPart == part and part.Parent do
			local camera = Workspace.CurrentCamera
			if camera then
				part.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 42, 0))
					* CFrame.Angles(math.rad(180), 0, 0)
			end
			task.wait(0.15)
		end
	end)
end

local function stopParticles()
	if emitterPart then
		local part = emitterPart
		emitterPart = nil
		local emitter = part:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Rate = 0
		end
		-- Let what is already falling finish rather than snapping it out.
		task.delay(4, function()
			part:Destroy()
		end)
	end
end

local function tintGrade(colour: Color3?)
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not grade then
		return
	end
	local target = colour or Color3.fromRGB(255, 249, 240)
	TweenService:Create(
		grade,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ TintColor = target }
	):Play()
end

local function handle(info: { [string]: any })
	local kind = Weather.KINDS[tostring(info.kind)]
	local label = tostring(info.label or "Weather")
	local colour = if kind then rgb(kind.tint) else Style.PALETTE.nomBlue

	if info.phase == "incoming" then
		-- The scramble. The banner says what to DO, not just what is happening.
		showBanner(
			`⛅ {label} in {math.ceil(tonumber(info.seconds) or 0)}s — put your best Nomlings out!`,
			colour
		)
		AudioController.play("purchase")
	elseif info.phase == "started" then
		activeLabel = label
		endsAt = os.clock() + (tonumber(info.seconds) or 0)
		local multiplier = tonumber(info.multiplier) or 1
		showBanner(`✨ {label} — ×{multiplier} coins!`, colour)
		tintGrade(colour)
		if kind then
			startParticles(kind)
		end
		AudioController.play("reveal")
		JuiceController.flash(colour, 0.2)
	elseif info.phase == "ended" then
		endsAt = 0
		activeLabel = ""
		hideBanner()
		tintGrade(nil)
		stopParticles()
	end
end

function WeatherController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Lives in the HUD's banner slot rather than at a hand-picked y, so it
	-- cannot land on the right-hand rail on a short screen.
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = HIDDEN
	banner.Size = UDim2.fromScale(1, 1)
	banner.BackgroundColor3 = Style.PALETTE.nomBlue
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.ZIndex = 30
	banner.Parent = BaseHudController.bannerSlot()
	corner(banner, 14)

	bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.new(1, -18, 1, -6)
	bannerText.Position = UDim2.new(0, 9, 0, 4)
	bannerText.BackgroundTransparency = 1
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextScaled = true
	bannerText.TextColor3 = Color3.fromRGB(54, 36, 18)
	bannerText.Text = ""
	bannerText.Parent = banner

	local remote = Net.get("Weather") :: RemoteEvent
	remote.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		local ok, err = pcall(handle, info)
		if not ok then
			warn(`[WeatherController] weather phase failed: {err}`)
		end
	end)

	-- A live countdown while an event runs, so the boost has a visible clock.
	task.spawn(function()
		while true do
			task.wait(1)
			if endsAt > 0 and banner.Visible then
				local left = math.max(0, math.ceil(endsAt - os.clock()))
				if left > 0 then
					bannerText.Text = `✨ {activeLabel} — {left}s left`
				end
			end
		end
	end)
end

return WeatherController
