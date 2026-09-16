--!strict
--[[
	Server entry point.

	Services are plain modules with optional `init` and `start`. Every service
	runs `init` before any service runs `start`, so a service may reference
	another's existence during init but must not rely on its started state.

	Order is explicit and declared here, not inferred. When ordering matters
	the reason belongs in a comment next to the name.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local SERVICE_ORDER = {
	-- Remotes must exist before anything tries to resolve one.
	"NetService",
	"PlazaService",
}

type Service = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

local servicesFolder = script.Parent:WaitForChild("Services")
local services: { Service } = {}

local function loadServices()
	for _, name in SERVICE_ORDER do
		local module = servicesFolder:FindFirstChild(name)
		assert(module ~= nil, `service '{name}' is in SERVICE_ORDER but has no module`)

		local service = require(module :: ModuleScript) :: Service
		assert(service.Name == name, `service module '{name}' reports Name='{service.Name}'`)
		table.insert(services, service)
	end
end

local function runPhase(phase: "init" | "start")
	for _, service in services do
		local fn = (service :: any)[phase]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				-- One broken service must not take the whole server down; a
				-- partially working game is far better than a join failure.
				warn(`[Bootstrap] {service.Name}:{phase}() failed: {err}`)
			end
		end
	end
end

local startedAt = os.clock()

Net.build()
loadServices()
runPhase("init")
runPhase("start")

print(string.format("[Bootstrap] %d services ready in %.0f ms", #services, (os.clock() - startedAt) * 1000))
