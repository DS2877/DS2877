--!strict
--[[
	Cloud integration smoke test.

	Runs headlessly inside a real place via Open Cloud Luau Execution:
		python3 tools/run-cloud-tests.py --env test

	ONE TASK, MANY ASSERTIONS. Task creation is capped at 5 per minute per API
	key owner, so every check lives in this single script rather than one task
	per test (docs/TECH.md section 7).

	WHAT A TASK CAN AND CANNOT SEE, and this test was wrong about it until
	2026-09-17. Roblox: "In a task, physics simulation does not run. Server and
	local scripts within the place also do not automatically run." The earlier
	version asserted `ReplicatedStorage.Net` and `Workspace.Plaza` existed --
	both built at RUNTIME by scripts that a task never starts. Those two checks
	could never have passed. They never failed visibly either, because the API
	key lacked the luau-execution scope from the day it was made, so the test
	had never once run. A test nobody has seen pass is a hypothesis.
	docs/VERIFY.md, Luau Execution, checked 2026-09-17.

	So this tests what a task genuinely can, which is also the gap this project
	actually has. Lune covers pure logic, but it resolves `require` by file path
	and has no Roblox engine. Only here do we learn that Rojo put everything
	where the code expects and that every module LOADS inside the real engine --
	the failure mode we are otherwise blind to, with no Studio and no luau-lsp
	in cloud sessions.

	Roblox also says a task "may access and update the data model of the place,
	including invoking any module scripts", which is how the remote table is
	tested for real: build it and look at what came out.

	Returns true on success; the runner treats anything else as a failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

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
	local config = shared:FindFirstChild("Config")
	local economyModule = config and config:FindFirstChild("Economy")
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

-- Remotes, by building them --------------------------------------------------
-- A task never starts the server bootstrap, so the folder does not exist yet.
-- Calling Net.build() is both allowed and a better test than looking for a
-- folder: it proves every declared remote is creatable and lands with the
-- right class, which is what the bootstrap will do for real at runtime.
if shared then
	local netModule = shared:FindFirstChild("Net")
	check("Net module present", netModule ~= nil)
	if netModule and netModule:IsA("ModuleScript") then
		local ok, result = pcall(function()
			local Net = require(netModule)
			return Net.build()
		end)
		check("Net.build() succeeds", ok, if ok then nil else tostring(result))
		if ok then
			local folder = result :: Folder
			local built = #folder:GetChildren()
			check("Net.build() produced remotes", built > 0, `built {built}`)
			check(
				"Ping remote built",
				folder:FindFirstChild("Ping") ~= nil,
				"the liveness remote every session uses"
			)
			for _, remote in folder:GetChildren() do
				local isRemote = remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")
				if not isRemote then
					check(`remote '{remote.Name}' has a remote class`, false, remote.ClassName)
				end
			end
		end
	end
end

-- Rojo put the code where the bootstraps look for it -------------------------
-- The scripts do not run here, but their modules must still BE there. A Rojo
-- mapping that silently stops publishing a folder is invisible to every other
-- check we have, and would ship a game that boots into nothing.
local server = ServerScriptService:FindFirstChild("Server")
check("server code published", server ~= nil)
if server then
	local services = server:FindFirstChild("Services")
	check("Services folder published", services ~= nil)
	if services then
		local count = #services:GetChildren()
		-- Not an exact number: the count is expected to grow, and a test that
		-- has to be edited for every new service gets edited without thought.
		check("services published", count >= 15, `found {count}`)
		check("DataService published", services:FindFirstChild("DataService") ~= nil)
		check("WorldService published", services:FindFirstChild("WorldService") ~= nil)
	end
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local client = starterScripts and starterScripts:FindFirstChild("Client")
check("client code published", client ~= nil)
if client then
	local controllers = client:FindFirstChild("Controllers")
	check("Controllers folder published", controllers ~= nil)
	if controllers then
		local count = #controllers:GetChildren()
		check("controllers published", count >= 11, `found {count}`)
		check(
			"BaseHudController published",
			controllers:FindFirstChild("BaseHudController") ~= nil,
			"the HUD every other controller hangs buttons on"
		)
	end
end

-- Every shared module loads inside the real engine -------------------------
-- The one thing Lune structurally cannot tell us. It resolves requires by file
-- path; Roblox resolves them through script.Parent, so a module that is fine
-- under Lune can still fail to load in the actual game.
--
-- LAST, AND NOISY, ON PURPOSE. require() runs arbitrary module code and there
-- is no way to time-bound it from in here: a module that yields at its top
-- level hangs the whole task, and the runner's 300 s timeout then reports
-- nothing about which one. Every other check has already printed by this
-- point, and the name goes out BEFORE the require, so the last line in the log
-- is always the module that stopped it.
if shared then
	local broken: { string } = {}
	local loaded = 0
	for _, descendant in shared:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			print(`  .... requiring {descendant:GetFullName()}`)
			local ok, err = pcall(require, descendant)
			if ok then
				loaded += 1
			else
				table.insert(broken, `{descendant:GetFullName()} -> {err}`)
			end
		end
	end
	check(
		`all {loaded + #broken} shared modules load in the engine`,
		#broken == 0,
		table.concat(broken, " | ")
	)
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
