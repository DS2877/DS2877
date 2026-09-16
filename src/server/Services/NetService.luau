--!strict
--[[
	Owns remote handlers and their per-player rate limits.

	Every declared remote gets a bucket per player. A player over budget is
	rejected, not disconnected -- our players are children and a dropped
	connection reads as "the game is broken" (docs/COMPLIANCE.md section 8).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local TokenBucket = require(Shared:WaitForChild("Logic"):WaitForChild("TokenBucket"))

local NetService = {}
NetService.Name = "NetService"

type BucketsByRemote = { [string]: TokenBucket.Bucket }

local buckets: { [Player]: BucketsByRemote } = {}

local function bucketsFor(player: Player): BucketsByRemote
	local existing = buckets[player]
	if existing then
		return existing
	end

	local created: BucketsByRemote = {}
	local now = os.clock()
	for name, spec in Net.REMOTES do
		created[name] = TokenBucket.new(spec.rateCapacity, spec.rateRefill, now)
	end
	buckets[player] = created
	return created
end

--- True when this call is within the player's budget for that remote.
function NetService.allow(player: Player, remoteName: string): boolean
	local bucket = bucketsFor(player)[remoteName]
	if not bucket then
		return false
	end
	return TokenBucket.consume(bucket, os.clock())
end

function NetService.init()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function NetService.start()
	local ping = Net.get("Ping") :: RemoteFunction
	ping.OnServerInvoke = function(player: Player)
		if not NetService.allow(player, "Ping") then
			return { ok = false, reason = "rate_limited" }
		end
		return { ok = true, serverTime = os.time() }
	end
end

return NetService
