--!strict
--[[
	Puts client-side failures ON THE PHONE SCREEN.

	This project has exactly one instrument for what happens on a real device,
	and it is Philip typing what he saw. A controller that threw used to print
	a warn() into a developer console that does not exist on a phone, so the
	symptom that reached me was "nothing happens when I press it" -- the
	hardest possible bug report to act on, and it has now cost several rounds.

	So anything that breaks says so, in red, at the top of the screen, with
	enough detail to name the cause.

	NO REQUIRES, NO DEPENDENCIES, ON PURPOSE. The thing that reports a broken
	module must not be able to break with one. It does not require Style, it
	does not require Net, and every path through it is safe to call before any
	other controller has started.
]]

local Players = game:GetService("Players")

local Fault = {}

local lines: { string } = {}
local label: TextLabel? = nil

--- Keeps the panel from growing without bound when something fails in a loop.
local MAX_LINES = 8

local function ensureLabel(): TextLabel?
	if label then
		return label
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local parent = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not parent then
		return nil
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "ClientFaults"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	-- Above everything, including the death screen, which is the one other
	-- thing that draws over the whole display.
	screen.DisplayOrder = 1000
	screen.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -20, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Position = UDim2.new(0, 10, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(120, 24, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	-- Never swallows a tap. A diagnostic that blocks the buttons it is
	-- reporting on would be worse than no diagnostic at all.
	frame.Active = false
	frame.Parent = screen

	local made = Instance.new("TextLabel")
	made.Size = UDim2.new(1, -16, 0, 0)
	made.Position = UDim2.new(0, 8, 0, 6)
	made.AutomaticSize = Enum.AutomaticSize.Y
	made.BackgroundTransparency = 1
	made.Font = Enum.Font.Code
	made.TextSize = 13
	made.TextWrapped = true
	made.TextXAlignment = Enum.TextXAlignment.Left
	made.TextColor3 = Color3.fromRGB(255, 226, 226)
	made.Active = false
	made.Parent = frame

	label = made
	return made
end

--- Records a fault and shows it. Safe to call from anywhere, at any time,
--- including before the PlayerGui exists -- it degrades to a warn() rather
--- than throwing a second error on top of the first.
function Fault.report(line: string)
	warn(`[Fault] {line}`)

	-- Repeats are counted, not stacked: a failure inside a per-frame loop
	-- would otherwise push the real first cause off the top of the screen.
	local last = lines[#lines]
	if last and string.sub(last, 1, #line) == line then
		lines[#lines] = `{line}  (x{(tonumber(string.match(last, "%(x(%d+)%)$")) or 1) + 1})`
	else
		table.insert(lines, line)
		if #lines > MAX_LINES then
			table.remove(lines, 1)
		end
	end

	local target = ensureLabel()
	if not target then
		return
	end
	target.Text = `CLIENT FAULT ({#lines}) — please send this to Claude:\n`
		.. table.concat(lines, "\n")
end

--- How many faults have been reported. Bootstrap prints this so a clean run
--- is also visible, not just a broken one.
function Fault.count(): number
	return #lines
end

return Fault
