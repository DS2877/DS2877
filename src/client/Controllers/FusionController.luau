--!strict
--[[
	The Fusion Kitchen's interface, and the reveal.

	THE REVEAL IS THE PRODUCT. Everything else in the game exists to bring a
	player here with two creatures they care about, and the two or three seconds
	after they tap Claim are the thing they will screenshot and the thing they
	will tell somebody about. It gets the whole screen.

	The beats, in order, because the order is the design:
	  1. The screen dims and the music ducks. Something is about to happen.
	  2. The creature's SILHOUETTE appears before its colours. Anticipation.
	  3. Colours resolve, confetti, the rarity banner slides in.
	  4. The NAME types itself out, one character at a time. This is the moment
	     -- the name is the proof that nobody has seen this creature before.
	  5. If it is a World First, a gold banner takes over and holds longer.

	The picker is deliberately plain by comparison. A player choosing two
	Nomlings is doing admin; a player watching a reveal is having the experience.
	Spending the visual budget evenly between them would waste it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local NomlingSpec = require(Shared:WaitForChild("Logic"):WaitForChild("NomlingSpec"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Style = require(Shared:WaitForChild("Style"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))
local JuiceController = require(script.Parent:WaitForChild("JuiceController"))
local ShopController = require(script.Parent:WaitForChild("ShopController"))

local FusionController = {}
FusionController.Name = "FusionController"

local player = Players.LocalPlayer
local snapshot: { [string]: any }? = nil

local gui: ScreenGui
local fuseButton: TextButton
local fuseLabel: TextLabel
local picker: Frame
local pickerList: ScrollingFrame
local pickerStatus: TextLabel
local confirmButton: TextButton

local reveal: Frame
local revealName: TextLabel
local revealRarity: TextLabel
local revealBanner: Frame
local revealBannerText: TextLabel
local globalBanner: Frame
local globalBannerText: TextLabel
local revealViewport: ViewportFrame
local revealCamera: Camera

local selected: { string } = {}

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

-- --- the reveal ------------------------------------------------------------

--- Builds the new creature inside a ViewportFrame, so the reveal shows the
--- actual thing the player now owns rather than an illustration of it.
local function showCreature(info: { [string]: any })
	revealViewport:ClearAllChildren()
	revealCamera = Instance.new("Camera")
	revealCamera.Parent = revealViewport
	revealViewport.CurrentCamera = revealCamera

	local species = Nomlings.BY_ID[`{info.snack}_{info.animal}`]
	local genome: NomlingSpec.Genome = {
		snack = info.snack,
		animal = info.animal,
		gen = info.gen or 2,
		mutation = info.mutation,
		seed = 0,
		archetype = if species then species.archetype else "quadruped_small",
	}
	local palette = (species and Style.SPECIES_PALETTE[species.palette])
		or Style.SPECIES_PALETTE.rice_salmon

	local model = Instance.new("Model")
	model.Name = "Reveal"
	local scale = 1.0

	for _, spec in NomlingSpec.build(genome) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Shape = if spec.shape == "ball"
			then Enum.PartType.Ball
			elseif spec.shape == "cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z) * scale
		part.CFrame = CFrame.new(spec.offset.x, spec.offset.y, spec.offset.z)
			* CFrame.Angles(math.rad(spec.tilt.x), math.rad(spec.tilt.y), math.rad(spec.tilt.z))
		part.Material = Enum.Material.SmoothPlastic
		-- Beat 2: the silhouette lands before the colours do. Everything starts
		-- near-black and resolves, which is a second of free anticipation.
		part.Color = Color3.fromRGB(28, 24, 30)
		part:SetAttribute(
			"FinalColor",
			(function()
				if spec.role == "eye" then
					return Style.EYE.white
				elseif spec.role == "pupil" then
					return Style.EYE.pupil
				elseif spec.role == "secondary" then
					return palette.secondary
				elseif spec.role == "snack" or spec.role == "accent" then
					return palette.snack
				end
				return palette.primary
			end)()
		)
		part.Parent = model
	end

	model.Parent = revealViewport

	-- Frame the creature and turn it slowly.
	local centre = Vector3.new(0, 2.4, 0)
	task.spawn(function()
		local t0 = os.clock()
		while revealViewport.Parent and reveal.Visible do
			local angle = (os.clock() - t0) * 0.9
			revealCamera.CFrame = CFrame.new(
				centre + Vector3.new(math.sin(angle) * 9, 2.6, math.cos(angle) * 9),
				centre
			)
			task.wait(1 / 30)
		end
	end)

	-- Beat 3: colours resolve.
	task.delay(0.55, function()
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				local final = part:GetAttribute("FinalColor")
				if typeof(final) == "Color3" then
					TweenService:Create(
						part,
						TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Color = final }
					):Play()
				end
			end
		end
	end)
end

--- Types a string out one character at a time.
local function typeOut(target: TextLabel, text: string, perCharacter: number)
	target.Text = ""
	task.spawn(function()
		for i = 1, #text do
			if not reveal.Visible then
				return
			end
			target.Text = string.sub(text, 1, i)
			task.wait(perCharacter)
		end
	end)
end

local function showReveal(info: { [string]: any })
	local rarity = Style.RARITY[info.rarity] or Style.RARITY.common

	reveal.Visible = true
	reveal.BackgroundTransparency = 1
	TweenService:Create(reveal, TweenInfo.new(0.3), { BackgroundTransparency = 0.12 }):Play()

	-- Beat 1: the music gets out of the way.
	AudioController.duck(4.5)
	AudioController.play("reveal")

	revealName.Text = ""
	revealRarity.Text = ""
	revealBanner.Visible = false

	showCreature(info)

	task.delay(1.05, function()
		if not reveal.Visible then
			return
		end
		revealRarity.Text = string.upper(rarity.label)
			.. (if info.upgraded then "  ▲ UPGRADED" else "")
		revealRarity.TextColor3 = rarity.color
		JuiceController.pop(revealRarity, 0.3)
		JuiceController.flash(rarity.color, 0.22)
	end)

	-- Beat 4: the name. Slow enough to read, which is the whole point -- nobody
	-- has seen this word before.
	task.delay(1.4, function()
		if not reveal.Visible then
			return
		end
		typeOut(revealName, tostring(info.name or "?"), 0.055)
	end)

	-- Beat 5: a World First takes over and holds longer.
	if info.worldFirst then
		task.delay(2.3, function()
			if not reveal.Visible then
				return
			end
			revealBanner.Visible = true
			revealBannerText.Text = "🏆 WORLD FIRST — nobody has ever made this"
			JuiceController.pop(revealBanner, 0.25)
			JuiceController.flash(Color3.fromRGB(255, 214, 110), 0.3)
		end)
	end

	local hold = if info.worldFirst then 6.5 else 4.5
	task.delay(hold, function()
		local fade = TweenService:Create(reveal, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			reveal.Visible = false
			revealViewport:ClearAllChildren()
		end)
		fade:Play()
	end)
end

-- --- the picker ------------------------------------------------------------

local function refreshPicker()
	local snap = snapshot
	pickerList:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = pickerList

	local roster = (snap and snap.roster) or {}
	if #roster < 2 then
		pickerStatus.Text = "You need two Nomlings to fuse. Buy one off the belt!"
		confirmButton.Visible = false
		return
	end

	for _, entry in roster do
		local rarity = Style.RARITY[entry.rarity] or Style.RARITY.common
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundColor3 = if table.find(selected, entry.id)
			then Style.PALETTE.nomMint
			else Style.PALETTE.nomCream
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextScaled = true
		row.TextColor3 = Style.PALETTE.ink
		row.Text = `  {entry.snack} {entry.animal}  ·  {rarity.label}`
			.. (if entry.mutation then `  ✨{entry.mutation}` else "")
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = pickerList
		corner(row, 10)

		local chip = Instance.new("Frame")
		chip.Size = UDim2.new(0, 6, 1, -12)
		chip.Position = UDim2.new(1, -14, 0, 6)
		chip.BackgroundColor3 = rarity.color
		chip.BorderSizePixel = 0
		chip.Parent = row
		corner(chip, 3)

		row.Activated:Connect(function()
			local at = table.find(selected, entry.id)
			if at then
				table.remove(selected, at)
			elseif #selected < 2 then
				table.insert(selected, entry.id)
			else
				-- Third tap replaces the first pick rather than doing nothing,
				-- which is what people expect and saves a deselect tap.
				table.remove(selected, 1)
				table.insert(selected, entry.id)
			end
			refreshPicker()
		end)
	end

	pickerList.CanvasSize = UDim2.new(0, 0, 0, #roster * 58 + 8)
	pickerStatus.Text = if #selected == 2
		then "Ready! Order matters — the first gives the snack."
		else `Pick two ({#selected}/2). Order matters.`
	confirmButton.Visible = #selected == 2
end

-- --- build -----------------------------------------------------------------

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Fusion"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The FUSE button lives in the HUD's bottom bar, so exactly one module
	-- decides the bottom-of-screen layout and the three buttons cannot collide.
	fuseButton, fuseLabel = BaseHudController.fuseButton()

	-- --- picker ---
	picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.5)
	picker.Size = UDim2.new(0.92, 0, 0.72, 0)
	picker.BackgroundColor3 = Style.PALETTE.plazaStone
	picker.BorderSizePixel = 0
	picker.Visible = false
	picker.ZIndex = 20
	picker.Parent = gui
	corner(picker, 20)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 44)
	title.Position = UDim2.new(0, 12, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Style.PALETTE.ink
	title.Text = "Fusion Kitchen"
	title.Parent = picker

	pickerStatus = Instance.new("TextLabel")
	pickerStatus.Size = UDim2.new(1, -24, 0, 26)
	pickerStatus.Position = UDim2.new(0, 12, 0, 54)
	pickerStatus.BackgroundTransparency = 1
	pickerStatus.Font = Enum.Font.GothamMedium
	pickerStatus.TextScaled = true
	pickerStatus.TextColor3 = Style.PALETTE.nomCocoa
	pickerStatus.Text = ""
	pickerStatus.Parent = picker

	pickerList = Instance.new("ScrollingFrame")
	pickerList.Size = UDim2.new(1, -24, 1, -168)
	pickerList.Position = UDim2.new(0, 12, 0, 86)
	pickerList.BackgroundTransparency = 1
	pickerList.BorderSizePixel = 0
	pickerList.ScrollBarThickness = 5
	pickerList.CanvasSize = UDim2.new()
	pickerList.Parent = picker

	confirmButton = Instance.new("TextButton")
	confirmButton.AnchorPoint = Vector2.new(0.5, 1)
	confirmButton.Position = UDim2.new(0.5, 0, 1, -14)
	confirmButton.Size = UDim2.new(1, -24, 0, 60)
	confirmButton.BackgroundColor3 = Style.PALETTE.nomOrange
	confirmButton.BorderSizePixel = 0
	confirmButton.Font = Enum.Font.FredokaOne
	confirmButton.TextScaled = true
	confirmButton.TextColor3 = Style.PALETTE.nomCream
	confirmButton.Text = "FUSE THEM!"
	confirmButton.Visible = false
	confirmButton.Parent = picker
	corner(confirmButton, 16)

	-- FUSION IS A PAID RANDOM ITEM. Roblox's own example of a "combination
	-- item" is synthesising two rare eggs for a better chance at a higher-quality
	-- result, which is exactly this -- so its outcome odds must be disclosed the
	-- same way an egg's are, behind a button carrying a descriptive word rather
	-- than a bare icon. docs/COMPLIANCE.md 2.
	local odds = Instance.new("TextButton")
	odds.Name = "Odds"
	odds.AnchorPoint = Vector2.new(1, 0)
	odds.Position = UDim2.new(1, -64, 0, 16)
	odds.Size = UDim2.fromOffset(74, 36)
	odds.BackgroundColor3 = Style.PALETTE.nomBlue
	odds.BorderSizePixel = 0
	odds.Font = Enum.Font.GothamBold
	odds.TextScaled = true
	odds.TextColor3 = Style.PALETTE.nomCream
	odds.Text = "Odds"
	odds.Parent = picker
	corner(odds, 10)
	odds.Activated:Connect(function()
		ShopController.showFusionOdds()
	end)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = Style.PALETTE.shadow
	close.BorderSizePixel = 0
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Style.PALETTE.ink
	close.Text = "✕"
	close.Parent = picker
	corner(close, 22)
	close.Activated:Connect(function()
		picker.Visible = false
	end)

	-- --- reveal ---
	reveal = Instance.new("Frame")
	reveal.Name = "Reveal"
	reveal.Size = UDim2.fromScale(1, 1)
	reveal.BackgroundColor3 = Color3.fromRGB(12, 10, 16)
	reveal.BackgroundTransparency = 1
	reveal.BorderSizePixel = 0
	reveal.Visible = false
	reveal.ZIndex = 60
	reveal.Parent = gui

	revealViewport = Instance.new("ViewportFrame")
	revealViewport.AnchorPoint = Vector2.new(0.5, 0.5)
	revealViewport.Position = UDim2.fromScale(0.5, 0.42)
	revealViewport.Size = UDim2.new(0.8, 0, 0.46, 0)
	revealViewport.BackgroundTransparency = 1
	revealViewport.Ambient = Color3.fromRGB(190, 186, 200)
	revealViewport.LightColor = Color3.fromRGB(255, 248, 232)
	revealViewport.Parent = reveal

	revealRarity = Instance.new("TextLabel")
	revealRarity.AnchorPoint = Vector2.new(0.5, 0)
	revealRarity.Position = UDim2.fromScale(0.5, 0.68)
	revealRarity.Size = UDim2.new(0.8, 0, 0, 34)
	revealRarity.BackgroundTransparency = 1
	revealRarity.Font = Enum.Font.GothamBlack
	revealRarity.TextScaled = true
	revealRarity.TextColor3 = Style.PALETTE.nomCream
	revealRarity.Text = ""
	revealRarity.Parent = reveal

	revealName = Instance.new("TextLabel")
	revealName.AnchorPoint = Vector2.new(0.5, 0)
	revealName.Position = UDim2.fromScale(0.5, 0.74)
	revealName.Size = UDim2.new(0.92, 0, 0, 72)
	revealName.BackgroundTransparency = 1
	revealName.Font = Enum.Font.FredokaOne
	revealName.TextScaled = true
	revealName.TextColor3 = Style.PALETTE.nomCream
	revealName.Text = ""
	revealName.Parent = reveal

	revealBanner = Instance.new("Frame")
	revealBanner.AnchorPoint = Vector2.new(0.5, 0)
	revealBanner.Position = UDim2.fromScale(0.5, 0.86)
	revealBanner.Size = UDim2.new(0.94, 0, 0, 52)
	revealBanner.BackgroundColor3 = Color3.fromRGB(255, 206, 92)
	revealBanner.BorderSizePixel = 0
	revealBanner.Visible = false
	revealBanner.Parent = reveal
	corner(revealBanner, 14)

	revealBannerText = Instance.new("TextLabel")
	revealBannerText.Size = UDim2.new(1, -16, 1, -10)
	revealBannerText.Position = UDim2.new(0, 8, 0, 5)
	revealBannerText.BackgroundTransparency = 1
	revealBannerText.Font = Enum.Font.GothamBlack
	revealBannerText.TextScaled = true
	revealBannerText.TextColor3 = Color3.fromRGB(64, 38, 6)
	revealBannerText.Text = ""
	revealBannerText.Parent = revealBanner

	-- The server-wide World First banner. It sweeps in from the top for
	-- EVERYONE, including people who had nothing to do with it -- that is the
	-- point. Seeing somebody else discover a creature is what makes the space
	-- feel unexplored, and it is the cheapest viral loop in the game.
	globalBanner = Instance.new("Frame")
	globalBanner.Name = "WorldFirstBanner"
	globalBanner.AnchorPoint = Vector2.new(0.5, 0)
	globalBanner.Position = UDim2.new(0.5, 0, 0, -70)
	globalBanner.Size = UDim2.new(0.96, 0, 0, 58)
	globalBanner.BackgroundColor3 = Color3.fromRGB(255, 206, 92)
	globalBanner.BorderSizePixel = 0
	globalBanner.ZIndex = 40
	globalBanner.Parent = gui
	corner(globalBanner, 16)

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 160)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 198, 76)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 232, 160)),
	})
	shine.Parent = globalBanner

	globalBannerText = Instance.new("TextLabel")
	globalBannerText.Size = UDim2.new(1, -20, 1, -10)
	globalBannerText.Position = UDim2.new(0, 10, 0, 5)
	globalBannerText.BackgroundTransparency = 1
	globalBannerText.Font = Enum.Font.GothamBlack
	globalBannerText.TextScaled = true
	globalBannerText.TextColor3 = Color3.fromRGB(64, 38, 6)
	globalBannerText.Text = ""
	globalBannerText.Parent = globalBanner
end

local function showWorldFirst(info: { [string]: any })
	local who = tostring(info.displayName or "A Nomling Scientist")
	local name = tostring(info.name or "?")
	globalBannerText.Text = `🏆 WORLD FIRST — {who} made {name}`

	-- Slides in, holds, slides out. Never blocks input: it is news, not a modal.
	globalBanner.Position = UDim2.new(0.5, 0, 0, -70)
	TweenService:Create(
		globalBanner,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 74) }
	):Play()

	task.delay(5, function()
		TweenService:Create(
			globalBanner,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -70) }
		):Play()
	end)
end

-- --- wiring ----------------------------------------------------------------

local function labState(): (string, boolean)
	local snap = snapshot
	local fusion = snap and snap.fusion
	if not fusion then
		return "🧪 FUSE", false
	end
	local now = (snap.now or os.time()) + (os.clock() - (snap.at or os.clock()))
	local remaining = math.max(0, (fusion.readyAt or 0) - now)
	if remaining <= 0 then
		return "✨ CLAIM!", true
	end
	return `🧪 {math.ceil(remaining)}s`, false
end

function FusionController.start()
	build()

	fuseButton.Activated:Connect(function()
		local _, ready = labState()
		local snap = snapshot
		if ready then
			local remote = Net.get("ClaimFusion") :: RemoteFunction
			local ok, reason = remote:InvokeServer()
			if not ok and reason then
				pickerStatus.Text = reason
			end
			return
		end
		if snap and snap.fusion then
			-- Busy: tapping it should say so rather than opening a picker that
			-- cannot be used.
			JuiceController.pop(fuseButton, 0.1)
			return
		end
		selected = {}
		picker.Visible = true
		refreshPicker()
	end)

	confirmButton.Activated:Connect(function()
		if #selected < 2 then
			return
		end
		local remote = Net.get("StartFusion") :: RemoteFunction
		local ok, reason = remote:InvokeServer(selected[1], selected[2])
		if ok then
			picker.Visible = false
			selected = {}
			JuiceController.pop(fuseButton, 0.2)
		elseif reason then
			pickerStatus.Text = reason
		end
	end)

	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		snap.at = os.clock()
		snapshot = snap
		if picker.Visible then
			refreshPicker()
		end
	end)

	local revealRemote = Net.get("FusionReveal") :: RemoteEvent
	revealRemote.OnClientEvent:Connect(function(info)
		if type(info) == "table" then
			local ok, err = pcall(showReveal, info)
			if not ok then
				warn(`[FusionController] reveal failed: {err}`)
			end
		end
	end)

	local worldFirst = Net.get("WorldFirst") :: RemoteEvent
	worldFirst.OnClientEvent:Connect(function(info)
		if type(info) == "table" then
			local ok, err = pcall(showWorldFirst, info)
			if not ok then
				warn(`[FusionController] world-first banner failed: {err}`)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local text = labState()
			fuseLabel.Text = text
		end
	end)
end

return FusionController
