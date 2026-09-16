--!strict
--[[ Minimal assertion helpers. No test framework dependency -- Lune plus
     twenty lines covers everything these tests need. ]]

local helpers = {}

local passed = 0
local failures: { string } = {}
local currentSuite = "?"

function helpers.suite(name: string)
	currentSuite = name
end

function helpers.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		table.insert(failures, `{currentSuite} > {name}\n      {err}`)
	end
end

function helpers.expectEqual(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function helpers.expectTrue(value: boolean, label: string?)
	if not value then
		error(`{label or "value"}: expected true`, 2)
	end
end

function helpers.expectNear(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected ~{expected} (+/-{tolerance}), got {actual}`, 2)
	end
end

function helpers.expectError(fn: () -> (), label: string?)
	local ok = pcall(fn)
	if ok then
		error(`{label or "call"}: expected an error, but it succeeded`, 2)
	end
end

function helpers.report(): number
	print(`\n  {passed} passed, {#failures} failed`)
	if #failures > 0 then
		print("\nFAILURES:")
		for _, failure in failures do
			print(`  - {failure}`)
		end
		return 1
	end
	return 0
end

return helpers
