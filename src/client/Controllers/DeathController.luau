--!strict
--[[
	The death screen: the whole view desaturates, and WASTED fades up in red.

	Asked for directly: "When you die I want something exactly similar to when
	you do it in gta. wasted in red on the screen and a sound."

	⚠️ ONE THING FOR PHILIP TO DECIDE, recorded rather than quietly softened.
	The game is aimed at the Roblox Kids tier, and everything else in it avoids
	the language of dying on purpose -- the PvP is "friendly snatchers", and the
	CI content gate rejects the whole violent vocabulary in any player-facing
	string. (It rejected the first draft of THIS comment, which listed a few of
	those words as examples. The gate cannot tell a comment from a label, which
	is the right way round for it to be wrong.)

	WASTED is a quotation from an 18-rated game, and it is the one place the
	project points at that register. It trips no automated rule and will not
	fail a review on its own; it is a tone choice, and it is Philip's to make.
	See docs/DECISIONS.md D-026.

	HOW IT IS DONE. A ColorCorrection on Lighting drains the colour out of the
	world, which is most of what makes the GTA screen read the way it does --
	the red word alone on a normal-looking street is just text. Both the grade
	and the text fade, because an instant cut reads as a bug and a fade reads as
	a moment.

	IT CLEANS UP AFTER ITSELF, and that matters more than it sounds: a
	ColorCorrection left on Lighting after a respawn would leave the whole game
	grey for the rest of the session with nothing on screen to explain it.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AudioController = require(script.Parent:WaitForChild("AudioController"))

local DeathController = {}
DeathController.Name = "DeathController"

local player = Players.LocalPlayer

local FADE_IN = 0.45
local FADE_OUT = 0.35

local screen: ScreenGui
local shade: Frame
local word: TextLabel
local grade: ColorCorrectionEffect

local showing = false

local function fadeTo(transparency: number, textTransparency: number, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(shade, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(word, info, {
		TextTransparency = textTransparency,
		TextStrokeTransparency = math.min(1, textTransparency + 0.35),
	}):Play()
end

local function show()
	if showing then
		return
	end
	showing = true

	screen.Enabled = true
	shade.BackgroundTransparency = 1
	word.TextTransparency = 1
	word.TextStrokeTransparency = 1
	-- Starts slightly large and settles. The word arriving rather than simply
	-- being there is the whole effect.
	word.Size = UDim2.fromScale(1.15, 0.26)

	fadeTo(0.35, 0, FADE_IN)
	TweenService:Create(
		word,
		TweenInfo.new(FADE_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.94, 0.22) }
	):Play()
	TweenService:Create(
		grade,
		TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Saturation = -0.85, Contrast = 0.18, Brightness = -0.06 }
	):Play()

	-- The existing deny cue, pitched down hard. Not ideal and not pretending to
	-- be: a proper sting is a ninth audio upload, and the monthly quota on a
	-- non-ID-verified account is ten. Philip can spend one on this whenever he
	-- decides the screen is staying.
	AudioController.play("deny")
	AudioController.duck(2)
end

local function hide()
	if not showing then
		return
	end
	showing = false

	fadeTo(1, 1, FADE_OUT)
	TweenService:Create(
		grade,
		TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Saturation = 0, Contrast = 0, Brightness = 0 }
	):Play()

	task.delay(FADE_OUT + 0.05, function()
		if not showing then
			screen.Enabled = false
		end
	end)
end

local function watch(character: Model)
	-- Hide first: a respawn is the only reliable "you are alive again" signal,
	-- and it arrives before the new Humanoid is findable.
	hide()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(show)
end

function DeathController.start()
	screen = Instance.new("ScreenGui")
	screen.Name = "Death"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	-- Above the HUD but below the fault reporter, which must stay readable
	-- through anything.
	screen.DisplayOrder = 500
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(12, 6, 8)
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	-- Never swallows a tap. The respawn button is Roblox's own and it has to
	-- stay pressable through this.
	shade.Active = false
	shade.Parent = screen

	word = Instance.new("TextLabel")
	word.Name = "Wasted"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.5)
	word.Size = UDim2.fromScale(0.94, 0.22)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.GothamBlack
	word.TextScaled = true
	word.TextColor3 = Color3.fromRGB(196, 22, 28)
	word.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	word.TextStrokeTransparency = 1
	word.TextTransparency = 1
	word.Text = "WASTED"
	word.Active = false
	word.Parent = screen

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DeathGrade"
	-- Neutral until it is needed, so this is invisible on a living player even
	-- though it is always parented.
	grade.Saturation = 0
	grade.Contrast = 0
	grade.Brightness = 0
	grade.Parent = Lighting

	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return DeathController
