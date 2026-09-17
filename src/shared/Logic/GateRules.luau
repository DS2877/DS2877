--!strict
--[[
	The Laser Gate: is it up, may it be raised, how long until either changes.

	A base is open to the road by design (GDD 5.3) -- no walls, no doors,
	because walking into someone's base has to be effortless or nobody ever
	tries. The Gate is the entire defence, and it is deliberately temporary:
	60 seconds up, 90 seconds of cooldown from the moment it went up. You
	cannot keep it closed, so choosing WHEN is the whole skill of it.

	PURE AND DEPENDENCY-FREE (CLAUDE.md), because this is time-window
	arithmetic, which is easy to get subtly wrong and nearly impossible to
	check by hand in a live server -- the interesting cases are the boundaries,
	and a boundary lasts one frame. Everything here takes `now` as an argument
	rather than reading a clock, so a test can stand on any instant it likes.

	ONE STATE FIELD. The whole gate is `raisedAt` -- the moment it last went
	up, or nil for a base that has never raised one. Up, cooling down and ready
	are all derived from that, so there is no way for two booleans to disagree
	about what the gate is doing.
]]

local GateRules = {}

export type Config = {
	--- How long the gate stays up once raised.
	GATE_SECONDS: number,
	--- Cooldown measured FROM THE RAISE, not from when it dropped. So the real
	--- gap between one gate falling and the next going up is
	--- GATE_COOLDOWN_SECONDS - GATE_SECONDS.
	GATE_COOLDOWN_SECONDS: number,
}

export type State = {
	up: boolean,
	--- Seconds until it drops. 0 when it is not up.
	upRemaining: number,
	--- Seconds until it may be raised again. 0 when it is ready now.
	cooldownRemaining: number,
	ready: boolean,
}

--- Everything about one gate at one instant.
---
--- A gate that has never been raised (`raisedAt == nil`) is down and ready --
--- not cooling down. A player joining a fresh base must be able to defend it
--- immediately; making them wait out a cooldown they never spent would be the
--- game punishing them for arriving.
function GateRules.state(raisedAt: number?, now: number, config: Config): State
	if raisedAt == nil then
		return { up = false, upRemaining = 0, cooldownRemaining = 0, ready = true }
	end

	local elapsed = now - raisedAt

	-- A negative elapsed means the clock went backwards under us -- a server
	-- restart, or a saved timestamp from a machine whose clock disagrees.
	-- Treating it as "raised just now" is the safe direction: the worst case is
	-- one player waiting out one extra cooldown, where the other direction
	-- hands out a permanently-ready gate.
	if elapsed < 0 then
		elapsed = 0
	end

	local up = elapsed < config.GATE_SECONDS
	local cooldownLeft = config.GATE_COOLDOWN_SECONDS - elapsed
	if cooldownLeft < 0 then
		cooldownLeft = 0
	end

	return {
		up = up,
		upRemaining = if up then config.GATE_SECONDS - elapsed else 0,
		cooldownRemaining = cooldownLeft,
		ready = cooldownLeft <= 0,
	}
end

--- Is this base's gate up right now? The one question snatching asks.
function GateRules.isUp(raisedAt: number?, now: number, config: Config): boolean
	return GateRules.state(raisedAt, now, config).up
end

--- May this base raise its gate? Returns ok, reason.
---
--- The refusals are separate on purpose. "It is already up" and "it is
--- recharging" feel completely different from inside the game, and a player
--- who taps the button during their own gate needs to be told they already
--- won, not that they are being made to wait.
function GateRules.canRaise(raisedAt: number?, now: number, config: Config): (boolean, string?)
	local state = GateRules.state(raisedAt, now, config)
	if state.up then
		return false, `The gate is already up — {math.ceil(state.upRemaining)}s left!`
	end
	if not state.ready then
		return false, `The gate is recharging — ready in {math.ceil(state.cooldownRemaining)}s.`
	end
	return true, nil
end

return GateRules
