--!strict
--[[
	The Bubble Wand. Everyone has one, always (GDD 5.8).

	It is the entire counter-play to being robbed. Without it, snatching is
	something that happens TO a player, and the design intent -- "that was
	exciting", never "I lost my afternoon" -- is impossible.

	THE CLIENT ONLY SAYS "I PRESSED IT". The server finds who is in range and
	decides what happens. A client that could name its target could bubble
	anybody on the street from anywhere on it.

	It tries NPC thieves and player thieves in turn, because from the player's
	side there is no difference: something is running off with their Nomling and
	they want it back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Snatch = require(Shared:WaitForChild("Config"):WaitForChild("Snatch"))

local NetService = require(script.Parent:WaitForChild("NetService"))
local SnatchNpcService = require(script.Parent:WaitForChild("SnatchNpcService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local BubbleService = {}
BubbleService.Name = "BubbleService"

local lastFired: { [Player]: number } = {}

function BubbleService.fire(player: Player): (boolean, string?)
	if not NetService.allow(player, "Bubble") then
		return false, "Steady on!"
	end

	local now = os.clock()
	local previous = lastFired[player]
	if previous and now - previous < Snatch.BUBBLE_COOLDOWN then
		local wait = math.ceil(Snatch.BUBBLE_COOLDOWN - (now - previous))
		return false, `Wand recharging — {wait}s`
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "Hold on a moment."
	end
	local position = root.Position

	-- The cooldown starts on the SHOT, not on a hit. Otherwise the wand is free
	-- to spam while nothing is nearby, and there is no cost to waving it about.
	lastFired[player] = now

	local ok = SnatchNpcService.bubbleNear(position)
	if ok then
		return true, nil
	end

	local hitPlayer = StealService.bubbleNear(position, player)
	if hitPlayer then
		return true, nil
	end

	return false, "Nothing in range — get closer!"
end

function BubbleService.init()
	Players.PlayerRemoving:Connect(function(player)
		lastFired[player] = nil
	end)
end

function BubbleService.start()
	local remote = Net.get("Bubble") :: RemoteFunction
	remote.OnServerInvoke = function(player)
		return BubbleService.fire(player)
	end
end

return BubbleService
