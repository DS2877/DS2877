--!strict
local h = require("./helpers")
local World = require("../../src/shared/Config/World")

h.suite("World layout")

h.test("REGRESSION: every base is reachable on foot from every other", function()
	-- The first playtest failed on exactly this: a ring of pads with gaps
	-- between them, so no player could reach another player's base and the
	-- stealing half of the game could not be played at all.
	--
	-- The test is that all bases share one connected ground plane: they all sit
	-- against the same road, and the road spans them.
	local minZ, maxZ = math.huge, -math.huge
	for index = 1, World.BASE_COUNT do
		local x, z = World.baseCenter(index)
		-- Every base must touch the kerb, not float away from the road.
		local nearEdge = math.abs(x) - World.BASE_DEPTH / 2
		h.expectNear(nearEdge, World.KERB_X, 0.001, `base {index} must meet the kerb`)
		minZ = math.min(minZ, z - World.BASE_WIDTH / 2)
		maxZ = math.max(maxZ, z + World.BASE_WIDTH / 2)
	end
	h.expectTrue(
		World.STREET_LENGTH >= maxZ - minZ,
		`the road ({World.STREET_LENGTH}) must span every base ({maxZ - minZ})`
	)
end)

h.test("bases do not overlap each other", function()
	for a = 1, World.BASE_COUNT do
		for b = a + 1, World.BASE_COUNT do
			local ax, az = World.baseCenter(a)
			local bx, bz = World.baseCenter(b)
			local sameSide = (ax < 0) == (bx < 0)
			if sameSide then
				local gap = math.abs(az - bz) - World.BASE_WIDTH
				h.expectTrue(gap >= 0, `bases {a} and {b} overlap by {-gap} studs`)
			end
		end
	end
end)

h.test("no base overlaps the road", function()
	for index = 1, World.BASE_COUNT do
		local x = World.baseCenter(index)
		local nearEdge = math.abs(x) - World.BASE_DEPTH / 2
		h.expectTrue(nearEdge >= World.STREET_WIDTH / 2 - 0.001, `base {index} juts into the road`)
	end
end)

h.test("a base holds exactly the configured pedestals", function()
	local offsets = World.pedestalOffsets()
	h.expectEqual(#offsets, World.PEDESTAL_ROWS * World.PEDESTAL_COLUMNS, "pedestal count")
	for i, offset in offsets do
		h.expectTrue(
			math.abs(offset.x) <= World.BASE_DEPTH / 2
				and math.abs(offset.z) <= World.BASE_WIDTH / 2,
			`pedestal {i} sits outside its own base`
		)
	end
end)

h.test("a player spawns inside their own base and nobody else's", function()
	for index = 1, World.BASE_COUNT do
		local x, z = World.spawnCFrame(index)
		h.expectTrue(World.isInsideBase(index, x, z), `base {index} spawn is outside its base`)
		for other = 1, World.BASE_COUNT do
			if other ~= index then
				h.expectTrue(
					not World.isInsideBase(other, x, z),
					`base {index} spawn lands inside base {other}`
				)
			end
		end
	end
end)

h.test("the belt fits inside the road", function()
	h.expectTrue(World.BELT_WIDTH < World.STREET_WIDTH, "the belt must leave room to walk past it")
end)

h.test("REGRESSION: the pedestal grid matches the economy's pedestal count", function()
	-- World lays pedestals out as a ROWS x COLUMNS grid while Economy caps how
	-- many a player may fill. If they disagree, either a base has pedestals no
	-- player can ever use, or Profile.place accepts an index with no post under
	-- it and a Nomling is placed into thin air. Neither shows up as an error.
	local Economy = require("../../src/shared/Config/Economy")
	local offsets = World.pedestalOffsets()
	h.expectEqual(
		#offsets,
		Economy.PEDESTALS_BASE,
		`grid is {World.PEDESTAL_ROWS}x{World.PEDESTAL_COLUMNS} but PEDESTALS_BASE is {Economy.PEDESTALS_BASE}`
	)
end)
