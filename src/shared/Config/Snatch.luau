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

return Snatch
