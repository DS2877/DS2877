--!strict
--[[
	Unit test entry point.

	Run:  lune run tests/unit/run

	Only pure, dependency-free modules are testable here -- anything that
	requires a DataModel belongs in tests/cloud instead. That constraint is why
	every module under src/shared/Logic requires nothing.
]]

local process = require("@lune/process")
local h = require("./helpers")

print("Running unit tests\n")

require("./odds.spec")
require("./tokenbucket.spec")
require("./economy.spec")
require("./namegen.spec")
require("./profile.spec")
require("./income.spec")
require("./world.spec")
require("./snatch.spec")
require("./nomlingspec.spec")
require("./fusion.spec")
require("./weather.spec")

process.exit(h.report())
