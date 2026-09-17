--!strict
--[[
	The shape of the world, in studs.

	THE LAYOUT CHANGED AFTER THE FIRST PLAYTEST. The GDD described "8 plots
	around a central plaza" (docs/GDD.md 5.1). Built, that gave eight pads in a
	ring with nothing but empty space between them -- you could not walk to
	anyone else's base, which makes a game about stealing from each other
	impossible to play.

	The genre's layout is a STREET: one long road with a delivery belt running
	down the middle and bases lining both sides, all at ground level and all
	open to the road. Every base is a short run from every other base, the belt
	is visible from everywhere, and stealing is a thing you can physically do.

	DEPENDENCY-FREE so Lune can test the layout maths.
]]

local World = {}

--- The road runs along Z. X is across it: negative is the west side, positive
--- the east. Everything is at ground level -- no stairs, no ramps, nothing a
--- phone player has to aim at.
World.STREET_LENGTH = 520
World.STREET_WIDTH = 52

--- The delivery belt, down the centre of the road.
World.BELT_WIDTH = 18
World.BELT_HEIGHT = 1.2

--- How high above the belt surface a Nomling rides.
---
--- Not decoration: a creature at belt level sits along the bottom edge of a
--- phone screen, which is exactly where the button bar is. Lifting it puts it
--- in the middle of the frame where it can be seen, wanted and raced for.
--- How far a riding Nomling's FEET sit above the belt's top surface. A
--- Nomling's model origin is between its feet (NomlingSpec), so this is
--- genuinely a ground clearance and not a hover height.
---
--- It was 3.2 and they floated: "the nomlings going on the band is elevating,
--- can we have them walk instead?" Riding three studs above a conveyor reads
--- as levitation, and no amount of animation fixes a creature that is visibly
--- not touching anything.
World.BELT_RIDE_HEIGHT = 0.1

--- Where the arrivals board stands, along the street.
---
--- The arrival end, a little past the player spawn: this is where Nomlings
--- join the belt and where every player appears, so it is the one spot the
--- whole server walks past. The board used to sit at z = 0, 240 studs away,
--- which is how a leaderboard can exist for days without anyone seeing it.
World.BOARD_Z = -World.STREET_LENGTH / 2 + 46

--- Belt Nomlings render this much larger than the same creature on a pedestal.
--- The belt is the shop window; it has to read from across the street.
World.BELT_DISPLAY_SCALE = 1.55
--- Studs per second a Nomling travels. Slow enough to read the sign and decide,
--- fast enough that a bad one clears quickly.
--- Studs per second along the belt. Slower than it looks like it should be,
--- on purpose: this is the shop window, and a player has to have time to read
--- a nameplate, decide, and walk over before it is gone.
World.BELT_SPEED = 4.5

World.BASES_PER_SIDE = 4
World.BASE_COUNT = World.BASES_PER_SIDE * 2
--- Frontage along the road, and how far back the base goes from the kerb.
World.BASE_WIDTH = 108
World.BASE_DEPTH = 76
--- Gap between neighbouring bases, so it is obvious where one ends.
World.BASE_GAP = 8

--- One Nomling appears on the belt this often.
World.BELT_SPAWN_SECONDS = 6
--- How many can ride the belt at once. Past this, spawning pauses rather than
--- crowding -- eight players all reading signs need space between items.
World.BELT_MAX_ITEMS = 10
--- A belt Nomling's price is its income per second times this. It pays for
--- itself in this many seconds, which keeps price and value tied together
--- automatically instead of needing a hand-tuned table per rarity.
World.BELT_PAYBACK_SECONDS = 90
--- Chance a belt Nomling arrives already mutated.
World.BELT_MUTATION_CHANCE = 0.12

--- Street dressing. All of it collides: see the header of WorldService for
--- why, and for the three narrow exceptions. The spacing below is what keeps
--- solid scenery from making the pavement feel like an obstacle course.
World.LAMP_SPACING = 88
World.LAMP_HEIGHT = 15
World.PLANTER_SPACING = 44
--- How far past the last base the backdrop sits, so the world does not simply
--- stop at the end of the road.
World.BACKDROP_DISTANCE = 130
World.BACKDROP_HEIGHT = 46

World.PEDESTAL_ROWS = 2
World.PEDESTAL_COLUMNS = 4
World.PEDESTAL_HEIGHT = 3
World.PEDESTAL_SPACING = 18

--- Where the kerb is: half the road, plus the pavement.
World.KERB_X = World.STREET_WIDTH / 2

--- The centre of base `index`, 1-based.
--- Odd indexes are the west side, even the east, so neighbours in the list are
--- opposite each other rather than next door -- it spreads players out on join.
function World.baseCenter(index: number): (number, number, number)
	local side = if index % 2 == 1 then -1 else 1
	local slot = math.floor((index - 1) / 2) -- 0-based position along the road
	local pitch = World.BASE_WIDTH + World.BASE_GAP
	local span = (World.BASES_PER_SIDE - 1) * pitch
	local z = slot * pitch - span / 2
	local x = side * (World.KERB_X + World.BASE_DEPTH / 2)
	return x, z, side
end

--- Pedestal positions within a base, relative to its centre.
--- Laid out in rows running parallel to the road, with row 1 nearest the kerb
--- so a thief has to commit to walking in for the back row.
function World.pedestalOffsets(): { { x: number, z: number } }
	local offsets: { { x: number, z: number } } = {}
	local rows, cols = World.PEDESTAL_ROWS, World.PEDESTAL_COLUMNS
	for row = 1, rows do
		for col = 1, cols do
			local x = (row - (rows + 1) / 2) * World.PEDESTAL_SPACING * 1.4
			local z = (col - (cols + 1) / 2) * World.PEDESTAL_SPACING
			table.insert(offsets, { x = x, z = z })
		end
	end
	return offsets
end

--- Where a base's owner spawns: just inside their own kerb, facing the road.
function World.spawnCFrame(index: number): (number, number, number)
	local x, z, side = World.baseCenter(index)
	return x - side * (World.BASE_DEPTH / 2 - 8), z, side
end

--- True when a point is inside base `index`. Used for "am I in someone's base"
--- checks, which both stealing and the base alarm need.
function World.isInsideBase(index: number, x: number, z: number): boolean
	local cx, cz = World.baseCenter(index)
	return math.abs(x - cx) <= World.BASE_DEPTH / 2 and math.abs(z - cz) <= World.BASE_WIDTH / 2
end

return World
