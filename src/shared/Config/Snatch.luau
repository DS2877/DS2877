--!strict
--[[
	Snatching rules, as numbers.

	Every value here exists to protect one feeling (GDD 5.8): a player who is
	snatched from should think "that was exciting", never "I lost my afternoon."
	If a playtest says otherwise, WEAKEN snatching. Never strengthen it.
]]

local Snatch = {}

--- Hold this long on a Nomling before it lifts. Long enough that it is a
--- decision, short enough to do while someone is running at you.
Snatch.HOLD_SECONDS = 1.5

--- The carrier moves at this fraction of normal speed.
Snatch.CARRY_SPEED_FACTOR = 0.7

--- Carry it longer than this and it goes home by itself. Stops a griefer from
--- simply running in circles with someone's best creature.
Snatch.CARRY_TIMEOUT_SECONDS = 40

--- No snatching from a player until they have this much total playtime.
Snatch.NEWCOMER_SHIELD_SECONDS = 20 * 60

--- Cannot snatch from a base earning less than this fraction of your own rate.
--- Stops the strongest player farming the weakest.
Snatch.MIN_TARGET_INCOME_RATIO = 0.2

--- One attempt on the same target per this many seconds.
Snatch.TARGET_COOLDOWN_SECONDS = 60

--- The victim immediately gets a replacement egg of this tier, hatching fast,
--- so being robbed hands you something rather than only taking something.
Snatch.COMEBACK_EGG = "basic"
Snatch.COMEBACK_HATCH_SECONDS = 120

-- --- the Bubble Wand -------------------------------------------------------
-- Everyone has one, always (GDD 5.8). It is the entire counter-play to being
-- robbed, and without it snatching is something that happens TO you.

--- How close you must be to bubble a carrier.
Snatch.BUBBLE_RANGE = 26
--- How long the bubbled carrier is stuck.
Snatch.BUBBLE_SECONDS = 2
--- Between your own bubble shots.
Snatch.BUBBLE_COOLDOWN = 3
--- A bubbled player cannot be bubbled again for this long, so nobody is ever
--- stun-locked. This number exists to protect a feeling, not a balance.
Snatch.BUBBLE_IMMUNITY = 3

-- --- NPC snatchers ---------------------------------------------------------
-- "Sneaky Sam and friends" (GDD 5.8). These exist for a hard practical reason:
-- Philip is phone-only with no Studio, so two clients cannot be run side by
-- side, and snatching is otherwise untestable. They drive the same server code
-- paths a real thief would.

Snatch.NPC_ENABLED = true
--- Names, so being robbed has a face. Friendly on purpose -- this is a game
--- about mischief, not menace.
Snatch.NPC_NAMES = {
	"Sneaky Sam",
	"Nibble Nora",
	"Crumb Colin",
	"Snack Bandit",
	"Pocket Pip",
}
--- Seconds between attempts. Long, because being robbed constantly is the
--- fastest way to make a player quit.
Snatch.NPC_INTERVAL_MIN = 75
Snatch.NPC_INTERVAL_MAX = 150
--- Studs per second. Slower than a player's 16, so bubbling one is always
--- possible for somebody who reacts.
Snatch.NPC_SPEED = 11
--- An NPC will not rob a base with fewer than this many Nomlings. Taking
--- somebody's only creature is not mischief, it is a reset.
Snatch.NPC_MIN_TARGET_NOMLINGS = 2
--- How long the NPC needs to reach the street's edge and get away.
Snatch.NPC_ESCAPE_SECONDS = 22

return Snatch
