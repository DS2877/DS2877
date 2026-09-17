--!strict
--[[
	Loads, holds and saves player profiles.

	For Philip: a DataStore is a key-value database Roblox hosts for us. We ask
	for a player's row on join and write it back on leave. The calls are slow
	and can fail, so everything here assumes they will.

	WHY THIS IS HAND-WRITTEN RATHER THAN ProfileStore
	-------------------------------------------------
	ProfileStore is approved (docs/DECISIONS.md D-006) and is still the
	destination. It is not here yet for one practical reason: the Wally
	registry returns HTTP 500 for every ProfileStore/ProfileService lookup as
	of 2026-09-16, while other packages resolve fine. Blocking the first
	playable slice on a registry outage buys nothing.

	So this file keeps ProfileStore's two load-bearing behaviours -- a session
	lock and atomic writes -- behind the same shape of API, and swapping it in
	later touches this file only. That swap is its own change, so it can be the
	only variable when it lands.

	THE SESSION LOCK is the part not to simplify away. Without it, the same
	player joining two servers gets two copies of their profile and whichever
	saves last wins -- which is a duplication exploit as soon as the game has
	stealing in it.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local DataService = {}
DataService.Name = "DataService"

--- Bump to abandon every existing save. Only ever for a schema we cannot
--- migrate -- this throws away real players' progress.
local STORE_NAME = "PlayerProfiles_v1"

--- A lock older than this is assumed dead: the server holding it crashed.
--- Long enough that a slow shutdown does not look like a crash, short enough
--- that a player is not locked out of their own save for a whole session.
local LOCK_STALE_SECONDS = 180
local LOCK_REFRESH_SECONDS = 60
local AUTOSAVE_SECONDS = 120
local RETRY_DELAYS = { 1, 3, 7 }

local store = DataStoreService:GetDataStore(STORE_NAME)
local serverId = game.JobId ~= "" and game.JobId or `studio-{os.time()}`

type Session = {
	data: Profile.Data,
	--- False once the player has left and the final save has been written.
	active: boolean,
	lastSave: number,
}

local sessions: { [Player]: Session } = {}

--- Runs a DataStore call with backoff. Returns ok, result.
--- DataStore failures are routine, not exceptional -- throttling, a brief
--- outage, a bad minute. Anything that gives up on the first failure will
--- lose somebody's afternoon.
local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local lastError: any = nil
	for attempt = 0, #RETRY_DELAYS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		local delay = RETRY_DELAYS[attempt + 1]
		if delay then
			task.wait(delay)
		end
	end
	warn(`[DataService] {label} failed after {#RETRY_DELAYS + 1} attempts: {lastError}`)
	return false, nil
end

local function key(userId: number): string
	return `player_{userId}`
end

--- Claims the lock and returns the stored profile, or nil if another live
--- server holds it.
local function acquire(userId: number): Profile.Data?
	local now = os.time()
	local rejected = false

	local ok = retry(`acquire {userId}`, function()
		store:UpdateAsync(key(userId), function(old: any)
			local lock = if type(old) == "table" then old.lock else nil
			if type(lock) == "table" and lock.server ~= serverId then
				local age = now - (tonumber(lock.at) or 0)
				if age < LOCK_STALE_SECONDS then
					rejected = true
					-- Returning nil aborts the update without writing.
					return nil
				end
			end

			local updated = if type(old) == "table" then old else {}
			updated.lock = { server = serverId, at = now }
			return updated
		end)
	end)

	if not ok or rejected then
		return nil
	end

	local _, raw = retry(`read {userId}`, function()
		return store:GetAsync(key(userId))
	end)

	return Profile.migrate(raw, os.time(), Economy.INVENTORY_CAP, Economy.PEDESTALS_BASE)
end

--- Writes the profile. `release` also drops the lock, so another server can
--- pick the player up immediately rather than waiting out the stale timeout.
local function write(userId: number, data: Profile.Data, release: boolean): boolean
	data.lastSeen = os.time()
	local ok = retry(`save {userId}`, function()
		store:UpdateAsync(key(userId), function(old: any)
			-- Refuse to overwrite a save another live server owns. Without this
			-- a stale session could stamp on fresh progress.
			local lock = if type(old) == "table" then old.lock else nil
			if type(lock) == "table" and lock.server ~= serverId then
				local age = os.time() - (tonumber(lock.at) or 0)
				if age < LOCK_STALE_SECONDS then
					return nil
				end
			end

			local payload: any = table.clone(data :: any)
			payload.lock = if release then nil else { server = serverId, at = os.time() }
			return payload
		end)
	end)
	return ok
end

--- The profile for a player, or nil if it never loaded.
function DataService.get(player: Player): Profile.Data?
	local session = sessions[player]
	return if session and session.active then session.data else nil
end

function DataService.save(player: Player, release: boolean?): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	session.lastSave = os.clock()
	return write(player.UserId, session.data, release == true)
end

local onLoaded: { (Player, Profile.Data) -> () } = {}

--- Registers a callback for "this player's profile is ready". Services that
--- need the profile subscribe rather than polling, so the order they start in
--- does not matter.
function DataService.onLoaded(fn: (Player, Profile.Data) -> ())
	table.insert(onLoaded, fn)
end

local function load(player: Player)
	local data = acquire(player.UserId)

	if not data then
		-- Someone else holds the lock, or the DataStore is down. Kicking is the
		-- honest outcome: letting them play on a profile we cannot save means
		-- they lose whatever they do next, which is far worse than a message
		-- asking them to rejoin.
		player:Kick(
			"Your Nomlings are still packing up from another server.\n"
				.. "Please rejoin in a moment -- nothing has been lost."
		)
		return
	end

	-- The FTUE grant. The economy simulator has always assumed a new player
	-- starts with an egg already incubating, so every pacing number in
	-- docs/ECONOMY.md depends on it; the game simply never did it, leaving a
	-- new profile with 0 coins, 0 income and no way to afford the cheapest egg.
	if Economy.STARTER_EGG then
		local granted = Profile.grantStarterEgg(
			data,
			Economy.STARTER_EGG,
			os.time() + Economy.FIRST_EGG_HATCH_SECONDS,
			Economy.FIRST_EGG_HATCH_SECONDS
		)
		if granted then
			print(`[DataService] {player.Name} starts with a free {Economy.STARTER_EGG} egg`)
		end
	end

	sessions[player] = { data = data, active = true, lastSave = os.clock() }
	for _, fn in onLoaded do
		local ok, err = pcall(fn, player, data)
		if not ok then
			warn(`[DataService] onLoaded callback failed for {player.Name}: {err}`)
		end
	end
end

local function unload(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.active = false
	write(player.UserId, session.data, true)
	sessions[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(unload, player)
	end)
end

function DataService.start()
	-- Players who joined before this service started (Studio, or a very fast
	-- join) still need loading.
	for _, player in Players:GetPlayers() do
		if not sessions[player] then
			task.spawn(load, player)
		end
	end

	task.spawn(function()
		while true do
			task.wait(LOCK_REFRESH_SECONDS)
			for player, session in sessions do
				if not session.active then
					continue
				end
				local due = os.clock() - session.lastSave >= AUTOSAVE_SECONDS
				-- Refresh the lock even when there is nothing new to save, or a
				-- long quiet session looks abandoned and another server steals it.
				write(player.UserId, session.data, false)
				if due then
					session.lastSave = os.clock()
				end
			end
		end
	end)

	game:BindToClose(function()
		-- Roblox gives a shutting-down server a short grace period. Save
		-- everyone in parallel; serially would run out of time with a full server.
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				unload(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
		if not RunService:IsStudio() then
			task.wait(1)
		end
	end)
end

return DataService
