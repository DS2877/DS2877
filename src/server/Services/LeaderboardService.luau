--!strict
--[[
	The board on the street: who is earning the most, right now.

	Seeing your own name on a board is worth a surprising amount to a
	nine-year-old, and with eight players it is the cheapest social pressure the
	game has (GDD 5.12).

	SERVER-SIDE AND SERVER-RENDERED. The standings are shared information, so
	there is nothing to personalise and no reason to send eight copies of the
	same list to eight clients. The SurfaceGui updates in place and every player
	sees the same board.

	It shows income per second rather than total coins, deliberately: total coins
	rewards whoever has been logged in longest, while income rewards whoever
	built the better base. One of those is a game and the other is a clock.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Style = require(Shared:WaitForChild("Style"))

local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local IncomeService = require(script.Parent:WaitForChild("IncomeService"))
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

local SHOWN = 5
--- The standings move slowly; the countdowns do not. One second is the coarsest
--- tick that still lets a number visibly fall, which is the whole point of
--- putting a countdown on a board.
local REFRESH_SECONDS = 1

local rowsFrame: Frame? = nil
local tickerFrame: Frame? = nil

local function findBacking(): Frame?
	local street = Workspace:FindFirstChild("Street")
	local board = street and street:FindFirstChild("Leaderboard")
	local gui = board and board:FindFirstChild("Board")
	local backing = gui and gui:FindFirstChildWhichIsA("Frame")
	return backing
end

local function findRows(): Frame?
	local backing = findBacking()
	local rows = backing and backing:FindFirstChild("Rows")
	return if rows and rows:IsA("Frame") then rows else nil
end

local function findTicker(): Frame?
	local backing = findBacking()
	local ticker = backing and backing:FindFirstChild("Ticker")
	return if ticker and ticker:IsA("Frame") then ticker else nil
end

--- "1m 20s", "14s". Minutes only when there are any, because "0m 14s" on a
--- board read from ten studs away is three characters of noise.
local function countdown(seconds: number): string
	local whole = math.max(0, math.floor(seconds + 0.5))
	if whole >= 60 then
		return `{whole // 60}m {whole % 60}s`
	end
	return `{whole}s`
end

--- The three lines under the standings. Each one answers "why should I still
--- be here in a minute?", which a leaderboard on its own never does.
local function refreshTicker()
	local ticker = tickerFrame
	if not ticker then
		return
	end

	local delivery = ticker:FindFirstChild("Delivery")
	if delivery and delivery:IsA("TextLabel") then
		local seconds = ConveyorService.secondsUntilNext()
		delivery.Text = if seconds
			then `🚚 Next Nomling in {countdown(seconds)}`
			else "🚚 Belt starting up..."
	end

	local weather = ticker:FindFirstChild("Weather")
	if weather and weather:IsA("TextLabel") then
		local activeKind, remaining = WeatherService.current()
		if activeKind then
			weather.Text = `⛅ {activeKind} for {countdown(remaining)}`
		else
			local seconds = WeatherService.secondsUntilNext()
			weather.Text = if seconds
				then `⛅ Weather in {countdown(seconds)}`
				else "⛅ Weather: later today"
		end
	end

	-- The best thing currently ON the belt, named and priced. This is the line
	-- that is meant to make people race: "it should be obvious to everyone what
	-- nomlings are coming to make them fight for it."
	local best = ticker:FindFirstChild("Best")
	if best and best:IsA("TextLabel") then
		local incoming = ConveyorService.incoming(1)
		local top = incoming[1]
		if top then
			local mark = if top.mutated then "✨ " else ""
			best.Text = `{mark}Best on belt: {top.label} · 💰 {Income.format(top.price)}`
		else
			best.Text = "Belt is empty right now"
		end
	end
end

local function makeRow(parent: Frame, order: number): Frame
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.Size = UDim2.new(0, 40, 1, 0)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.FredokaOne
	rank.TextScaled = true
	rank.TextColor3 = Style.PALETTE.nomOrange
	rank.Text = `{order}.`
	rank.Parent = row

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Size = UDim2.new(1, -150, 1, 0)
	name.Position = UDim2.new(0, 44, 0, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Style.PALETTE.ink
	name.Text = "—"
	name.Parent = row

	local rate = Instance.new("TextLabel")
	rate.Name = "Rate"
	rate.AnchorPoint = Vector2.new(1, 0)
	rate.Position = UDim2.new(1, 0, 0, 0)
	rate.Size = UDim2.new(0, 104, 1, 0)
	rate.BackgroundTransparency = 1
	rate.Font = Enum.Font.GothamBold
	rate.TextScaled = true
	rate.TextXAlignment = Enum.TextXAlignment.Right
	rate.TextColor3 = Style.PALETTE.nomCocoa
	rate.Text = ""
	rate.Parent = row

	return row
end

local function refresh()
	refreshTicker()

	local rows = rowsFrame
	if not rows then
		return
	end

	type Entry = { name: string, rate: number }
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			table.insert(entries, {
				name = player.DisplayName,
				rate = IncomeService.perSecond(data),
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.rate ~= b.rate then
			return a.rate > b.rate
		end
		-- A stable tiebreak, so equal rates do not make the board flicker
		-- between refreshes.
		return a.name < b.name
	end)

	for index = 1, SHOWN do
		local row = rows:FindFirstChild(`Row{index}`)
		if not row then
			row = makeRow(rows, index)
		end
		local nameLabel = row:FindFirstChild("PlayerName")
		local rateLabel = row:FindFirstChild("Rate")
		local entry = entries[index]
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = if entry then entry.name else "—"
		end
		if rateLabel and rateLabel:IsA("TextLabel") then
			rateLabel.Text = if entry then `{Income.format(entry.rate)}/s` else ""
		end
	end
end

function LeaderboardService.start()
	task.spawn(function()
		-- WorldService builds the board in its own start(); wait for it rather
		-- than depending on ordering that a future edit could change.
		local deadline = os.clock() + 20
		while os.clock() < deadline do
			rowsFrame = findRows()
			tickerFrame = findTicker()
			if rowsFrame then
				break
			end
			task.wait(0.5)
		end
		if not rowsFrame then
			warn("[LeaderboardService] no board found on the street")
			return
		end

		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn(`[LeaderboardService] refresh failed: {err}`)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
