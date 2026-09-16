--!strict
--[[ Prints a sample of generated Nomling names. Handy for showing a human what
     the generator actually produces:  lune run tools/sample/names ]]

local NameGen = require("../../src/shared/Logic/NameGen")
local Nomlings = require("../../src/shared/Config/Nomlings")

local all = NameGen.enumerate(Nomlings.SPECIES, Nomlings.GEN3_AFFIXES, Nomlings.PUREBRED_AFFIX)

local byGen: { [number]: { string } } = { [1] = {}, [2] = {}, [3] = {} }
for _, entry in all do
	table.insert(byGen[entry.gen], entry.name)
end

local function grid(names: { string }, step: number, count: number, width: number, perRow: number)
	local line = {}
	for index = 1, count do
		local name = names[((index * step - 1) % #names) + 1]
		table.insert(line, name .. string.rep(" ", math.max(1, width - #name)))
		if index % perRow == 0 then
			print("  " .. table.concat(line))
			line = {}
		end
	end
	if #line > 0 then
		print("  " .. table.concat(line))
	end
end

print(`\nGEN 1 — the 12 base Nomlings you hatch from eggs`)
grid(byGen[1], 1, 12, 16, 4)

print(`\nGEN 2 — fuse two base Nomlings ({#byGen[2]} possible)`)
grid(byGen[2], 7, 28, 16, 4)

print(`\nGEN 3 — fuse two fusions, the "Mega" tier ({#byGen[3]} possible)`)
grid(byGen[3], 43, 18, 22, 3)

print(`\n  {#all} distinct creatures in total.`)
