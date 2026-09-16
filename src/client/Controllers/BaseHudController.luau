--!strict
--[[
	The M1 HUD: coins, the egg button, and the incubator slots.

	Built from plain Instances rather than React-Lua. React-Lua is approved
	(docs/DECISIONS.md D-005) and is still the destination for real UI, but
	four labels and two buttons do not need a reconciler, and adding one to
	the first playable slice means two new things being tested at once.
	It lands when the UI actually earns it.

	PHONE FIRST. Every tappable thing is at least 56 px on its shortest side
	and sits in the lower half of the screen, inside thumb reach. Nothing
	important hides behind the Roblox top bar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local BaseHudController = {}
BaseHudController.Name = "BaseHudController"

local TOUCH_MIN = 56

local player = Players.LocalPlayer
local snapshot: { [string]: any }? = nil
local coinLabel: TextLabel
local rateLabel: TextLabel
local eggButton: TextButton
local slotButtons: { TextButton } = {}
local toast: TextLabel

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function showToast(text: string)
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function()
		if toast.Text == text then
			toast.Visible = false
		end
	end)
end

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BaseHud"
	gui.ResetOnSpawn = false
	-- Keeps the HUD clear of the notch and the Roblox top bar without us
	-- hard-coding an inset per device.
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- --- coins ---
	local purse = Instance.new("Frame")
	purse.Name = "Purse"
	purse.AnchorPoint = Vector2.new(0, 0)
	purse.Position = UDim2.new(0, 12, 0, 12)
	purse.Size = UDim2.new(0, 190, 0, 62)
	purse.BackgroundColor3 = Style.PALETTE.nomCream
	purse.BackgroundTransparency = 0.08
	purse.BorderSizePixel = 0
	purse.Parent = gui
	corner(purse, 14)

	coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "Coins"
	coinLabel.Position = UDim2.new(0, 12, 0, 6)
	coinLabel.Size = UDim2.new(1, -24, 0, 32)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Font = Enum.Font.FredokaOne
	coinLabel.TextScaled = true
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.TextColor3 = Style.PALETTE.ink
	coinLabel.Text = "0"
	coinLabel.Parent = purse

	rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "Rate"
	rateLabel.Position = UDim2.new(0, 12, 0, 38)
	rateLabel.Size = UDim2.new(1, -24, 0, 18)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Font = Enum.Font.Gotham
	rateLabel.TextScaled = true
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateLabel.TextColor3 = Style.PALETTE.nomCocoa
	rateLabel.Text = "0 / sec"
	rateLabel.Parent = purse

	-- --- incubator slots ---
	local slots = Instance.new("Frame")
	slots.Name = "Incubators"
	slots.AnchorPoint = Vector2.new(0.5, 1)
	slots.Position = UDim2.new(0.5, 0, 1, -90)
	slots.Size = UDim2.new(0, 300, 0, TOUCH_MIN)
	slots.BackgroundTransparency = 1
	slots.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = slots

	for i = 1, Economy.INCUBATORS_BASE do
		local slot = Instance.new("TextButton")
		slot.Name = `Slot{i}`
		slot.Size = UDim2.new(0, 146, 0, TOUCH_MIN)
		slot.BackgroundColor3 = Style.PALETTE.nomMint
		slot.BorderSizePixel = 0
		slot.Font = Enum.Font.FredokaOne
		slot.TextScaled = true
		slot.TextColor3 = Style.PALETTE.ink
		slot.Text = "-"
		slot.Visible = false
		slot.Parent = slots
		corner(slot, 14)
		slotButtons[i] = slot

		slot.Activated:Connect(function()
			local remote = Net.get("ClaimHatch") :: RemoteFunction
			local ok, reason = remote:InvokeServer(i)
			if not ok and reason then
				showToast(reason)
			end
		end)
	end

	-- --- buy ---
	eggButton = Instance.new("TextButton")
	eggButton.Name = "BuyEgg"
	eggButton.AnchorPoint = Vector2.new(0.5, 1)
	eggButton.Position = UDim2.new(0.5, 0, 1, -18)
	eggButton.Size = UDim2.new(0, 300, 0, 64)
	eggButton.BackgroundColor3 = Style.PALETTE.nomOrange
	eggButton.BorderSizePixel = 0
	eggButton.Font = Enum.Font.FredokaOne
	eggButton.TextScaled = true
	eggButton.TextColor3 = Style.PALETTE.nomCream
	eggButton.Text = "Buy Egg"
	eggButton.Parent = gui
	corner(eggButton, 18)

	eggButton.Activated:Connect(function()
		local remote = Net.get("BuyEgg") :: RemoteFunction
		local ok, reason = remote:InvokeServer("basic")
		if not ok and reason then
			showToast(reason)
		end
	end)

	-- --- toast ---
	toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -160)
	toast.Size = UDim2.new(0, 300, 0, 40)
	toast.BackgroundColor3 = Style.PALETTE.ink
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.Gotham
	toast.TextScaled = true
	toast.TextColor3 = Style.PALETTE.nomCream
	toast.Text = ""
	toast.Visible = false
	toast.Parent = gui
	corner(toast, 12)

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

--- Redraws from the last snapshot. Called every frame-ish, so it must stay
--- allocation-free and must never assume a field is present.
local function refresh()
	local snap = snapshot
	if not snap then
		return
	end

	coinLabel.Text = Income.format(snap.coins or 0)

	local price = snap.prices and snap.prices.basic
	eggButton.Text = if price then `Buy Egg  {Income.format(price)}` else "Egg locked"
	local affordable = price ~= nil and (snap.coins or 0) >= price
	eggButton.BackgroundColor3 = if affordable
		then Style.PALETTE.nomOrange
		else Style.PALETTE.shadow

	local incubators = snap.incubators or {}
	for i, slot in slotButtons do
		local entry = incubators[i]
		if not entry then
			slot.Visible = false
			continue
		end
		slot.Visible = true
		-- Count down from the client's own clock between syncs, so the timer
		-- ticks smoothly instead of jumping once a second.
		local remaining = math.max(
			0,
			entry.readyAt - (snap.now or os.time()) - (os.clock() - (snap.at or os.clock()))
		)
		if remaining <= 0 then
			slot.Text = "TAP TO HATCH!"
			slot.BackgroundColor3 = Style.PALETTE.nomPink
		else
			slot.Text = `{math.ceil(remaining)}s`
			slot.BackgroundColor3 = Style.PALETTE.nomMint
		end
	end
end

function BaseHudController.start()
	build()

	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		snap.at = os.clock()
		snapshot = snap
		refresh()
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			refresh()
		end
	end)
end

return BaseHudController
