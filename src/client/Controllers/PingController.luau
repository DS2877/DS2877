--!strict
--[[
	M0 liveness check.

	Calls Ping once on start and logs the round trip. This is what turns
	"the deploy reported success" into "the game is actually running", which
	matters more than usual here: Philip reviews on a phone and cannot open
	Studio to check.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local PingController = {}
PingController.Name = "PingController"

function PingController.start()
	local ping = Net.get("Ping") :: RemoteFunction

	local startedAt = os.clock()
	local ok, result = pcall(function()
		return ping:InvokeServer()
	end)

	if not ok then
		warn(`[PingController] ping failed: {result}`)
		return
	end

	local elapsedMs = (os.clock() - startedAt) * 1000
	if typeof(result) == "table" and result.ok then
		print(string.format("[PingController] server alive, round trip %.0f ms", elapsedMs))
	else
		warn(`[PingController] server rejected ping: {result and result.reason or "unknown"}`)
	end
end

return PingController
