--!strict
--[[
	The saved profile: its shape, its defaults, and every legal mutation.

	For Philip: this is the player's save file. A DataStore is roughly a
	key-value database -- we hand it one table per player and get the same table
	back next session. Everything the player keeps lives in here.

	Two rules make this module what it is.

	1. It is DEPENDENCY-FREE (CLAUDE.md), so Lune can test it without a
	   DataModel. Anything needing economy numbers takes them as arguments
	   rather than requiring Config -- the caller wires the two together.

	2. `sanitize` never rejects. A profile can come back from the DataStore
	   truncated, from an older schema, or -- if we ever ship a bug -- plain
	   wrong. Refusing to load it means a player permanently cannot enter the
	   game, which is far worse than silently repairing it. Every field is
	   rebuilt from scratch and anything unrecognised is dropped.
]]

local Profile = {}

--- Bump when the shape changes, and add a step to `migrate`.
Profile.VERSION = 1

export type Nomling = {
	id: string,
	snack: string,
	animal: string,
	gen: number,
	affix: string?,
	mutation: string?,
	rarity: string,
	seed: number,
}

export type Incubator = {
	eggKey: string,
	--- os.time() at which it may be claimed.
	readyAt: number,
}

export type Data = {
	version: number,
	coins: number,
	rebirths: number,
	--- Everything owned, placed or not.
	nomlings: { Nomling },
	--- pedestal index (1-based, as a string key) -> nomling id.
	--- A string key because DataStores turn sparse arrays into objects anyway,
	--- and a sparse Luau array silently breaks `#`.
	pedestals: { [string]: string },
	incubators: { Incubator },
	--- os.time() of the last save. Drives offline income.
	lastSeen: number,
	stats: { hatched: number, placed: number, coinsEarned: number, playtime: number },
	--- Monotonic, so a Nomling id is never reused within a profile.
	nextId: number,
}

function Profile.new(now: number): Data
	return {
		version = Profile.VERSION,
		coins = 0,
		rebirths = 0,
		nomlings = {},
		pedestals = {},
		incubators = {},
		lastSeen = now,
		stats = { hatched = 0, placed = 0, coinsEarned = 0, playtime = 0 },
		nextId = 1,
	}
end

-- --- helpers ---------------------------------------------------------------

local function num(value: any, fallback: number, min: number?, max: number?): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	local result = value
	if min and result < min then
		result = min
	end
	if max and result > max then
		result = max
	end
	return result
end

local function str(value: any): string?
	return if type(value) == "string" and #value > 0 and #value <= 64 then value else nil
end

-- --- sanitize --------------------------------------------------------------

--- Turns anything at all into a valid profile. Never errors, never returns nil.
--- `inventoryCap` and `pedestalCount` come from Config (the caller supplies
--- them so this module stays dependency-free).
function Profile.sanitize(raw: any, now: number, inventoryCap: number, pedestalCount: number): Data
	if type(raw) ~= "table" then
		return Profile.new(now)
	end

	local clean = Profile.new(now)
	clean.coins = num(raw.coins, 0, 0)
	clean.rebirths = math.floor(num(raw.rebirths, 0, 0, 1000))
	clean.lastSeen = math.floor(num(raw.lastSeen, now, 0))
	clean.version = Profile.VERSION

	local stats = if type(raw.stats) == "table" then raw.stats else {}
	clean.stats = {
		hatched = math.floor(num(stats.hatched, 0, 0)),
		placed = math.floor(num(stats.placed, 0, 0)),
		coinsEarned = num(stats.coinsEarned, 0, 0),
		-- Drives the newcomer shield, so it must never come back negative:
		-- that would leave a veteran permanently unsnatchable.
		playtime = num(stats.playtime, 0, 0),
	}

	-- Nomlings. An entry missing an id, a snack or an animal cannot be rendered
	-- or named, so it is dropped rather than carried as a broken creature.
	local seen: { [string]: boolean } = {}
	local highest = 0
	if type(raw.nomlings) == "table" then
		for _, entry in raw.nomlings :: any do
			if #clean.nomlings >= inventoryCap then
				break
			end
			if type(entry) ~= "table" then
				continue
			end
			local id, snack, animal = str(entry.id), str(entry.snack), str(entry.animal)
			if not id or not snack or not animal or seen[id] then
				continue
			end
			seen[id] = true
			local numeric = tonumber(id)
			if numeric and numeric > highest then
				highest = numeric
			end
			table.insert(clean.nomlings, {
				id = id,
				snack = snack,
				animal = animal,
				gen = math.floor(num(entry.gen, 1, 1, 3)),
				affix = str(entry.affix),
				mutation = str(entry.mutation),
				rarity = str(entry.rarity) or "common",
				seed = math.floor(num(entry.seed, 0, 0)),
			})
		end
	end
	clean.nextId = math.max(math.floor(num(raw.nextId, 1, 1)), highest + 1)

	-- Pedestals. A slot pointing at a Nomling that no longer exists, or at one
	-- already standing on another slot, is dropped -- duplicating a creature
	-- across two pedestals would double its income for free.
	local placed: { [string]: boolean } = {}
	if type(raw.pedestals) == "table" then
		for key, id in raw.pedestals :: any do
			local index = tonumber(key)
			if not index or index < 1 or index > pedestalCount or index % 1 ~= 0 then
				continue
			end
			local nomlingId = str(id)
			if not nomlingId or not seen[nomlingId] or placed[nomlingId] then
				continue
			end
			placed[nomlingId] = true
			clean.pedestals[tostring(math.floor(index))] = nomlingId
		end
	end

	if type(raw.incubators) == "table" then
		for _, entry in raw.incubators :: any do
			if type(entry) ~= "table" then
				continue
			end
			local eggKey = str(entry.eggKey)
			if eggKey then
				table.insert(clean.incubators, {
					eggKey = eggKey,
					readyAt = math.floor(num(entry.readyAt, now, 0)),
				})
			end
		end
	end

	return clean
end

--- Applies any schema migrations, then sanitizes. This is what DataService calls.
function Profile.migrate(raw: any, now: number, inventoryCap: number, pedestalCount: number): Data
	-- Version 1 is the first schema, so there is nothing to step through yet.
	-- When VERSION becomes 2, transform the table here BEFORE sanitizing --
	-- sanitize only knows the current shape and would drop what it cannot read.
	return Profile.sanitize(raw, now, inventoryCap, pedestalCount)
end

-- --- mutations -------------------------------------------------------------

function Profile.addCoins(data: Data, amount: number): number
	if amount <= 0 or amount ~= amount then
		return data.coins
	end
	data.coins += amount
	data.stats.coinsEarned += amount
	return data.coins
end

--- Spends only if affordable. Returns whether it happened -- callers MUST
--- check, because "did the purchase go through" is the whole question.
function Profile.spendCoins(data: Data, amount: number): boolean
	if amount < 0 or amount ~= amount or data.coins < amount then
		return false
	end
	data.coins -= amount
	return true
end

function Profile.findNomling(data: Data, id: string): Nomling?
	for _, nomling in data.nomlings do
		if nomling.id == id then
			return nomling
		end
	end
	return nil
end

--- Allocates the next id and adds the creature. Returns nil when the inventory
--- is full, which the caller must surface rather than silently discarding.
function Profile.addNomling(data: Data, nomling: Nomling, inventoryCap: number): Nomling?
	if #data.nomlings >= inventoryCap then
		return nil
	end
	local stored: Nomling = {
		id = tostring(data.nextId),
		snack = nomling.snack,
		animal = nomling.animal,
		gen = nomling.gen,
		affix = nomling.affix,
		mutation = nomling.mutation,
		rarity = nomling.rarity,
		seed = nomling.seed,
	}
	data.nextId += 1
	table.insert(data.nomlings, stored)
	data.stats.hatched += 1
	return stored
end

function Profile.pedestalOf(data: Data, nomlingId: string): number?
	for key, id in data.pedestals do
		if id == nomlingId then
			return tonumber(key)
		end
	end
	return nil
end

--- Places a Nomling on a pedestal. Returns ok, reason.
--- Every failure is named, because these reasons become player-facing text and
--- "something went wrong" is not an acceptable message for a child.
function Profile.place(
	data: Data,
	nomlingId: string,
	index: number,
	pedestalCount: number
): (boolean, string?)
	if index % 1 ~= 0 or index < 1 or index > pedestalCount then
		return false, "That pedestal does not exist."
	end
	if not Profile.findNomling(data, nomlingId) then
		return false, "You do not own that Nomling."
	end
	local key = tostring(index)
	if data.pedestals[key] then
		return false, "That pedestal is taken."
	end
	local already = Profile.pedestalOf(data, nomlingId)
	if already then
		return false, "That Nomling is already out."
	end
	data.pedestals[key] = nomlingId
	data.stats.placed += 1
	return true, nil
end

function Profile.unplace(data: Data, index: number): string?
	local key = tostring(index)
	local id = data.pedestals[key]
	data.pedestals[key] = nil
	return id
end

--- True when the profile has nothing at all: no coins, no creatures, no egg on
--- the way. Such a player cannot earn and cannot buy, so they are stuck on the
--- first screen forever.
---
--- Deliberately a state test rather than an "is this a new profile?" flag. It
--- also catches anyone ALREADY stranded by an earlier build, and it cannot
--- hand a second free egg to someone who simply spent down to zero -- they
--- still have a Nomling earning, or an egg incubating.
function Profile.isStranded(data: Data): boolean
	return data.coins <= 0
		and #data.nomlings == 0
		and #data.incubators == 0
		and next(data.pedestals) == nil
end

--- Gives a starting egg, already incubating. Returns whether it was given.
function Profile.grantStarterEgg(data: Data, eggKey: string, readyAt: number): boolean
	if not Profile.isStranded(data) then
		return false
	end
	table.insert(data.incubators, { eggKey = eggKey, readyAt = readyAt })
	return true
end

function Profile.placedNomlings(data: Data): { Nomling }
	local result: { Nomling } = {}
	for _, id in data.pedestals do
		local nomling = Profile.findNomling(data, id)
		if nomling then
			table.insert(result, nomling)
		end
	end
	return result
end

return Profile
