--!strict
local h = require("./helpers")
local Profile = require("../../src/shared/Logic/Profile")
local Economy = require("../../src/shared/Config/Economy")

h.suite("Profile")

local CAP = Economy.INVENTORY_CAP
local PEDS = Economy.PEDESTALS_BASE
local NOW = 1_700_000_000

local function creature(snack: string, animal: string, rarity: string): Profile.Nomling
	return {
		id = "", -- assigned by addNomling
		snack = snack,
		animal = animal,
		gen = 1,
		affix = nil,
		mutation = nil,
		rarity = rarity,
		seed = 1234,
	}
end

-- This runs FIRST on purpose, before any test has called sanitize.
--
-- A real bug lived here: an edit anchored on "return Profile" matched the FIRST
-- occurrence in the file, which is `return Profile.new(now)` inside sanitize --
-- so Profile.rebirth was being DEFINED INSIDE A CONDITIONAL BRANCH. It existed
-- only after sanitize had been called with a non-table. New players took that
-- branch, so it worked for them; an existing player's Re-Nom would have called
-- a nil value. Nothing in the suite caught it, because an earlier test happened
-- to call sanitize with a non-table first.
h.test("REGRESSION: every exported function exists at module scope", function()
	for _, name in
		{
			"new",
			"sanitize",
			"migrate",
			"addCoins",
			"spendCoins",
			"findNomling",
			"addNomling",
			"pedestalOf",
			"place",
			"unplace",
			"placedNomlings",
			"isStranded",
			"grantStarterEgg",
			"rebirth",
			"discover",
			"bookCount",
		}
	do
		h.expectEqual(
			type((Profile :: any)[name]),
			"function",
			`Profile.{name} is missing -- is it nested inside another function?`
		)
	end
end)

h.test("a new profile is empty and valid", function()
	local data = Profile.new(NOW)
	h.expectEqual(data.coins, 0, "coins")
	h.expectEqual(#data.nomlings, 0, "nomlings")
	h.expectEqual(data.version, Profile.VERSION, "version")
end)

h.test("coins cannot be spent below zero", function()
	local data = Profile.new(NOW)
	Profile.addCoins(data, 100)
	h.expectTrue(not Profile.spendCoins(data, 101), "overspend must be refused")
	h.expectEqual(data.coins, 100, "balance after refused spend")
	h.expectTrue(Profile.spendCoins(data, 100), "exact spend must succeed")
	h.expectEqual(data.coins, 0, "balance after exact spend")
end)

h.test("negative and NaN amounts cannot mint coins", function()
	local data = Profile.new(NOW)
	Profile.addCoins(data, -500)
	h.expectEqual(data.coins, 0, "negative add")
	Profile.addCoins(data, 0 / 0)
	h.expectEqual(data.coins, 0, "NaN add")
	-- A negative spend would otherwise be a free deposit.
	h.expectTrue(not Profile.spendCoins(data, -500), "negative spend must be refused")
	h.expectEqual(data.coins, 0, "balance after negative spend")
end)

h.test("ids are never reused within a profile", function()
	local data = Profile.new(NOW)
	local a = Profile.addNomling(data, creature("taco", "rhino", "common"), CAP)
	local b = Profile.addNomling(data, creature("sushi", "pup", "rare"), CAP)
	assert(a and b, "addNomling returned nil")
	h.expectTrue(a.id ~= b.id, "two creatures share an id")
	-- Remove the first, add a third: the id must not be recycled, or a stale
	-- pedestal reference would silently point at the wrong creature.
	table.remove(data.nomlings, 1)
	local c = Profile.addNomling(data, creature("pizza", "penguin", "epic"), CAP)
	assert(c, "addNomling returned nil")
	h.expectTrue(c.id ~= a.id, "id was recycled after a removal")
end)

h.test("REGRESSION: one Nomling cannot stand on two pedestals", function()
	-- Placing the same creature twice would double its income for free, which
	-- is a duplication exploit dressed up as a UI bug.
	local data = Profile.new(NOW)
	local n = Profile.addNomling(data, creature("taco", "rhino", "legendary"), CAP)
	assert(n, "addNomling returned nil")
	local ok1 = Profile.place(data, n.id, 1, PEDS)
	h.expectTrue(ok1, "first placement should succeed")
	local ok2, reason = Profile.place(data, n.id, 2, PEDS)
	h.expectTrue(not ok2, "second placement must be refused")
	h.expectTrue(reason ~= nil, "a refusal must name a reason")
end)

h.test("a pedestal cannot hold a Nomling you do not own", function()
	local data = Profile.new(NOW)
	local ok, reason = Profile.place(data, "999", 1, PEDS)
	h.expectTrue(not ok, "placing an unowned creature must be refused")
	h.expectTrue(reason ~= nil, "a refusal must name a reason")
end)

h.test("pedestal indexes outside the base are refused", function()
	local data = Profile.new(NOW)
	local n = Profile.addNomling(data, creature("mochi", "mole", "common"), CAP)
	assert(n, "addNomling returned nil")
	for _, bad in { 0, -1, PEDS + 1, 1.5 } do
		local ok = Profile.place(data, n.id, bad, PEDS)
		h.expectTrue(not ok, `pedestal index {bad} should be refused`)
	end
end)

h.test("inventory cap is enforced", function()
	local data = Profile.new(NOW)
	for _ = 1, CAP do
		Profile.addNomling(data, creature("taco", "rhino", "common"), CAP)
	end
	h.expectEqual(#data.nomlings, CAP, "inventory should be full")
	h.expectEqual(
		Profile.addNomling(data, creature("sushi", "pup", "common"), CAP),
		nil,
		"overflow"
	)
end)

-- --- sanitize: the load path -------------------------------------------------

h.test("sanitize never rejects, whatever it is handed", function()
	for _, junk in { nil, 5, "hello", true, {}, { coins = "lots" } } do
		local data = Profile.sanitize(junk, NOW, CAP, PEDS)
		h.expectEqual(type(data), "table", "sanitize must return a table")
		h.expectEqual(type(data.coins), "number", "coins must be a number")
		h.expectTrue(data.coins >= 0, "coins must not be negative")
	end
end)

h.test("REGRESSION: a corrupt save cannot lock a player out", function()
	-- Refusing to load means the player can never enter the game again. Every
	-- field here is wrong in a different way and all of them must be survivable.
	local data = Profile.sanitize({
		version = 99,
		coins = 0 / 0,
		rebirths = -5,
		nomlings = { 7, "x", {}, { id = "1", snack = "taco" } },
		pedestals = { ["1"] = "nope", bad = "1", ["999"] = "1" },
		incubators = { 1, { eggKey = "basic", readyAt = "soon" } },
		stats = "gone",
		nextId = -3,
	}, NOW, CAP, PEDS)

	h.expectEqual(data.coins, 0, "NaN coins must become 0")
	h.expectEqual(data.rebirths, 0, "negative rebirths must clamp to 0")
	h.expectEqual(#data.nomlings, 0, "entries missing an animal must be dropped")
	h.expectEqual(next(data.pedestals), nil, "pedestals pointing at nothing must be dropped")
	h.expectEqual(#data.incubators, 1, "the one valid incubator survives")
	h.expectEqual(data.stats.hatched, 0, "missing stats are rebuilt")
	h.expectTrue(data.nextId >= 1, "nextId must stay usable")
end)

h.test("REGRESSION: a tampered save cannot duplicate a Nomling", function()
	-- Two pedestals pointing at the same creature is the shape a duplication
	-- exploit would take on the way back in through the save file.
	local data = Profile.sanitize({
		nomlings = { { id = "1", snack = "taco", animal = "rhino", rarity = "mythic" } },
		pedestals = { ["1"] = "1", ["2"] = "1", ["3"] = "1" },
	}, NOW, CAP, PEDS)

	local count = 0
	for _ in data.pedestals do
		count += 1
	end
	h.expectEqual(count, 1, "the same creature must occupy exactly one pedestal")
	h.expectEqual(#Profile.placedNomlings(data), 1, "placed list must not duplicate")
end)

h.test("sanitize truncates an oversized inventory rather than failing", function()
	local raw = { nomlings = {} }
	for i = 1, CAP + 50 do
		table.insert(raw.nomlings, {
			id = tostring(i),
			snack = "taco",
			animal = "rhino",
			rarity = "common",
		})
	end
	local data = Profile.sanitize(raw, NOW, CAP, PEDS)
	h.expectEqual(#data.nomlings, CAP, "inventory must be capped on load")
end)

h.test("sanitize round-trips a healthy save unchanged", function()
	local original = Profile.new(NOW)
	Profile.addCoins(original, 12345)
	local n = Profile.addNomling(original, creature("waffle", "walrus", "epic"), CAP)
	assert(n, "addNomling returned nil")
	Profile.place(original, n.id, 3, PEDS)

	local restored = Profile.sanitize(original, NOW, CAP, PEDS)
	h.expectEqual(restored.coins, 12345, "coins")
	h.expectEqual(#restored.nomlings, 1, "nomlings")
	h.expectEqual(restored.pedestals["3"], n.id, "pedestal 3")
	h.expectEqual(restored.nomlings[1].rarity, "epic", "rarity")
end)

h.test("REGRESSION: a new player cannot be stranded on the first screen", function()
	-- The mirror of the rebirth soft-lock (docs/DECISIONS.md D-008). A fresh
	-- profile has no coins and no income, and every egg costs coins, so without
	-- the starter grant the player can never take a single action. The economy
	-- simulator has always assumed this egg exists.
	local data = Profile.new(NOW)
	h.expectTrue(Profile.isStranded(data), "a fresh profile is stranded without a grant")
	h.expectTrue(Economy.STARTER_EGG ~= nil, "STARTER_EGG must exist or the FTUE dead-ends")

	local granted = Profile.grantStarterEgg(data, Economy.STARTER_EGG, NOW + 5, 5)
	h.expectTrue(granted, "the grant must apply to a fresh profile")
	h.expectTrue(not Profile.isStranded(data), "the grant must un-strand the player")
end)

h.test("the starter egg is granted once, not on every join", function()
	local data = Profile.new(NOW)
	h.expectTrue(Profile.grantStarterEgg(data, "basic", NOW + 5, 5), "first grant")
	h.expectTrue(
		not Profile.grantStarterEgg(data, "basic", NOW + 5, 5),
		"second grant must be refused"
	)
	h.expectEqual(#data.incubators, 1, "only one starting egg")
end)

h.test("a player who spent down to zero is not stranded", function()
	-- Someone with a Nomling earning, or an egg on the way, still has a path
	-- forward and must not collect a second free egg.
	local withNomling = Profile.new(NOW)
	local n = Profile.addNomling(withNomling, creature("taco", "rhino", "common"), CAP)
	assert(n, "addNomling returned nil")
	h.expectTrue(not Profile.isStranded(withNomling), "owning a Nomling is not stranded")

	local withEgg = Profile.new(NOW)
	table.insert(withEgg.incubators, { eggKey = "basic", readyAt = NOW + 10, total = 10 })
	h.expectTrue(not Profile.isStranded(withEgg), "an incubating egg is not stranded")
end)

h.test("an incubator saved before `total` existed still loads", function()
	-- The field was added after the first playtest. A profile written by the
	-- previous build has no `total`, and dividing by it would be a division by
	-- zero on the client's progress bar.
	local data = Profile.sanitize({
		incubators = { { eggKey = "basic", readyAt = NOW + 30 } },
	}, NOW, CAP, PEDS)
	h.expectEqual(#data.incubators, 1, "the incubator should survive")
	h.expectTrue(data.incubators[1].total >= 1, "total must never be zero or nil")
end)

h.test("rebirth clears the base and raises the multiplier", function()
	local data = Profile.new(NOW)
	Profile.addCoins(data, Economy.rebirthCost(0))
	local n = Profile.addNomling(data, creature("taco", "rhino", "mythic"), CAP)
	assert(n, "addNomling returned nil")
	Profile.place(data, n.id, 1, PEDS)
	table.insert(data.incubators, { eggKey = "basic", readyAt = NOW + 10, total = 10 })

	h.expectTrue(Profile.rebirth(data, Economy.rebirthCost(0)), "affordable rebirth should succeed")
	h.expectEqual(data.coins, 0, "coins cleared")
	h.expectEqual(#data.nomlings, 0, "nomlings cleared")
	h.expectEqual(next(data.pedestals), nil, "pedestals cleared")
	h.expectEqual(#data.incubators, 0, "incubators cleared")
	h.expectEqual(data.rebirths, 1, "rebirth counted")
	h.expectTrue(
		Economy.rebirthMultiplier(1) > Economy.rebirthMultiplier(0),
		"the multiplier must actually go up"
	)
end)

h.test("rebirth is refused when it cannot be afforded", function()
	local data = Profile.new(NOW)
	Profile.addCoins(data, Economy.rebirthCost(0) - 1)
	h.expectTrue(
		not Profile.rebirth(data, Economy.rebirthCost(0)),
		"one coin short must be refused"
	)
	h.expectEqual(data.rebirths, 0, "and must not count")
	h.expectTrue(data.coins > 0, "and must not take the coins")
end)

h.test("REGRESSION: a rebirthed player is stranded until granted an egg", function()
	-- This is D-008 as an executable statement. Rebirth leaves coins and
	-- income at zero and every egg costs coins, so the grant is not a nicety --
	-- without it the player can never act again.
	local data = Profile.new(NOW)
	Profile.addCoins(data, Economy.rebirthCost(0))
	Profile.rebirth(data, Economy.rebirthCost(0))
	h.expectTrue(Profile.isStranded(data), "a freshly rebirthed profile is stranded")
	h.expectTrue(
		Profile.grantStarterEgg(data, Economy.STARTER_EGG, NOW + 5, 5),
		"the grant must apply after a rebirth"
	)
	h.expectTrue(not Profile.isStranded(data), "and must un-strand them")
end)

h.test("each rebirth unlocks at least one new egg tier eventually", function()
	-- Rebirth has to open something, or the multiplier is the only reward and
	-- the shop never changes.
	local unlockedAt: { [number]: number } = {}
	for _, egg in Economy.EGGS do
		unlockedAt[egg.unlockRebirth] = (unlockedAt[egg.unlockRebirth] or 0) + 1
	end
	h.expectTrue(unlockedAt[0] ~= nil, "something must be available at rebirth 0")
	local tiers = 0
	for _ in unlockedAt do
		tiers += 1
	end
	h.expectTrue(tiers >= 3, `only {tiers} distinct unlock points across the egg tiers`)
end)

h.test("the Fusion Book records a discovery once", function()
	local data = Profile.new(NOW)
	h.expectEqual(Profile.bookCount(data), 0, "a new book is empty")
	h.expectTrue(Profile.discover(data, "g2:sushi-walrus"), "first sighting is a discovery")
	h.expectTrue(not Profile.discover(data, "g2:sushi-walrus"), "second sighting is not")
	h.expectEqual(Profile.bookCount(data), 1, "and is only counted once")
end)

h.test("REGRESSION: Re-Nom never takes the Fusion Book", function()
	-- Coins and creatures are the price of a rebirth. What a player has
	-- DISCOVERED is not -- it is the one thing they cannot be asked to give up
	-- twice, and losing it would make every rebirth feel like a punishment.
	local data = Profile.new(NOW)
	Profile.discover(data, "g2:sushi-walrus")
	Profile.discover(data, "species:taco_rhino")
	Profile.addCoins(data, Economy.rebirthCost(0))

	Profile.rebirth(data, Economy.rebirthCost(0))
	h.expectEqual(Profile.bookCount(data), 2, "the book must survive a rebirth")
	h.expectTrue(data.book["g2:sushi-walrus"], "and keep its entries")
end)

h.test("a tampered book cannot grow without bound", function()
	local raw = { book = {} }
	for i = 1, 20000 do
		raw.book[`k{i}`] = true
	end
	raw.book[string.rep("x", 200)] = true
	local data = Profile.sanitize(raw, NOW, CAP, PEDS)
	h.expectTrue(Profile.bookCount(data) <= 8000, "the book must be bounded on load")
	h.expectTrue(not data.book[string.rep("x", 200)], "an absurd key must be dropped")
end)
