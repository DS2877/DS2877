--!strict
--[[
	Client entry point. Mirrors the server bootstrap: init everything, then
	start everything, in a declared order.

	M0 has one controller. Its only job is to prove the client is alive and the
	transport works, so that "the place published and actually runs" is a thing
	we can see rather than assume.
]]

local CONTROLLER_ORDER = {
	"PingController",
	-- Audio first: Juice calls into it, and the HUD and Fusion both call Juice.
	-- A cue fired before the pools exist is a silent no-op rather than an
	-- error, which would have been a genuinely hard bug to notice.
	"AtmosphereController",
	"AudioController",
	"JuiceController",
	"BaseHudController",
	"TutorialController",
	"NomlingRenderController",
	-- Needs nothing from the others; it only reads the pads' OwnerUserId.
	"HomeController",
	-- Shop before Fusion: the fusion picker's Odds button calls into it, and
	-- fusion is a paid random item whose odds must be disclosable.
	"ShopController",
	"FusionController",
	"WeatherController",
	"BookController",
	-- Last: it only listens for a death and draws over everything, so
	-- nothing else depends on it having started.
	"DeathController",
}

type Controller = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

-- --- the one thing that can never fail -------------------------------------
-- A CLIENT ERROR THE PLAYER CAN SEE. This project has exactly one instrument
-- for what happens on a phone, and it is Philip typing what he saw. Until now
-- a controller that threw printed a warn() into a log nobody can open, and the
-- symptom reaching me was "nothing happens when I press it" -- which is the
-- hardest possible bug report to act on and has now cost three rounds.
--
-- So failures go ON SCREEN. Built with no requires and no dependencies, before
-- anything else runs, because the thing that reports a broken controller must
-- not be able to break with one.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local faultLines: { string } = {}
local faultLabel: TextLabel? = nil

local function reportFault(line: string)
	table.insert(faultLines, line)
	warn(`[Bootstrap] {line}`)

	local label = faultLabel
	if not label then
		local screen = Instance.new("ScreenGui")
		screen.Name = "ClientFaults"
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 1000
		screen.Parent = localPlayer:WaitForChild("PlayerGui")

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -20, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Position = UDim2.new(0, 10, 0, 90)
		frame.BackgroundColor3 = Color3.fromRGB(120, 24, 32)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		-- Never swallows a tap. A diagnostic that blocks the buttons it is
		-- reporting on would be worse than no diagnostic.
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
		faultLabel = made
		label = made
	end

	label.Text = `CLIENT FAULT ({#faultLines}) — please send this to Claude:\n`
		.. table.concat(faultLines, "\n")
end

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers: { Controller } = {}

for _, name in CONTROLLER_ORDER do
	local module = controllersFolder:FindFirstChild(name)
	if not module then
		reportFault(`{name}: no module (check default.project.json)`)
		continue
	end

	-- pcall'd, because a module that throws while LOADING used to take the
	-- whole bootstrap with it: no HUD, no controllers, no explanation.
	local ok, controller = pcall(require, module :: ModuleScript)
	if not ok then
		reportFault(`{name}: require failed -- {controller}`)
		continue
	end
	table.insert(controllers, controller :: Controller)
end

local function runPhase(phase: "init" | "start")
	for _, controller in controllers do
		local fn = (controller :: any)[phase]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				reportFault(`{controller.Name}:{phase}() -- {err}`)
			end
		end
	end
end

runPhase("init")
runPhase("start")

print(`[Bootstrap] {#controllers} controllers ready, {#faultLines} faults`)
