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
	"FusionController",
	"WeatherController",
}

type Controller = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers: { Controller } = {}

for _, name in CONTROLLER_ORDER do
	local module = controllersFolder:FindFirstChild(name)
	assert(module ~= nil, `controller '{name}' is in CONTROLLER_ORDER but has no module`)

	local controller = require(module :: ModuleScript) :: Controller
	assert(controller.Name == name, `controller module '{name}' reports Name='{controller.Name}'`)
	table.insert(controllers, controller)
end

local function runPhase(phase: "init" | "start")
	for _, controller in controllers do
		local fn = (controller :: any)[phase]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				warn(`[Bootstrap] {controller.Name}:{phase}() failed: {err}`)
			end
		end
	end
end

runPhase("init")
runPhase("start")

print(`[Bootstrap] {#controllers} controllers ready`)
