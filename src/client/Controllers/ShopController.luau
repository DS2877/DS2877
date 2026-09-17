--!strict
--[[
	The Egg Market, and the odds panels.

	TWO JOBS, AND THE SECOND ONE IS A LEGAL REQUIREMENT.

	1. A shop that shows all six egg tiers with their prices and which ones are
	   still locked. The locked ones are half the point: a nine-year-old seeing
	   "Cosmic Diner — unlocks at Re-Nom 5" has a goal, and a shop that only
	   shows what you can already afford has no aspiration in it.

	2. ODDS DISCLOSURE. docs/COMPLIANCE.md 2: every paid random item must show
	   all possible outcomes with actual numerical odds, as percentages summing
	   to exactly 100%, behind a button carrying a DESCRIPTIVE WORD -- never a
	   bare (i) icon. That is Roblox policy, not a preference, and getting it
	   wrong risks the rating the whole Kids-tier plan depends on.

	   FUSION IS ALSO A PAID RANDOM ITEM, which is easy to overlook: Roblox's own
	   example of a "combination item" is synthesising two rare eggs for a better
	   chance at a higher-quality result. So the kitchen gets an Odds button too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Net = require(Shared:WaitForChild("Net"))
local Odds = require(Shared:WaitForChild("Logic"):WaitForChild("Odds"))
local Style = require(Shared:WaitForChild("Style"))

local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))
local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local ShopController = {}
ShopController.Name = "ShopController"

local player = Players.LocalPlayer
local snapshot: { [string]: any }? = nil

local gui: ScreenGui
local shop: Frame
local shopList: ScrollingFrame
local oddsPanel: Frame
local oddsTitle: TextLabel
local oddsList: ScrollingFrame

--- Display names, so the UI never shows a config key to a player. Shared with
--- the HUD's egg button, which has to name the same tier it buys.
local EGG_LABEL: { [string]: string } = Style.EGG_LABEL

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function sortedEggKeys(): { string }
	local keys: { string } = {}
	for key in Economy.EGGS do
		table.insert(keys, key)
	end
	-- By unlock order, so the shop reads as a ladder. Sorted rather than
	-- iterated, because Luau table order is undefined and a shop that reshuffles
	-- itself between openings is maddening.
	table.sort(keys, function(a, b)
		local ea, eb = Economy.EGGS[a], Economy.EGGS[b]
		if ea.unlockRebirth ~= eb.unlockRebirth then
			return ea.unlockRebirth < eb.unlockRebirth
		end
		return a < b
	end)
	return keys
end

-- --- odds ------------------------------------------------------------------

local function row(parent: Instance, left: string, right: string, colour: Color3, order: number)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, -8, 0, 34)
	line.BackgroundColor3 = Color3.fromRGB(255, 252, 244)
	line.BorderSizePixel = 0
	line.LayoutOrder = order
	line.Parent = parent
	corner(line, 8)

	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(0, 8, 1, -12)
	chip.Position = UDim2.new(0, 8, 0, 6)
	chip.BackgroundColor3 = colour
	chip.BorderSizePixel = 0
	chip.Parent = line
	corner(chip, 4)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(0.62, -24, 1, 0)
	name.Position = UDim2.new(0, 24, 0, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Style.PALETTE.ink
	name.Text = left
	name.Parent = line

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(0.38, -12, 1, 0)
	value.Position = UDim2.new(0.62, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = Style.PALETTE.nomCocoa
	value.Text = right
	value.Parent = line
end

--- Shows an egg's full outcome table. Every rarity, every percentage, summing
--- to 100% -- which is guaranteed by the ppm total being CI-asserted at exactly
--- 1,000,000 in three places.
function ShopController.showEggOdds(eggKey: string)
	local egg = Economy.EGGS[eggKey]
	if not egg then
		return
	end
	oddsTitle.Text = `{EGG_LABEL[eggKey] or eggKey} — chances`
	oddsList:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = oddsList

	local order = 0
	local total = 0
	-- Best first: a player opening this wants to know what the good outcome is.
	for index = #Economy.RARITY_ORDER, 1, -1 do
		local rarity = Economy.RARITY_ORDER[index]
		local ppm = egg.odds[rarity]
		if ppm and ppm > 0 then
			order += 1
			total += ppm
			local spec = Style.RARITY[rarity] or Style.RARITY.common
			row(oddsList, spec.label, Odds.formatPercent(ppm), spec.color, order)
		end
	end

	order += 1
	row(oddsList, "Total", Odds.formatPercent(total), Style.PALETTE.ink, order)
	oddsList.CanvasSize = UDim2.fromOffset(0, order * 39 + 8)
	oddsPanel.Visible = true
end

--- Fusion's outcomes. A combination item under Roblox's own definition, so its
--- odds are disclosed exactly like an egg's.
function ShopController.showFusionOdds()
	oddsTitle.Text = "Fusing — chances"
	oddsList:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = oddsList

	local same = Economy.FUSION_UPGRADE_CHANCE_SAME_TIER
	local diff = Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER
	local mutate = Economy.FUSION_MUTATION_INHERIT_CHANCE

	-- NAMED FIELDS, not a positional tuple. `{ string, string, Color3 }` makes
	-- Luau unify all three slots into one element type, so entry[3] reads as a
	-- string and entry[1] as a Color3 -- and a disclosure panel is the last
	-- place to find out at runtime that a label and a colour got swapped.
	type OddsRow = { label: string, value: string, colour: Color3 }

	local entries: { OddsRow } = {
		{
			label = "Same rarity: one rarity HIGHER",
			value = `{string.format("%.1f", same * 100)}%`,
			colour = Style.RARITY.epic.color,
		},
		{
			label = "Same rarity: stays the same",
			value = `{string.format("%.1f", (1 - same) * 100)}%`,
			colour = Style.RARITY.common.color,
		},
		{
			label = "Mixed rarity: one rarity HIGHER",
			value = `{string.format("%.1f", diff * 100)}%`,
			colour = Style.RARITY.rare.color,
		},
		{
			label = "Mixed rarity: keeps the higher one",
			value = `{string.format("%.1f", (1 - diff) * 100)}%`,
			colour = Style.RARITY.common.color,
		},
		{
			label = "Keeps a parent's mutation",
			value = `{string.format("%.1f", mutate * 100)}%`,
			colour = Style.RARITY.legendary.color,
		},
		{
			label = "Fusing never creates a new mutation",
			value = "0%",
			colour = Style.PALETTE.shadow,
		},
	}
	for index, entry in entries do
		row(oddsList, entry.label, entry.value, entry.colour, index)
	end

	oddsList.CanvasSize = UDim2.fromOffset(0, #entries * 39 + 8)
	oddsPanel.Visible = true
end

-- --- shop ------------------------------------------------------------------

local function refreshShop()
	local snap = snapshot
	shopList:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = shopList

	local rebirths = (snap and snap.rebirths) or 0
	local coins = (snap and snap.coins) or 0
	local prices = (snap and snap.prices) or {}
	local keys = sortedEggKeys()

	for index, key in keys do
		local egg = Economy.EGGS[key]
		local unlocked = rebirths >= egg.unlockRebirth
		local price = prices[key]

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 86)
		card.BackgroundColor3 = if unlocked
			then Color3.fromRGB(255, 252, 244)
			else Color3.fromRGB(226, 220, 214)
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.Parent = shopList
		corner(card, 14)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -120, 0, 30)
		title.Position = UDim2.new(0, 14, 0, 8)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = if unlocked then Style.PALETTE.ink else Color3.fromRGB(148, 140, 136)
		title.Text = EGG_LABEL[key] or key
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -120, 0, 22)
		sub.Position = UDim2.new(0, 14, 0, 40)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.TextScaled = true
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Style.PALETTE.nomCocoa
		sub.Text = if unlocked
			then `{Income.format(price or 0)} coins · hatches in {egg.hatch}s`
			else `🔒 Unlocks at Re-Nom {egg.unlockRebirth}`
		sub.Parent = card

		-- The Odds button. A DESCRIPTIVE WORD, never a bare icon -- that is the
		-- policy wording and the reason this says "Odds" and not "(i)".
		local odds = Instance.new("TextButton")
		odds.AnchorPoint = Vector2.new(1, 1)
		odds.Position = UDim2.new(1, -12, 1, -10)
		odds.Size = UDim2.fromOffset(74, 32)
		odds.BackgroundColor3 = Style.PALETTE.nomBlue
		odds.BorderSizePixel = 0
		odds.Font = Enum.Font.GothamBold
		odds.TextScaled = true
		odds.TextColor3 = Style.PALETTE.nomCream
		odds.Text = "Odds"
		odds.Parent = card
		corner(odds, 10)
		odds.Activated:Connect(function()
			ShopController.showEggOdds(key)
		end)

		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0)
		buy.Position = UDim2.new(1, -12, 0, 10)
		buy.Size = UDim2.fromOffset(94, 34)
		buy.BackgroundColor3 = if unlocked
				and price
				and coins >= price
			then Style.PALETTE.nomOrange
			else Style.PALETTE.shadow
		buy.BorderSizePixel = 0
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextColor3 = Style.PALETTE.nomCream
		buy.Text = if unlocked then "Buy" else "Locked"
		buy.Parent = card
		corner(buy, 10)

		if unlocked then
			buy.Activated:Connect(function()
				local remote = Net.get("BuyEgg") :: RemoteFunction
				local ok = remote:InvokeServer(key)
				if ok then
					JuiceController.pop(buy, 0.2)
				end
			end)
		end
	end

	shopList.CanvasSize = UDim2.fromOffset(0, #keys * 94 + 8)
end

local function panel(name: string, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.92, 0, height, 0)
	frame.BackgroundColor3 = Style.PALETTE.plazaStone
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 20)
	return frame
end

local function closeButton(parent: Frame, onClose: () -> ())
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
	close.Parent = parent
	corner(close, 22)
	close.Activated:Connect(onClose)
end

function ShopController.openShop()
	refreshShop()
	shop.Visible = true
	shop.Size = UDim2.new(0.84, 0, 0.66, 0)
	TweenService:Create(
		shop,
		TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.92, 0, 0.74, 0) }
	):Play()
end

--- Wires the prompts on the two landmark counters. Client-side because they
--- only open a panel; nothing about them changes state.
local function bindLandmarks()
	task.spawn(function()
		local street = Workspace:WaitForChild("Street", 30)
		if not street then
			return
		end
		local function bind(modelName: string, open: () -> ())
			local model = street:WaitForChild(modelName, 15)
			local counter = model and model:FindFirstChild("Counter")
			local prompt = counter and counter:FindFirstChild("Use")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(open)
			end
		end
		bind("EggMarket", ShopController.openShop)
		bind("FusionLab", function()
			-- The kitchen's own picker lives in FusionController; opening it from
			-- here would duplicate that state. Its odds panel is the part this
			-- module owns.
			ShopController.showFusionOdds()
		end)
	end)
end

function ShopController.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- A button as well as the market counter. The counter is the nicer way in,
	-- but a phone player halfway down the street should not have to walk back.
	local openButton = BaseHudController.railButton("OpenShop", 40, Style.PALETTE.nomOrange)
	local openLabel = Instance.new("TextLabel")
	openLabel.Size = UDim2.fromScale(1, 1)
	openLabel.BackgroundTransparency = 1
	openLabel.Font = Enum.Font.FredokaOne
	openLabel.TextScaled = true
	openLabel.TextColor3 = Style.PALETTE.nomCream
	openLabel.Text = "🥚"
	openLabel.Parent = openButton
	openButton.Activated:Connect(function()
		if shop.Visible then
			shop.Visible = false
		else
			ShopController.openShop()
		end
	end)

	shop = panel("EggShop", 0.74)
	shop.ZIndex = 22

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 42)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Style.PALETTE.ink
	title.Text = "🥚 Egg Market"
	title.Parent = shop

	shopList = Instance.new("ScrollingFrame")
	shopList.Size = UDim2.new(1, -28, 1, -68)
	shopList.Position = UDim2.new(0, 14, 0, 58)
	shopList.BackgroundTransparency = 1
	shopList.BorderSizePixel = 0
	shopList.ScrollBarThickness = 6
	shopList.CanvasSize = UDim2.new()
	shopList.Parent = shop
	closeButton(shop, function()
		shop.Visible = false
	end)

	oddsPanel = panel("Odds", 0.62)
	oddsPanel.ZIndex = 28

	oddsTitle = Instance.new("TextLabel")
	oddsTitle.Size = UDim2.new(1, -70, 0, 40)
	oddsTitle.Position = UDim2.new(0, 14, 0, 10)
	oddsTitle.BackgroundTransparency = 1
	oddsTitle.Font = Enum.Font.FredokaOne
	oddsTitle.TextScaled = true
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.TextColor3 = Style.PALETTE.ink
	oddsTitle.Text = "Chances"
	oddsTitle.Parent = oddsPanel

	oddsList = Instance.new("ScrollingFrame")
	oddsList.Size = UDim2.new(1, -28, 1, -66)
	oddsList.Position = UDim2.new(0, 14, 0, 56)
	oddsList.BackgroundTransparency = 1
	oddsList.BorderSizePixel = 0
	oddsList.ScrollBarThickness = 6
	oddsList.CanvasSize = UDim2.new()
	oddsList.Parent = oddsPanel
	closeButton(oddsPanel, function()
		oddsPanel.Visible = false
	end)

	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		snapshot = snap
		if shop.Visible then
			refreshShop()
		end
	end)

	bindLandmarks()
end

return ShopController
