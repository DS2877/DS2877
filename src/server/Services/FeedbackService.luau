--!strict
--[[
	Fires juice cues at clients.

	One place that knows the cue names, so the server sending them and
	JuiceController reading them cannot drift. Cues are FEEDBACK ONLY -- a
	dropped one costs a sparkle, never a state change -- which is why this is a
	plain event with no acknowledgement and no retry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local FeedbackService = {}
FeedbackService.Name = "FeedbackService"

local remote: RemoteEvent? = nil

local function channel(): RemoteEvent?
	if not remote then
		local found = Net.get("Feedback")
		remote = found :: RemoteEvent
	end
	return remote
end

--- Sends a cue to one player.
function FeedbackService.fire(
	player: Player,
	kind: string,
	position: Vector3?,
	extra: { [string]: any }?
)
	local event = channel()
	if event then
		event:FireClient(player, kind, position, extra)
	end
end

--- Sends a cue to everybody. Used for the loud shared moments -- a World First
--- or a Golden Egg -- never for one player's coin.
function FeedbackService.fireAll(kind: string, position: Vector3?, extra: { [string]: any }?)
	local event = channel()
	if event then
		event:FireAllClients(kind, position, extra)
	end
end

return FeedbackService
