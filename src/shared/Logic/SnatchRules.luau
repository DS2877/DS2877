--!strict
--[[
	May this player snatch from that one, right now?

	Pure and DEPENDENCY-FREE, so every fair-play rule is unit-testable without a
	DataModel. The service does the world checks (distance, line of sight, is
	the gate up); this decides the social ones, which are the rules people
	actually get upset about when they are wrong.

	Every refusal returns a sentence a child can read. "Denied" is not an
	acceptable message for a nine-year-old.
]]

local SnatchRules = {}

export type Context = {
	thiefUserId: number,
	targetUserId: number,
	--- Total seconds the target has ever played.
	targetPlaytime: number,
	thiefIncomePerSecond: number,
	targetIncomePerSecond: number,
	--- os.clock() of the thief's last attempt on this target, or nil.
	lastAttemptAt: number?,
	now: number,
	--- Is the target's Laser Gate up?
	gateUp: boolean,
	--- Is the creature in the Vault, or Bonded?
	protected: boolean,
	--- Does the thief have anywhere to put it?
	thiefHasFreePedestal: boolean,
	--- Is the thief already carrying something?
	thiefCarrying: boolean,
}

export type Config = {
	NEWCOMER_SHIELD_SECONDS: number,
	MIN_TARGET_INCOME_RATIO: number,
	TARGET_COOLDOWN_SECONDS: number,
}

function SnatchRules.check(ctx: Context, config: Config): (boolean, string?)
	if ctx.thiefUserId == ctx.targetUserId then
		return false, "That one is already yours!"
	end
	if ctx.thiefCarrying then
		return false, "You are already carrying one!"
	end
	if ctx.protected then
		return false, "That Nomling is in the Vault."
	end
	if ctx.gateUp then
		return false, "The Laser Gate is up!"
	end
	if not ctx.thiefHasFreePedestal then
		return false, "Your base is full -- no room for it."
	end

	if ctx.targetPlaytime < config.NEWCOMER_SHIELD_SECONDS then
		return false, "They are brand new. Give them a minute!"
	end

	-- Protects the weakest players from the strongest. Note the direction: a
	-- small player may always rob a big one, which is the fun asymmetry.
	if ctx.thiefIncomePerSecond > 0 then
		local ratio = ctx.targetIncomePerSecond / ctx.thiefIncomePerSecond
		if ratio < config.MIN_TARGET_INCOME_RATIO then
			return false, "They are way behind you. Pick on someone your own size!"
		end
	end

	local last = ctx.lastAttemptAt
	if last then
		local elapsed = ctx.now - last
		if elapsed < config.TARGET_COOLDOWN_SECONDS then
			local wait = math.ceil(config.TARGET_COOLDOWN_SECONDS - elapsed)
			return false, `Too soon! Try them again in {wait}s.`
		end
	end

	return true, nil
end

return SnatchRules
