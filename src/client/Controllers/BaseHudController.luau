--!strict
--[[
	The HUD: purse, income rate, incubators, the egg button, toasts.

	PHONE FIRST, and that shapes every choice here. Everything tappable is at
	least 44 px on its shortest side -- Apple's and Google's floor, and the
	number to argue with if these get smaller again -- and sits in the lower
	third, inside thumb reach. Nothing important goes near the top-right, where
	a right-handed player's thumb covers the screen when they reach for it. The
	purse is top-left because that is the one thing players glance at without
	tapping.

	SIZED DOWN after a phone playtest: "make the buttons smaller and the ui more
	ux friendly". The first pass used 58-72 px controls, which on a 390-point
	screen ate the bottom fifth and left the game visible through a letterbox.
	Chrome is not the game. Every control here is now as small as the 44 px
	floor allows, and every number below is in ONE place so the whole thing
	scales together rather than drifting apart again.

	Built from plain Instances rather than React-Lua. React-Lua is approved
	(docs/DECISIONS.md D-005) and is still the destination for the Fusion Book
	and the reveal, but a HUD that never changes shape does not need a
	reconciler, and high-frequency values -- the coin counter ticking every
	frame -- are exactly what D-005 says to keep out of the tree anyway.

	WHAT MAKES IT LOOK EXPENSIVE, since none of it is art assets:
	layered surfaces with a real shadow, gradients rather than flat fills, a
	type hierarchy with three weights, progress that animates instead of
	jumping, and a number that punches when it changes.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Snatch = require(Shared:WaitForChild("Config"):WaitForChild("Snatch"))
local HudLayout = require(Shared:WaitForChild("Logic"):WaitForChild("HudLayout"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local BaseHudController = {}
BaseHudController.Name = "BaseHudController"

-- Every number this file lays out with comes from HudLayout, which is pure and
-- therefore testable: tests/unit/hud.spec.luau checks that the bands do not
-- overlap, that nothing drops under the 44 pt touch floor and that the
-- furniture leaves the game most of the screen. Nothing here invents a
-- position, which is what let the last version put a banner under the Roblox
-- menu and a toast behind the bottom bar.
local TOUCH_MIN = HudLayout.TOUCH_MIN
local EDGE = HudLayout.EDGE
local GAP = HudLayout.GAP
local TOP_H = HudLayout.TOP_H
local TOP_Y = HudLayout.TOP_Y
local PURSE_W = HudLayout.PURSE_W
local RAIL_W = HudLayout.RAIL_W
local BAR_H = HudLayout.BAR_H
local BAR_MAX_W = HudLayout.BAR_MAX_W
local SLOT_H = HudLayout.SLOT_H
local SLOT_W = HudLayout.SLOT_W
local RAIL_TOP = HudLayout.RAIL_TOP
local BAR_TOP = HudLayout.BAR_TOP
local TOAST_H = HudLayout.TOAST_H
local TOAST_TOP = HudLayout.TOAST_TOP
local SPLIT = HudLayout.BAR_SPLIT

local player = Players.LocalPlayer
local snapshot: { [string]: any }? = nil
local displayedCoins = 0

local purse: Frame
local coinLabel: TextLabel
local rateLabel: TextLabel
local eggButton: TextButton
local eggLabel: TextLabel
local eggPrice: TextLabel
local fuseButton: TextButton
local fuseLabel: TextLabel
local bubbleButton: TextButton
local bubbleLabel: TextLabel
local renomButton: TextButton
local renomLabel: TextLabel
local rail: Frame
local objective: Frame
local bannerSlot: Frame
local confirm: Frame
local confirmText: TextLabel
local toast: Frame
local toastLabel: TextLabel
--- `ready` is remembered so the pulse fires once on the transition rather than
--- twenty times a second for as long as the egg sits unclaimed.
local slots: { { button: TextButton, label: TextLabel, fill: Frame, ready: boolean } } = {}

-- --- small builders --------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number)
	local line = Instance.new("UIStroke")
	line.Color = colour
	line.Thickness = thickness
	line.Transparency = transparency
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = parent
end

--- Depth, without geometry: a vertical gradient that MULTIPLIES the surface's
--- own colour, so it darkens toward the bottom edge the way a moulded plastic
--- button does while keeping its hue. The earlier version was an offset dark
--- frame behind the surface, which no longer works now that everything with
--- depth sits in a UIListLayout -- a sibling there becomes a layout cell.
local function depth(target: GuiObject)
	local grad = Instance.new("UIGradient")
	grad.Name = "Depth"
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.68, Color3.new(0.97, 0.96, 0.97)),
		ColorSequenceKeypoint.new(1, Color3.new(0.79, 0.75, 0.78)),
	})
	grad.Rotation = 90
	grad.Parent = target
	return grad
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	grad.Rotation = rotation or 90
	grad.Parent = parent
	return grad
end

--- Caps how large TextScaled is allowed to go. Without this a 50 px button
--- asks for 50 px type, and "FUSE" at 50 px is wider than a third of a phone
--- screen -- which is exactly how the E ended up hanging off the end.
local function cap(text: TextLabel, maxSize: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 8
	limit.Parent = text
end

--- Fills a button, inset on every side so no glyph ever touches the stroke.
local function buttonText(
	parent: GuiObject,
	font: Enum.Font,
	colour: Color3,
	maxSize: number
): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.new(1, -16, 1, -10)
	text.Position = UDim2.new(0, 8, 0, 5)
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextScaled = true
	text.TextColor3 = colour
	text.Text = ""
	text.ZIndex = parent.ZIndex + 1
	text.Parent = parent
	cap(text, maxSize)
	return text
end

local function label(parent: Instance, font: Enum.Font, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = size
	text.Position = position
	text.Font = font
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Style.PALETTE.ink
	text.Text = ""
	text.Parent = parent
	return text
end

-- --- toast -----------------------------------------------------------------

local toastToken = 0

local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toastLabel.TextTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(toastLabel, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
	JuiceController.pop(toast, 0.06)

	task.delay(2.6, function()
		if toastToken ~= token then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		local fade = TweenService:Create(toastLabel, TweenInfo.new(0.3), { TextTransparency = 1 })
		fade.Completed:Connect(function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
		fade:Play()
	end)
end

-- --- build -----------------------------------------------------------------

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BaseHud"
	gui.ResetOnSpawn = false
	-- CoreUISafeInsets, not DeviceSafeInsets. DeviceSafeInsets only dodges the
	-- notch; it does NOT reserve the Roblox top bar, so on a phone the objective
	-- banner rendered underneath the menu, chat and mic buttons and the purse
	-- lost its top edge. CoreUISafeInsets reserves both.
	-- docs/VERIFY.md: Enum.ScreenInsets, checked 2026-09-17.
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- --- the top row ---
	-- Same lesson the bottom bar already learnt, applied to the top edge: the
	-- purse and the objective banner were positioned independently and on a
	-- phone the banner covered the coin count. A row cannot overlap itself, and
	-- the row stops short of the rail so the round buttons have their own
	-- column. TutorialController parents its banner into `objective`.
	local topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.Position = UDim2.new(0, EDGE, 0, TOP_Y)
	topRow.Size = UDim2.new(1, -(EDGE * 2 + RAIL_W + GAP), 0, TOP_H)
	topRow.BackgroundTransparency = 1
	topRow.ZIndex = 4
	topRow.Parent = gui

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, GAP)
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Parent = topRow

	-- --- purse ---
	purse = Instance.new("Frame")
	purse.Name = "Purse"
	purse.LayoutOrder = 1
	purse.Size = UDim2.fromOffset(PURSE_W, TOP_H)
	purse.BackgroundColor3 = Style.PALETTE.nomCream
	purse.BorderSizePixel = 0
	purse.ZIndex = 5
	purse.Parent = topRow
	corner(purse, 14)
	gradient(purse, Color3.fromRGB(255, 252, 244), Color3.fromRGB(246, 232, 208))
	stroke(purse, Style.PALETTE.nomCocoa, 1.5, 0.72)

	local coinIcon = Instance.new("Frame")
	coinIcon.Name = "CoinIcon"
	coinIcon.Position = UDim2.new(0, 9, 0.5, -10)
	coinIcon.Size = UDim2.fromOffset(20, 20)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 206, 84)
	coinIcon.BorderSizePixel = 0
	coinIcon.ZIndex = 6
	coinIcon.Parent = purse
	corner(coinIcon, 10)
	stroke(coinIcon, Color3.fromRGB(214, 152, 40), 2, 0)

	coinLabel = label(purse, Enum.Font.FredokaOne, UDim2.new(1, -42, 0, 24), UDim2.new(0, 34, 0, 4))
	coinLabel.ZIndex = 6
	coinLabel.Text = "0"
	cap(coinLabel, 22)
	rateLabel =
		label(purse, Enum.Font.GothamMedium, UDim2.new(1, -42, 0, 14), UDim2.new(0, 34, 0, 28))
	rateLabel.ZIndex = 6
	rateLabel.TextColor3 = Style.PALETTE.nomCocoa
	rateLabel.Text = "0 / sec"
	cap(rateLabel, 13)

	-- The rest of the row. Empty until the tutorial fills it, and it collapses
	-- to nothing visible rather than leaving a hole.
	objective = Instance.new("Frame")
	objective.Name = "Objective"
	objective.LayoutOrder = 2
	objective.Size = UDim2.new(1, -(PURSE_W + GAP), 1, 0)
	objective.BackgroundTransparency = 1
	objective.ZIndex = 4
	objective.Parent = topRow

	-- A strip under the top row, same width, for anything that announces itself
	-- and then goes away. Nothing in here can reach the rail.
	bannerSlot = Instance.new("Frame")
	bannerSlot.Name = "BannerSlot"
	bannerSlot.Position = UDim2.new(0, EDGE, 0, RAIL_TOP)
	bannerSlot.Size = UDim2.new(1, -(EDGE * 2 + RAIL_W + GAP), 0, HudLayout.BANNER_H)
	bannerSlot.BackgroundTransparency = 1
	bannerSlot.ZIndex = 8
	bannerSlot.Parent = gui

	JuiceController.setPurseTarget(purse)

	-- --- incubator slots ---
	-- Docked directly on top of the bottom bar, not floating at a hand-picked
	-- offset. In the playtest screenshot "TAP TO HATCH!" sat alone in the middle
	-- of the screen with nothing under it, so it read as a stray label rather
	-- than as the thing you are meant to press.
	local tray = Instance.new("Frame")
	tray.Name = "Incubators"
	tray.AnchorPoint = Vector2.new(0.5, 1)
	tray.Position = UDim2.new(0.5, 0, 1, -(BAR_TOP + GAP))
	tray.Size = UDim2.new(
		0,
		SLOT_W * Economy.INCUBATORS_BASE + GAP * (Economy.INCUBATORS_BASE - 1),
		0,
		SLOT_H
	)
	tray.BackgroundTransparency = 1
	tray.ZIndex = 4
	tray.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = tray

	for i = 1, Economy.INCUBATORS_BASE do
		local button = Instance.new("TextButton")
		button.Name = `Slot{i}`
		button.Size = UDim2.new(0, SLOT_W, 0, SLOT_H)
		button.BackgroundColor3 = Style.PALETTE.nomMint
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Visible = false
		button.ZIndex = 4
		button.Parent = tray
		corner(button, 13)
		stroke(button, Style.PALETTE.nomCocoa, 1.5, 0.8)

		-- A progress fill behind the text, so a countdown is something you
		-- watch rather than something you read.
		local progress = Instance.new("Frame")
		progress.Name = "Fill"
		progress.Size = UDim2.new(0, 0, 1, 0)
		progress.BackgroundColor3 = Color3.fromRGB(150, 232, 206)
		progress.BorderSizePixel = 0
		progress.ZIndex = 3
		progress.Parent = button
		corner(progress, 13)

		local text = buttonText(button, Enum.Font.FredokaOne, Style.PALETTE.ink, 17)
		text.ZIndex = 5
		text.Text = "-"

		slots[i] = { button = button, label = text, fill = progress, ready = false }

		button.Activated:Connect(function()
			local remote = Net.get("ClaimHatch") :: RemoteFunction
			local ok, reason = remote:InvokeServer(i)
			if ok then
				JuiceController.pop(button, 0.22)
			elseif reason then
				showToast(reason)
			end
		end)
	end

	-- --- bottom bar ---
	-- Three buttons in ONE row with proportional widths. An earlier version
	-- anchored FUSE and Buy Egg to the bottom independently, and on a 390-point
	-- phone screen they overlapped -- a 320-wide centred button leaves 35 points
	-- either side and FUSE was 116 wide at x=14. A row cannot do that at any
	-- width, which is the point of using one.
	local bar = Instance.new("Frame")
	bar.Name = "BottomBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -EDGE)
	bar.Size = UDim2.new(1, -(EDGE * 2 + 4), 0, BAR_H)
	bar.BackgroundTransparency = 1
	bar.ZIndex = 4
	bar.Parent = gui

	-- A row of three stretched across an iPad is a worse row of three. Cap it
	-- and let it centre.
	local barWidth = Instance.new("UISizeConstraint")
	barWidth.MaxSize = Vector2.new(BAR_MAX_W, math.huge)
	barWidth.Parent = bar

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, GAP)
	barLayout.Parent = bar

	local function barButton(name: string, widthScale: number, colour: Color3): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		-- Scale widths minus the gaps, so the row always fits exactly.
		button.Size = UDim2.new(widthScale, -6, 1, 0)
		button.BackgroundColor3 = colour
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.ZIndex = 4
		button.Parent = bar
		corner(button, 14)
		stroke(button, Style.PALETTE.nomCocoa, 1.5, 0.6)
		depth(button)
		return button
	end

	-- NO EMOJI on these three. "🧪 FUSE" at TextScaled in a 72 px button asked
	-- for type wider than the button and the E hung off the end, and the bubble
	-- button was blank on a real phone because U+1FAE7 is Emoji 14.0 and
	-- Roblox's font fallback does not carry it. tools/validate-kid-safe.py now
	-- fails the build on any emoji that is not on the known-good list.
	fuseButton = barButton("Fuse", SPLIT.fuse, Style.PALETTE.nomMint)
	fuseLabel = buttonText(fuseButton, Enum.Font.FredokaOne, Style.PALETTE.ink, 20)
	fuseLabel.Text = "FUSE"

	eggButton = barButton("BuyEgg", SPLIT.egg, Style.PALETTE.nomOrange)
	eggLabel =
		label(eggButton, Enum.Font.FredokaOne, UDim2.new(1, -16, 0, 21), UDim2.new(0, 8, 0, 5))
	eggLabel.TextXAlignment = Enum.TextXAlignment.Center
	eggLabel.TextColor3 = Style.PALETTE.nomCream
	eggLabel.ZIndex = 5
	eggLabel.Text = "Buy Egg"
	cap(eggLabel, 19)
	eggPrice =
		label(eggButton, Enum.Font.GothamBold, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 27))
	eggPrice.TextXAlignment = Enum.TextXAlignment.Center
	eggPrice.TextColor3 = Color3.fromRGB(255, 240, 220)
	eggPrice.ZIndex = 5
	eggPrice.Text = ""
	cap(eggPrice, 16)

	bubbleButton = barButton("Bubble", SPLIT.bubble, Style.PALETTE.nomBlue)
	-- The bubble is DRAWN, not typed. A circle always renders; a 2021 emoji
	-- does not.
	local bubbleGlyph = Instance.new("Frame")
	bubbleGlyph.Name = "Bubble"
	bubbleGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	bubbleGlyph.Position = UDim2.fromScale(0.5, 0.5)
	bubbleGlyph.Size = UDim2.fromOffset(BAR_H - 16, BAR_H - 16)
	bubbleGlyph.BackgroundColor3 = Color3.fromRGB(226, 244, 255)
	bubbleGlyph.BackgroundTransparency = 0.45
	bubbleGlyph.BorderSizePixel = 0
	bubbleGlyph.ZIndex = 4
	bubbleGlyph.Parent = bubbleButton
	corner(bubbleGlyph, (BAR_H - 16) // 2)
	stroke(bubbleGlyph, Color3.fromRGB(255, 255, 255), 2, 0.3)

	bubbleLabel = buttonText(bubbleButton, Enum.Font.FredokaOne, Style.PALETTE.nomCream, 18)
	bubbleLabel.ZIndex = 5
	bubbleLabel.Text = "SAVE IT!"

	-- HIDDEN UNTIL THERE IS SOMETHING TO SAVE. From a playtest: "the save
	-- button I don't even know what the function is for." It was permanently
	-- on the bar doing nothing, which is the worst way to teach a mechanic --
	-- a button you have pressed ten times to no effect is one you stop
	-- believing in. It now appears only while a thief is actually running off
	-- with something near you, which makes it self-explanatory: it shows up at
	-- the exact moment it means "press this".
	bubbleButton.Visible = false

	eggButton.Activated:Connect(function()
		-- Buys the best tier this player has unlocked. Wiring this to "basic"
		-- made five of the six egg tiers unreachable from the UI no matter how
		-- many times somebody re-nommed.
		local snap = snapshot
		local tier = (snap and snap.bestEgg) or "basic"
		local remote = Net.get("BuyEgg") :: RemoteFunction
		local ok, reason = remote:InvokeServer(tier)
		if ok then
			JuiceController.pop(eggButton, 0.14)
		elseif reason then
			showToast(reason)
		end
	end)

	bubbleButton.Activated:Connect(function()
		local remote = Net.get("Bubble") :: RemoteFunction
		local ok, reason = remote:InvokeServer()
		if ok then
			JuiceController.pop(bubbleButton, 0.24)
		elseif reason then
			showToast(reason)
		end
	end)

	-- --- the right-hand rail ---
	-- Four controllers want a round button down the right edge, and positioning
	-- them independently is the same mistake the bottom bar already made: on a
	-- short screen (landscape on a small phone) the stack would run into the
	-- bottom bar. A list layout cannot collide, so one module owns the rail and
	-- hands out slots.
	-- Starts below the top row and stops above the tray, so the "?" can never
	-- land on the objective banner the way it did in the playtest screenshot.
	rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(1, 0)
	rail.Position = UDim2.new(1, -EDGE, 0, RAIL_TOP)
	rail.Size = UDim2.new(0, RAIL_W, 1, -(RAIL_TOP + HudLayout.RAIL_BOTTOM))
	rail.BackgroundTransparency = 1
	rail.ZIndex = 5
	rail.Parent = gui

	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	railLayout.Padding = UDim.new(0, HudLayout.RAIL_GAP)
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Parent = rail

	-- --- Re-Nom ---
	-- Hidden until affordable. A permanently greyed button for a milestone
	-- hours away is clutter; one that appears the moment you can afford it is
	-- an event.
	renomButton = BaseHudController.railButton("ReNom", 20, Color3.fromRGB(196, 132, 240))
	renomButton.Visible = false

	renomLabel = Instance.new("TextLabel")
	renomLabel.Size = UDim2.fromScale(1, 1)
	renomLabel.BackgroundTransparency = 1
	renomLabel.Font = Enum.Font.FredokaOne
	renomLabel.TextScaled = true
	renomLabel.TextColor3 = Style.PALETTE.nomCream
	renomLabel.Text = "🔁"
	renomLabel.Parent = renomButton

	-- Irreversible, so it asks. The dialog names exactly what is lost and what
	-- is gained, because "are you sure?" is not informed consent.
	confirm = Instance.new("Frame")
	confirm.Name = "ConfirmReNom"
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.new(0.86, 0, 0, 240)
	confirm.BackgroundColor3 = Style.PALETTE.plazaStone
	confirm.BorderSizePixel = 0
	confirm.Visible = false
	confirm.ZIndex = 30
	confirm.Parent = gui
	corner(confirm, 20)

	confirmText = Instance.new("TextLabel")
	confirmText.Size = UDim2.new(1, -28, 1, -84)
	confirmText.Position = UDim2.new(0, 14, 0, 14)
	confirmText.BackgroundTransparency = 1
	confirmText.Font = Enum.Font.GothamMedium
	confirmText.TextScaled = true
	confirmText.TextWrapped = true
	confirmText.TextColor3 = Style.PALETTE.ink
	confirmText.Text = ""
	confirmText.Parent = confirm

	local yes = Instance.new("TextButton")
	yes.Position = UDim2.new(0, 14, 1, -60)
	yes.Size = UDim2.new(0.5, -21, 0, TOUCH_MIN + 2)
	yes.BackgroundColor3 = Color3.fromRGB(196, 132, 240)
	yes.BorderSizePixel = 0
	yes.Font = Enum.Font.FredokaOne
	yes.TextScaled = true
	yes.TextColor3 = Style.PALETTE.nomCream
	yes.Text = "RE-NOM!"
	yes.Parent = confirm
	corner(yes, 14)

	local no = Instance.new("TextButton")
	no.AnchorPoint = Vector2.new(1, 0)
	no.Position = UDim2.new(1, -14, 1, -60)
	no.Size = UDim2.new(0.5, -21, 0, TOUCH_MIN + 2)
	no.BackgroundColor3 = Style.PALETTE.shadow
	no.BorderSizePixel = 0
	no.Font = Enum.Font.FredokaOne
	no.TextScaled = true
	no.TextColor3 = Style.PALETTE.ink
	no.Text = "Not yet"
	no.Parent = confirm
	corner(no, 14)

	renomButton.Activated:Connect(function()
		local snap = snapshot
		if not snap then
			return
		end
		confirmText.Text = ("Re-Nom #%d?\n\nYou LOSE all your coins and every Nomling.\n\nYou KEEP your Fusion Book, and everything you earn from now on is multiplied by %.1f instead of %.1f — forever. You also get a free %s egg to restart with."):format(
			(snap.rebirths or 0) + 1,
			snap.nextMultiplier or 1,
			snap.rebirthMultiplier or 1,
			tostring(snap.bestEgg or "basic")
		)
		confirm.Visible = true
	end)

	no.Activated:Connect(function()
		confirm.Visible = false
	end)

	yes.Activated:Connect(function()
		confirm.Visible = false
		local remote = Net.get("Rebirth") :: RemoteFunction
		local ok, reason = remote:InvokeServer()
		if not ok and reason then
			showToast(reason)
		end
	end)

	-- --- toast ---
	-- Sits directly above the tray, which is the top of the control stack, so
	-- it can never end up behind a button. It is also the ONLY thing that
	-- explains a refusal, so it outranks everything else on screen.
	toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -TOAST_TOP)
	toast.Size = UDim2.new(0.8, 0, 0, TOAST_H)
	toast.BackgroundColor3 = Style.PALETTE.ink
	toast.BackgroundTransparency = 0.08
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 50
	toast.Parent = gui
	corner(toast, 12)

	local toastWidth = Instance.new("UISizeConstraint")
	toastWidth.MinSize = Vector2.new(240, 0)
	toastWidth.MaxSize = Vector2.new(430, math.huge)
	toastWidth.Parent = toast

	toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(1, -20, 1, -8)
	toastLabel.Position = UDim2.new(0, 10, 0, 4)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextScaled = true
	toastLabel.TextWrapped = true
	toastLabel.TextColor3 = Style.PALETTE.nomCream
	toastLabel.ZIndex = 51
	toastLabel.Text = ""
	toastLabel.Parent = toast
	cap(toastLabel, 16)
end

-- --- refresh ---------------------------------------------------------------

--- The refresh loop reports its first failure to the player and then shuts up.
local refreshFaultShown = false

--- os.clock() of the last carried-Nomling scan, and what it found.
local lastCarrierScan = 0
local carrierNear = false

--- Is somebody running off with a Nomling within bubbling distance?
---
--- Read off the world rather than pushed from the server, because the thing to
--- look for is already replicated: a player thief carries a model named
--- "Carried" welded to their head, and an NPC thief is a model named Thief_*.
--- No new remote for a question the client can already answer.
---
--- 4 Hz. Bubble range is 26 studs and nobody crosses that in 250 ms.
local function isCarrierNear(): boolean
	local now = os.clock()
	if now - lastCarrierScan < 0.25 then
		return carrierNear
	end
	lastCarrierScan = now

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		carrierNear = false
		return false
	end

	local reach = Snatch.BUBBLE_RANGE
	for _, thing in Workspace:GetChildren() do
		local isCarry = thing.Name == "Carried" or string.sub(thing.Name, 1, 6) == "Thief_"
		if not isCarry or not thing:IsA("Model") then
			continue
		end
		local pivot = thing.PrimaryPart or thing:FindFirstChildWhichIsA("BasePart")
		if pivot and (pivot.Position - root.Position).Magnitude <= reach then
			carrierNear = true
			return true
		end
	end
	carrierNear = false
	return false
end

local function refresh(delta: number)
	local snap = snapshot
	if not snap then
		return
	end

	-- The counter eases toward the real value rather than snapping. A number
	-- that visibly climbs is worth a surprising amount of perceived quality,
	-- and it also hides the one-second sync interval.
	local target = snap.coins or 0
	if math.abs(target - displayedCoins) < 1 then
		displayedCoins = target
	else
		displayedCoins += (target - displayedCoins) * math.min(1, delta * 6)
	end
	coinLabel.Text = Income.format(displayedCoins)

	local rate = snap.perSecond or 0
	-- Name the pocket money when that is all it is. An unexplained trickle of
	-- coins with an empty base reads as a bug; "pocket money" reads as the
	-- game helping you back up, which is what it is.
	rateLabel.Text = if (snap.placedCount or 0) <= 0 and rate > 0
		then `{Income.format(rate)} /s pocket money`
		else `{Income.format(rate)} / sec`

	-- Price and name the tier the button actually buys. Reading `prices.basic`
	-- while buying `bestEgg` meant that after a Re-Nom the button advertised
	-- 25 coins and charged 1200 -- the same hardcoded-"basic" bug that made
	-- five of the six tiers unreachable, left behind in the display half.
	-- THE BUTTON MUST NOT LIE ABOUT ITSELF. From a playtest: "Even if I have
	-- money, and try to buy something it doesn't work." It was working exactly
	-- as designed -- both incubator slots were full, so the server refused --
	-- but the button sat there bright orange reading "Basic Egg · 25", which is
	-- a button claiming it can be pressed. The refusal arrived as a toast that
	-- is easy to miss and gone in two seconds.
	--
	-- Every reason the server would refuse is knowable from the snapshot the
	-- client already has, so the button now shows the blocker instead of the
	-- price and greys out for ALL of them, not just for money.
	local tier = (snap.bestEgg :: string?) or "basic"
	local price = snap.prices and snap.prices[tier]
	local slotsUsed = #(snap.incubators or {})
	local slotsFull = slotsUsed >= Economy.INCUBATORS_BASE
	local affordable = price ~= nil and target >= price
	local buyable = price ~= nil and affordable and not slotsFull

	if not price then
		eggLabel.Text = "Egg locked"
		eggPrice.Text = ""
	elseif slotsFull then
		-- Named the way out, not just the obstacle. A refusal that does not say
		-- what to do next is a dead end (the same rule the belt follows).
		eggLabel.Text = "Nest full"
		eggPrice.Text = "hatch one first"
	else
		eggLabel.Text = Style.EGG_LABEL[tier] or "Buy Egg"
		eggPrice.Text = if affordable
			then Income.format(price)
			else `need {Income.format(price - target)} more`
	end

	eggButton.BackgroundColor3 = if buyable
		then Style.PALETTE.nomOrange
		else Color3.fromRGB(176, 158, 146)

	local cost = snap.rebirthCost
	if cost and target >= cost then
		if not renomButton.Visible then
			renomButton.Visible = true
			JuiceController.pop(renomButton, 0.3)
		end
		-- Just the icon: the button is 56px round. The multiplier is spelled out
		-- in the confirmation, which is where the decision gets made.
		renomLabel.Text = "🔁"
	else
		renomButton.Visible = false
	end

	bubbleButton.Visible = isCarrierNear()

	local incubators = snap.incubators or {}
	for i, slot in slots do
		local entry = incubators[i]
		if not entry then
			slot.button.Visible = false
			continue
		end
		slot.button.Visible = true

		local now = (snap.now or os.time()) + (os.clock() - (snap.at or os.clock()))
		local remaining = math.max(0, entry.readyAt - now)
		local total = math.max(1, entry.total or remaining + 1)

		if remaining <= 0 then
			slot.label.Text = "TAP TO HATCH!"
			slot.button.BackgroundColor3 = Style.PALETTE.nomPink
			slot.fill.Size = UDim2.new(1, 0, 1, 0)
			slot.fill.BackgroundColor3 = Color3.fromRGB(255, 176, 204)
			-- PULSE, once, the moment it becomes ready. An egg that finishes
			-- while the player is looking somewhere else just quietly changes
			-- colour, and a playtester sat on an unclaimed hatch long enough
			-- that both nest slots filled and every purchase was refused --
			-- reported as "even if I have money, buying doesn't work". The
			-- blocked button now says so too, but the better fix is that the
			-- thing to press asks for attention when it is ready.
			if not slot.ready then
				slot.ready = true
				JuiceController.pop(slot.button, 0.3)
			end
		else
			slot.ready = false
			slot.label.Text = `{math.ceil(remaining)}s`
			slot.button.BackgroundColor3 = Style.PALETTE.nomMint
			local progress = math.clamp(1 - remaining / total, 0, 1)
			slot.fill.Size = UDim2.new(progress, 0, 1, 0)
			slot.fill.BackgroundColor3 = Color3.fromRGB(150, 232, 206)
		end
	end
end

--- Adds a round button to the right-hand rail. `order` decides where it sits,
--- so a controller does not need to know what else is on the rail.
---
--- Slots in use: 10 help, 20 Re-Nom, 30 book, 40 shop.
function BaseHudController.railButton(name: string, order: number, fill: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(RAIL_W, RAIL_W)
	button.BackgroundColor3 = fill
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 5
	button.Parent = rail
	corner(button, RAIL_W // 2)
	stroke(button, Style.PALETTE.nomCocoa, 1.5, 0.7)
	depth(button)
	return button
end

--- The objective banner's slot in the top row: everything left over after the
--- purse, and stopping short of the rail. TutorialController parents its
--- banner in here and sizes it (1, 0, 1, 0) rather than picking a position,
--- which is what stops it landing under the Roblox menu buttons or on top of
--- the coin count.
function BaseHudController.objectiveSlot(): Frame
	return objective
end

--- Where a transient announcement goes: under the top row, clear of the rail.
--- WeatherController slides its banner in and out inside this.
function BaseHudController.bannerSlot(): Frame
	return bannerSlot
end

--- The fusion controller owns the picker and the reveal, but the bar lives
--- here so there is exactly one thing deciding the bottom-of-screen layout.
function BaseHudController.fuseButton(): (TextButton, TextLabel)
	return fuseButton, fuseLabel
end

function BaseHudController.toast(message: string)
	showToast(message)
end

function BaseHudController.start()
	build()

	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		snap.at = os.clock()
		local previous = snapshot
		snapshot = snap
		-- Punch the purse when coins jump by a visible amount, which means a
		-- purchase, a hatch or an offline payout rather than the steady tick.
		if previous and (snap.coins or 0) > (previous.coins or 0) * 1.05 then
			JuiceController.pop(purse, 0.1)
		end
	end)

	local notify = Net.get("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			showToast(text)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1 / 20)
			local now = os.clock()
			local delta = now - last
			last = now
			local ok, err = pcall(refresh :: (number) -> any, delta)
			if not ok then
				warn(`[BaseHudController] refresh failed: {err}`)
				-- SAID ONCE, ON SCREEN. This loop runs 20 times a second, so a
				-- refresh that throws used to freeze every number and every
				-- button state in the HUD while printing into a log no phone
				-- can open -- which reaches me as "nothing happens when I press
				-- it" and is the single most expensive bug report this project
				-- has had. Once, because 20 toasts a second is not a message.
				if not refreshFaultShown then
					refreshFaultShown = true
					showToast(`HUD error — tell Claude: {err}`)
				end
			end
		end
	end)
end

return BaseHudController
