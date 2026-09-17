--!strict
--[[
	Client entry point. Mirrors the server bootstrap: init everything, then
	start everything, in a declared order.

	Every load and every phase is pcall'd, and every failure ends up on the red
	Fault panel. One controller that throws must never be able to take the rest
	of the client with it -- that turns a broken feature into a game that shows
	a HUD and responds to nothing, which is exactly the report this had to be
	debugged from once already.
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
	-- After the HUD (it toasts through it) and before the tutorial, which
	-- points a marker at the nest it builds.
	"HatcheryController",
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
-- A CLIENT ERROR THE PLAYER CAN SEE. Lives in its own dependency-free module
-- so the controllers can reach it too: a button whose remote call fails has
-- exactly the same "nothing happens" symptom as a controller that never
-- started, and both need to end up on the same red panel.
local Fault = require(script.Parent:WaitForChild("Fault"))
local reportFault = Fault.report

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

print(`[Bootstrap] {#controllers} controllers ready, {Fault.count()} faults`)
