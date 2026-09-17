--!strict
local h = require("./helpers")
local Economy = require("../../src/shared/Config/Economy")
local World = require("../../src/shared/Config/World")

h.suite("Base furniture")

--- Half-extent of one pedestal, in both directions.
local PEDESTAL_HALF = World.PEDESTAL_WIDTH / 2

--- Do two axis-aligned boxes, given as centre and half-extents, overlap?
local function overlaps(
	ax: number,
	az: number,
	ahx: number,
	ahz: number,
	bx: number,
	bz: number,
	bhx: number,
	bhz: number
): boolean
	return math.abs(ax - bx) < ahx + bhx and math.abs(az - bz) < ahz + bhz
end

h.test("the egg bench does not stand on a pedestal", function()
	-- The bench was placed by arithmetic rather than by eye, because there is no
	-- Studio in this project and a pedestal growing up through a bench is
	-- exactly the sort of thing that comes back as "the base looks broken" and
	-- costs a screenshot round-trip to find.
	--
	-- The trap here is that the pedestals are a RING -- radius 0.32 x the pad's
	-- shorter side, eight positions at 45 degrees -- and nothing in the name
	-- PEDESTAL_ROWS or PEDESTAL_COLUMNS says so. The first placement cleared
	-- them, but only by 1.3 studs, which is luck rather than design. This pins
	-- it, so moving either one is a failed test rather than a surprise.
	local nest = World.nestFootprint(1)
	for _, side in { -1, 1 } do
		local footprint = World.nestFootprint(side)
		for i, pedestal in World.pedestalRing(Economy.PEDESTALS_BASE) do
			h.expectTrue(
				not overlaps(
					footprint.x,
					footprint.z,
					footprint.halfDepth,
					footprint.halfLength,
					pedestal.x,
					pedestal.z,
					PEDESTAL_HALF,
					PEDESTAL_HALF
				),
				`side {side}: the bench overlaps pedestal {i} at ({pedestal.x}, {pedestal.z})`
			)
		end
	end
	h.expectTrue(nest.halfDepth > 0, "the bench has a footprint at all")
end)

h.test("the egg bench clears the awning posts", function()
	-- The posts run the full frontage, so this is a one-dimensional check: the
	-- bench's far edge against the posts' near edge.
	for _, side in { -1, 1 } do
		local footprint = World.nestFootprint(side)
		local benchFar = math.abs(footprint.x) + footprint.halfDepth
		local postNear = World.BASE_DEPTH / 2 - World.AWNING_INSET - World.AWNING_POST_WIDTH / 2
		h.expectTrue(
			benchFar < postNear,
			`side {side}: bench reaches {benchFar}, the awning posts start at {postNear}`
		)
	end
end)

h.test("the egg bench holds every cup it has to", function()
	-- INCUBATORS_MAX cups at NEST_CUP_PITCH, and they must fit on the bench
	-- with the cups themselves counted, not just their centres.
	local span = (Economy.INCUBATORS_MAX - 1) * World.NEST_CUP_PITCH + World.NEST_CUP
	h.expectTrue(
		span <= World.NEST_LENGTH,
		`{Economy.INCUBATORS_MAX} cups need {span} studs, the bench is {World.NEST_LENGTH}`
	)
	h.expectTrue(
		World.NEST_CUP < World.NEST_DEPTH,
		`a {World.NEST_CUP}-stud cup hangs off a {World.NEST_DEPTH}-stud bench`
	)
end)

h.test("the egg bench does not sit on the path", function()
	-- The path is 10 studs wide down the middle of the base, and the bench is
	-- meant to be BESIDE it: you walk in and it is there, not in the way.
	local footprint = World.nestFootprint(-1)
	local benchEdge = footprint.z + footprint.halfLength
	h.expectTrue(benchEdge < -5, `the bench reaches z {benchEdge}; the path ends at -5`)
end)

h.test("the awning clears a jumping player", function()
	-- R15 stands about 5.5 studs to the top of the head and jumps about 7.2, so
	-- the lowest thing hanging off the awning has to clear roughly 12.7. This is
	-- the whole reason the awning was raised when it was rebuilt: a solid canopy
	-- you knock your head on every time you run home is worse than a ghost one.
	local lowest = World.AWNING_LIP - World.AWNING_BEAM_H - World.AWNING_VALANCE_H
	h.expectTrue(lowest > 12.7, `the valance hangs to {lowest}, inside a 12.7-stud jump`)
end)
