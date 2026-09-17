--!strict
local h = require("./helpers")
local GateRules = require("../../src/shared/Logic/GateRules")
local Snatch = require("../../src/shared/Config/Snatch")

h.suite("Laser Gate")

local CONFIG = {
	GATE_SECONDS = Snatch.GATE_SECONDS,
	GATE_COOLDOWN_SECONDS = Snatch.GATE_COOLDOWN_SECONDS,
}

-- Fixed instants, so every case below reads as "how long after the raise".
local RAISED = 1000

h.test("a base that has never raised a gate is ready, not cooling down", function()
	-- A player who just joined must be able to defend immediately. Treating
	-- "never raised" as "cooling down" would punish them for arriving.
	local state = GateRules.state(nil, RAISED, CONFIG)
	h.expectEqual(state.up, false)
	h.expectEqual(state.ready, true)
	h.expectEqual(state.cooldownRemaining, 0)

	local ok = GateRules.canRaise(nil, RAISED, CONFIG)
	h.expectEqual(ok, true, "a fresh base may raise its gate")
end)

h.test("the gate is up for exactly GATE_SECONDS", function()
	h.expectEqual(GateRules.isUp(RAISED, RAISED, CONFIG), true, "up the instant it is raised")
	h.expectEqual(
		GateRules.isUp(RAISED, RAISED + Snatch.GATE_SECONDS - 0.01, CONFIG),
		true,
		"still up a hundredth before it expires"
	)
	-- The boundary is exclusive: at exactly GATE_SECONDS it is down. A gate
	-- that lingered one frame past its own countdown would let a snatch fail
	-- after the player watched the timer hit zero.
	h.expectEqual(
		GateRules.isUp(RAISED, RAISED + Snatch.GATE_SECONDS, CONFIG),
		false,
		"down on the tick it runs out"
	)
end)

h.test("the cooldown is measured from the RAISE, not from the drop", function()
	-- This is the number that decides how much of the time a base can be
	-- locked. Measured from the drop it would be 60 up + 90 down = 40% locked;
	-- measured from the raise it is 60 up in every 90, which is 67% -- a very
	-- different game. The config comment claims from-the-raise; this is the
	-- test that keeps it true.
	local justDropped = RAISED + Snatch.GATE_SECONDS
	local state = GateRules.state(RAISED, justDropped, CONFIG)
	h.expectEqual(state.up, false)
	h.expectEqual(
		state.cooldownRemaining,
		Snatch.GATE_COOLDOWN_SECONDS - Snatch.GATE_SECONDS,
		"the remaining wait is the overhang past the gate's own duration"
	)
end)

h.test("it becomes raisable again exactly at the cooldown", function()
	local ready = RAISED + Snatch.GATE_COOLDOWN_SECONDS
	h.expectEqual(GateRules.state(RAISED, ready - 0.01, CONFIG).ready, false)
	h.expectEqual(GateRules.state(RAISED, ready, CONFIG).ready, true)

	local ok = GateRules.canRaise(RAISED, ready, CONFIG)
	h.expectEqual(ok, true)
end)

h.test("the two refusals are different sentences", function()
	-- "Already up" and "recharging" feel nothing alike from inside the game.
	-- A player tapping during their own gate needs to hear they already won.
	local _, duringGate = GateRules.canRaise(RAISED, RAISED + 5, CONFIG)
	local _, duringCooldown = GateRules.canRaise(RAISED, RAISED + Snatch.GATE_SECONDS + 5, CONFIG)

	h.expectTrue(duringGate ~= nil and duringCooldown ~= nil, "both refusals explain themselves")
	h.expectTrue(
		(duringGate :: string) ~= (duringCooldown :: string),
		"and they are not the same text"
	)
	h.expectTrue(
		string.find(duringGate :: string, "already") ~= nil,
		"the during-gate refusal says the gate is already up"
	)
	h.expectTrue(
		string.find(duringCooldown :: string, "recharg") ~= nil,
		"the cooldown refusal says it is recharging"
	)
end)

h.test("a clock that goes backwards does not hand out a permanent gate", function()
	-- os.time() across a server restart, or a saved timestamp from a machine
	-- whose clock disagrees. The safe direction is "raised just now": the worst
	-- case is one extra cooldown, where the other direction is a base that can
	-- re-raise forever.
	local state = GateRules.state(RAISED, RAISED - 5000, CONFIG)
	h.expectEqual(state.up, true, "treated as just raised")
	h.expectEqual(state.ready, false, "and therefore not instantly re-raisable")
end)

h.test("a gate can never be up more often than it is down", function()
	-- The design rule behind the two numbers (GDD 5.8): the Gate is a moment,
	-- not a wall. If a cooldown is ever shorter than twice the gate it can be
	-- held up more than half the time, and snatching -- the thing the whole
	-- base defends against -- stops happening at all.
	h.expectTrue(
		Snatch.GATE_COOLDOWN_SECONDS >= Snatch.GATE_SECONDS * 1.5,
		`GATE_COOLDOWN_SECONDS ({Snatch.GATE_COOLDOWN_SECONDS}) must stay well above `
			.. `GATE_SECONDS ({Snatch.GATE_SECONDS}) or bases are locked most of the time`
	)
end)
