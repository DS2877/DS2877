--!strict
--[[
	The HUD: purse, income rate, incubators, the egg button, toasts.

	PHONE FIRST, and that shapes every choice here. Everything tappable is at
	least 56 px on its shortest side and sits in the lower third, inside thumb
	reach. Nothing important goes near the top-right, where a right-handed
	player's thumb covers the screen when they reach for it. The purse is
	top-left because that is the one thing players glance at without tapping.

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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local BaseHudController = {}
BaseHudController.Name = "BaseHudController"

local TOUCH_MIN = 58

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
local confirm: Frame
local confirmText: TextLabel
local toast: Frame
local toastLabel: TextLabel
local slots: { { button: TextButton, label: TextLabel, fill: Frame } } = {}

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

--- A soft drop shadow, built from one offset dark frame behind the surface.
--- There is no shadow image to load, and at this size nobody can tell.
local function shadow(target: GuiObject, spread: number)
	local behind = Instance.new("Frame")
	behind.Name = "Shadow"
	behind.AnchorPoint = target.AnchorPoint
	behind.Position = target.Position + UDim2.fromOffset(0, spread)
	behind.Size = target.Size + UDim2.fromOffset(spread, spread)
	behind.BackgroundColor3 = Style.PALETTE.ink
	behind.BackgroundTransparency = 0.72
	behind.BorderSizePixel = 0
	behind.ZIndex = target.ZIndex - 1
	behind.Parent = target.Parent
	corner(behind, 18)
	return behind
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
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- --- purse ---
	purse = Instance.new("Frame")
	purse.Name = "Purse"
	purse.Position = UDim2.new(0, 14, 0, 14)
	purse.Size = UDim2.new(0, 208, 0, 70)
	purse.BackgroundColor3 = Style.PALETTE.nomCream
	purse.BorderSizePixel = 0
	purse.ZIndex = 4
	purse.Parent = gui
	corner(purse, 18)
	gradient(purse, Color3.fromRGB(255, 252, 244), Color3.fromRGB(246, 232, 208))
	stroke(purse, Style.PALETTE.nomCocoa, 1.5, 0.72)
	shadow(purse, 4)

	local coinIcon = Instance.new("Frame")
	coinIcon.Name = "CoinIcon"
	coinIcon.Position = UDim2.new(0, 12, 0.5, -13)
	coinIcon.Size = UDim2.fromOffset(26, 26)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 206, 84)
	coinIcon.BorderSizePixel = 0
	coinIcon.Parent = purse
	corner(coinIcon, 13)
	stroke(coinIcon, Color3.fromRGB(214, 152, 40), 2, 0)

	coinLabel = label(purse, Enum.Font.FredokaOne, UDim2.new(1, -54, 0, 34), UDim2.new(0, 46, 0, 8))
	coinLabel.Text = "0"
	rateLabel =
		label(purse, Enum.Font.GothamMedium, UDim2.new(1, -54, 0, 18), UDim2.new(0, 46, 0, 44))
	rateLabel.TextColor3 = Style.PALETTE.nomCocoa
	rateLabel.Text = "0 / sec"

	JuiceController.setPurseTarget(purse)

	-- --- incubator slots ---
	local tray = Instance.new("Frame")
	tray.Name = "Incubators"
	tray.AnchorPoint = Vector2.new(0.5, 1)
	tray.Position = UDim2.new(0.5, 0, 1, -100)
	tray.Size = UDim2.new(0, 320, 0, TOUCH_MIN)
	tray.BackgroundTransparency = 1
	tray.ZIndex = 4
	tray.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = tray

	for i = 1, Economy.INCUBATORS_BASE do
		local button = Instance.new("TextButton")
		button.Name = `Slot{i}`
		button.Size = UDim2.new(0, 150, 0, TOUCH_MIN)
		button.BackgroundColor3 = Style.PALETTE.nomMint
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Visible = false
		button.Parent = tray
		corner(button, 16)
		stroke(button, Style.PALETTE.nomCocoa, 1.5, 0.8)

		-- A progress fill behind the text, so a countdown is something you
		-- watch rather than something you read.
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(150, 232, 206)
		fill.BorderSizePixel = 0
		fill.ZIndex = 0
		fill.Parent = button
		corner(fill, 16)

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Style.PALETTE.ink
		text.ZIndex = 2
		text.Text = "-"
		text.Parent = button

		slots[i] = { button = button, label = text, fill = fill }

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
	bar.Position = UDim2.new(0.5, 0, 1, -18)
	bar.Size = UDim2.new(1, -28, 0, 72)
	bar.BackgroundTransparency = 1
	bar.ZIndex = 4
	bar.Parent = gui

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 8)
	barLayout.Parent = bar

	local function barButton(name: string, widthScale: number, fill: Color3): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		-- Scale widths minus the gaps, so the row always fits exactly.
		button.Size = UDim2.new(widthScale, -6, 1, 0)
		button.BackgroundColor3 = fill
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = bar
		corner(button, 20)
		stroke(button, Style.PALETTE.nomCocoa, 1.5, 0.6)
		return button
	end

	fuseButton = barButton("Fuse", 0.26, Style.PALETTE.nomMint)
	fuseLabel = Instance.new("TextLabel")
	fuseLabel.Size = UDim2.fromScale(1, 1)
	fuseLabel.BackgroundTransparency = 1
	fuseLabel.Font = Enum.Font.FredokaOne
	fuseLabel.TextScaled = true
	fuseLabel.TextColor3 = Style.PALETTE.ink
	fuseLabel.Text = "🧪 FUSE"
	fuseLabel.Parent = fuseButton

	eggButton = barButton("BuyEgg", 0.46, Style.PALETTE.nomOrange)
	gradient(eggButton, Color3.fromRGB(255, 176, 98), Color3.fromRGB(240, 128, 44))
	eggLabel =
		label(eggButton, Enum.Font.FredokaOne, UDim2.new(1, -16, 0, 28), UDim2.new(0, 12, 0, 10))
	eggLabel.TextColor3 = Style.PALETTE.nomCream
	eggLabel.Text = "Buy Egg"
	eggPrice =
		label(eggButton, Enum.Font.GothamBold, UDim2.new(1, -16, 0, 20), UDim2.new(0, 12, 0, 40))
	eggPrice.TextColor3 = Color3.fromRGB(255, 240, 220)
	eggPrice.Text = ""

	bubbleButton = barButton("Bubble", 0.26, Style.PALETTE.nomBlue)
	bubbleLabel = Instance.new("TextLabel")
	bubbleLabel.Size = UDim2.fromScale(1, 1)
	bubbleLabel.BackgroundTransparency = 1
	bubbleLabel.Font = Enum.Font.FredokaOne
	bubbleLabel.TextScaled = true
	bubbleLabel.TextColor3 = Style.PALETTE.nomCream
	bubbleLabel.Text = "🫧"
	bubbleLabel.Parent = bubbleButton

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
	rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(1, 0)
	rail.Position = UDim2.new(1, -12, 0, 12)
	rail.Size = UDim2.new(0, 58, 1, -120)
	rail.BackgroundTransparency = 1
	rail.ZIndex = 5
	rail.Parent = gui

	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	railLayout.Padding = UDim.new(0, 8)
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Parent = rail

	-- --- Re-Nom ---
	-- Hidden until affordable. A permanently greyed button for a milestone
	-- hours away is clutter; one that appears the moment you can afford it is
	-- an event.
	renomButton = BaseHudController.railButton("ReNom", 20, Color3.fromRGB(196, 132, 240))
	renomButton.Visible = false
	stroke(renomButton, Color3.fromRGB(128, 72, 172), 2, 0.2)

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
	confirmText.Size = UDim2.new(1, -28, 1, -90)
	confirmText.Position = UDim2.new(0, 14, 0, 14)
	confirmText.BackgroundTransparency = 1
	confirmText.Font = Enum.Font.GothamMedium
	confirmText.TextScaled = true
	confirmText.TextWrapped = true
	confirmText.TextColor3 = Style.PALETTE.ink
	confirmText.Text = ""
	confirmText.Parent = confirm

	local yes = Instance.new("TextButton")
	yes.Position = UDim2.new(0, 14, 1, -66)
	yes.Size = UDim2.new(0.5, -21, 0, 52)
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
	no.Position = UDim2.new(1, -14, 1, -66)
	no.Size = UDim2.new(0.5, -21, 0, 52)
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
	toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -178)
	toast.Size = UDim2.new(0, 320, 0, 46)
	toast.BackgroundColor3 = Style.PALETTE.ink
	toast.BackgroundTransparency = 0.08
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 6
	toast.Parent = gui
	corner(toast, 14)

	toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(1, -20, 1, -10)
	toastLabel.Position = UDim2.new(0, 10, 0, 5)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Font = Enum.Font.GothamMedium
	toastLabel.TextScaled = true
	toastLabel.TextWrapped = true
	toastLabel.TextColor3 = Style.PALETTE.nomCream
	toastLabel.Text = ""
	toastLabel.Parent = toast
end

-- --- refresh ---------------------------------------------------------------

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
	rateLabel.Text = `{Income.format(rate)} / sec`

	local price = snap.prices and snap.prices.basic
	local affordable = price ~= nil and target >= price
	eggLabel.Text = if price then "Buy Egg" else "Egg locked"
	eggPrice.Text = if price then Income.format(price) else ""
	eggButton.BackgroundColor3 = if affordable
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
		else
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
	button.Size = UDim2.fromOffset(56, 56)
	button.BackgroundColor3 = fill
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = rail
	corner(button, 28)
	return button
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
			local ok, err = pcall(refresh, delta)
			if not ok then
				warn(`[BaseHudController] refresh failed: {err}`)
			end
		end
	end)
end

return BaseHudController
