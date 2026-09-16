--!strict
--[[
	Cloud integration smoke test.

	Runs headlessly inside a real place via Open Cloud Luau Execution:
		python3 tools/run-cloud-tests.py --env test

	ONE TASK, MANY ASSERTIONS. Task creation is capped at 5 per minute per API
	key owner, so every check lives in this single script rather than one task
	per test (docs/TECH.md section 7).

	This is what turns "the deploy reported success" into "the game actually
	boots" -- which matters more than usual, because Philip reviews on a phone
	and cannot open Studio to look.

	Returns true on success; the runner treats anything else as a failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local checks = 0
local failures: { string } = {}

local function check(label: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(`  PASS  {label}`)
	else
		local message = if detail then `{label}: {detail}` else label
		table.insert(failures, message)
		print(`  FAIL  {message}`)
	end
end

print("Cloud smoke test")

-- Shared code replicated at all -------------------------------------------
local shared = ReplicatedStorage:FindFirstChild("Shared")
check("Shared folder replicated", shared ~= nil)

if shared then
	local economyModule = shared:FindFirstChild("Config")
	economyModule = economyModule and economyModule:FindFirstChild("Economy")
	check("Economy config present", economyModule ~= nil)

	if economyModule then
		local Economy = require(economyModule :: ModuleScript)

		-- Compliance, not balance: Roblox requires disclosed odds to total
		-- 100%. A drift here is a policy violation, not a tuning mistake.
		for eggKey, egg in Economy.EGGS do
			local total = 0
			for _, ppm in egg.odds do
				total += ppm
			end
			check(`odds sum for '{eggKey}'`, total == 1000000, `got {total} ppm, expected 1000000`)
		end

		check(
			"rebirth grants a free egg",
			Economy.REBIRTH_GRANTS_FREE_EGG == true,
			"without this, players soft-lock after their first rebirth"
		)
		check("fusion has one slot at base", Economy.FUSION_SLOTS_BASE == 1)
	end

	local logic = shared:FindFirstChild("Logic")
	check("Logic modules present", logic ~= nil and logic:FindFirstChild("Odds") ~= nil)
end

-- Remotes built ------------------------------------------------------------
local net = ReplicatedStorage:FindFirstChild("Net")
check("Net folder built by the server", net ~= nil)
if net then
	check("Ping remote exists", net:FindFirstChild("Ping") ~= nil)
end

-- World built --------------------------------------------------------------
local plaza = Workspace:FindFirstChild("Plaza")
check("Plaza built", plaza ~= nil)

if plaza then
	check("Plaza floor present", plaza:FindFirstChild("PlazaFloor") ~= nil)
	check("Egg Market present", plaza:FindFirstChild("EggMarket") ~= nil)
	check("Fusion Lab present", plaza:FindFirstChild("FusionLab") ~= nil)
	check("Spawn present", plaza:FindFirstChild("PlazaSpawn") ~= nil)

	local plots = plaza:FindFirstChild("Plots")
	check("Plots folder present", plots ~= nil)
	if plots then
		local count = #plots:GetChildren()
		check("eight plots built", count == 8, `found {count}`)
	end
end

-- Report -------------------------------------------------------------------
print(`\n{checks - #failures}/{checks} checks passed`)

if #failures > 0 then
	for _, failure in failures do
		print(`  FAILED: {failure}`)
	end
	error(`cloud smoke test failed: {#failures} of {checks} checks`)
end

return true
