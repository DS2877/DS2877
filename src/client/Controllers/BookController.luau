--!strict
--[[
	The Fusion Book: a 12x12 grid of every fusion, filled in as you find them.

	"Collect them all" is the stickiest hook there is for this audience, and
	this is free content -- the creatures already exist, the book just makes the
	space VISIBLE. A player who can see 137 of 876 filled in has a reason to
	keep fusing that no coins-per-second number provides.

	THE GRID IS THE DESIGN. Rows are the snack parent, columns the animal
	parent, so the matrix shows at a glance that Sushi+Walrus and Walrus+Sushi
	are DIFFERENT squares. That is the one rule about fusion players most need
	to internalise, and a table teaches it faster than any tooltip.

	Undiscovered squares show a "?" rather than being blank: an empty square
	reads as broken, a question mark reads as an invitation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameGen = require(Shared:WaitForChild("Logic"):WaitForChild("NameGen"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Style = require(Shared:WaitForChild("Style"))

local Fault = require(script.Parent.Parent:WaitForChild("Fault"))
local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))
local JuiceController = require(script.Parent:WaitForChild("JuiceController"))

local BookController = {}
BookController.Name = "BookController"

local CELL = 46

local player = Players.LocalPlayer
local panel: Frame
local grid: ScrollingFrame
local header: TextLabel
local detail: TextLabel
local discovered: { [string]: boolean } = {}
local built = false

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function cellColour(found: boolean, sameSpecies: boolean): Color3
	if not found then
		return Color3.fromRGB(216, 208, 200)
	end
	-- The diagonal is the purebred "Prime" line, and it gets its own colour
	-- because those are the twelve squares a player can plan for.
	return if sameSpecies then Color3.fromRGB(255, 206, 110) else Style.PALETTE.nomMint
end

local function buildGrid()
	grid:ClearAllChildren()
	local species = Nomlings.SPECIES
	local size = #species

	for row, snackSpecies in species do
		for col, animalSpecies in species do
			local key = NameGen.comboKey(snackSpecies.id, animalSpecies.id, 2, nil)
			local found = discovered[key] == true
			local same = snackSpecies.id == animalSpecies.id

			local cell = Instance.new("TextButton")
			cell.Name = key
			cell.Size = UDim2.fromOffset(CELL - 4, CELL - 4)
			cell.Position = UDim2.fromOffset((col - 1) * CELL, (row - 1) * CELL)
			cell.BackgroundColor3 = cellColour(found, same)
			cell.BorderSizePixel = 0
			cell.Font = Enum.Font.FredokaOne
			cell.TextScaled = true
			cell.TextColor3 = if found then Style.PALETTE.ink else Color3.fromRGB(160, 152, 148)
			-- A found square shows the first letters of its generated name; an
			-- unfound one shows "?", which reads as an invitation rather than
			-- as something broken.
			cell.Text = if found
				then string.sub(
					NameGen.build(
						snackSpecies,
						animalSpecies,
						2,
						Nomlings.GEN3_AFFIXES,
						Nomlings.PUREBRED_AFFIX
					),
					1,
					2
				)
				else "?"
			cell.Parent = grid
			corner(cell, 8)

			cell.Activated:Connect(function()
				local name = NameGen.build(
					snackSpecies,
					animalSpecies,
					2,
					Nomlings.GEN3_AFFIXES,
					Nomlings.PUREBRED_AFFIX
				)
				if found then
					detail.Text = `✅ {name}  —  {snackSpecies.name} + {animalSpecies.name}`
				else
					detail.Text =
						`❓ {snackSpecies.name} + {animalSpecies.name} — fuse them in that order!`
				end
				JuiceController.pop(cell, 0.2)
			end)
		end
	end

	grid.CanvasSize = UDim2.fromOffset(size * CELL, size * CELL)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BookGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = BaseHudController.railButton("OpenBook", 30, Style.PALETTE.nomMint)
	local openLabel = Instance.new("TextLabel")
	openLabel.Size = UDim2.fromScale(1, 1)
	openLabel.BackgroundTransparency = 1
	openLabel.Font = Enum.Font.FredokaOne
	openLabel.TextScaled = true
	openLabel.TextColor3 = Style.PALETTE.ink
	openLabel.Text = "📖"
	openLabel.Parent = open

	panel = Instance.new("Frame")
	panel.Name = "Book"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.94, 0, 0.8, 0)
	panel.BackgroundColor3 = Style.PALETTE.plazaStone
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 25
	panel.Parent = gui
	corner(panel, 20)

	header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -70, 0, 42)
	header.Position = UDim2.new(0, 14, 0, 10)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Style.PALETTE.ink
	header.Text = "Fusion Book"
	header.Parent = panel

	detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, -28, 0, 30)
	detail.Position = UDim2.new(0, 14, 0, 54)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.TextScaled = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Style.PALETTE.nomCocoa
	detail.Text = "Tap a square. Rows are the snack, columns the animal."
	detail.Parent = panel

	grid = Instance.new("ScrollingFrame")
	grid.Size = UDim2.new(1, -28, 1, -106)
	grid.Position = UDim2.new(0, 14, 0, 90)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollingDirection = Enum.ScrollingDirection.XY
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel

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
	close.Parent = panel
	corner(close, 22)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	open.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
			return
		end
		-- pcall'd like every other client->server call. GetBook returns a
		-- table rather than the usual (ok, reason), so it cannot go through
		-- Net.invoke -- but a handler that errors would still leave the button
		-- doing nothing at all, which is the symptom this whole round is about.
		local called, result = pcall(function()
			return (Net.get("GetBook") :: RemoteFunction):InvokeServer()
		end)
		if not called then
			Fault.report(`GetBook: {result}`)
			return
		end
		if type(result) ~= "table" then
			return
		end
		discovered = {}
		for _, key in result.discovered or {} do
			discovered[tostring(key)] = true
		end
		local total = (result.totals and result.totals.all) or 0
		header.Text = `Fusion Book — {result.count or 0} / {total}`
		buildGrid()
		panel.Visible = true
		panel.Size = UDim2.new(0.86, 0, 0.72, 0)
		TweenService:Create(
			panel,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0.94, 0, 0.8, 0) }
		):Play()
	end)

	built = true
end

function BookController.start()
	build()
	assert(built, "book failed to build")
end

return BookController
