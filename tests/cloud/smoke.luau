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
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
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

-- EVERY CLIENT CONTROLLER LOADS -------------------------------------------
-- The other half of the same hole, and the one that was still open after the
-- server was proved healthy.
--
-- Bootstrap.client pcalls every require, on purpose: a controller that throws
-- while loading used to take the whole client with it, and now it does not.
-- The price of that is silence -- the controller is skipped, its buttons are
-- never wired, and the report that comes back from a phone is "nothing happens
-- when I press it". The red Fault panel says so on screen now, but a check that
-- catches it BEFORE a build reaches a phone is worth more than one that
-- explains it afterwards.
--
-- start() cannot run here: there is no LocalPlayer in a task, so anything that
-- touches PlayerGui would fail for a reason that says nothing about the game.
-- Loading is the part that can be tested, and loading is the part that was
-- failing silently.
local CONTROLLER_ORDER = {
	"PingController",
	"AtmosphereController",
	"AudioController",
	"JuiceController",
	"BaseHudController",
	"HatcheryController",
	"TutorialController",
	"NomlingRenderController",
	"HomeController",
	"ShopController",
	"FusionController",
	"WeatherController",
	"BookController",
	"DeathController",
}

local clientRoot = starterScripts and starterScripts:FindFirstChild("Client")
local controllerFolder = clientRoot and clientRoot:FindFirstChild("Controllers")
check("client Controllers folder replicated", controllerFolder ~= nil)

if clientRoot and controllerFolder then
	-- The fault reporter first, and on its own: every controller requires it,
	-- so if this one is missing the whole list fails with the same message and
	-- the real cause is buried.
	local faultModule = clientRoot:FindFirstChild("Fault")
	check(
		"Fault module published beside the controllers",
		faultModule ~= nil and faultModule:IsA("ModuleScript"),
		"controllers reach it as script.Parent.Parent.Fault"
	)

	local brokenControllers: { string } = {}
	local loadedControllers = 0
	local unnamed: { string } = {}

	for _, name in CONTROLLER_ORDER do
		local module = controllerFolder:FindFirstChild(name)
		if not (module and module:IsA("ModuleScript")) then
			table.insert(brokenControllers, `{name} -> no module (check default.project.json)`)
			continue
		end
		-- Name printed BEFORE the require, for the same reason the shared loop
		-- does it: a module that yields at its top level hangs the task, and
		-- the last line in the log is then the one that stopped it.
		print(`  .... requiring {name}`)
		local ok, controller = pcall(require, module :: ModuleScript)
		if not ok then
			table.insert(brokenControllers, `{name} -> {controller}`)
			continue
		end
		loadedControllers += 1
		-- A controller with no start() is wired into nothing. Every one of
		-- these has one, and the day one does not is the day its feature
		-- silently stops existing.
		local shape = controller :: any
		if type(shape) ~= "table" or shape.Name ~= name or type(shape.start) ~= "function" then
			table.insert(unnamed, name)
		end
	end

	check(
		`all {loadedControllers + #brokenControllers} client controllers load in the engine`,
		#brokenControllers == 0,
		table.concat(brokenControllers, " | ")
	)
	check(
		"every controller reports its own name and has a start()",
		#unnamed == 0,
		table.concat(unnamed, ", ")
	)
end

-- THE SERVER ACTUALLY BOOTING ---------------------------------------------
-- The gap this project kept falling into. A task does not run the place's
-- scripts, so Bootstrap.server never executes here -- which meant a service
-- whose start() threw was invisible to every check we had. And the bootstrap
-- PCALLS each phase, so on a real server a broken service fails silently too:
-- its remote handler is never registered, its prompts are never connected, and
-- from a phone that reads as "I press the button and nothing happens."
--
-- Philip reported exactly that, twice, across three weeks. So run the real
-- bootstrap here, in order, and name the service that breaks.
--
-- init() then start(), in two passes, because that ordering is load-bearing:
-- every init() must finish before any start(), and services register their
-- DataService.onLoaded callbacks in start().
local SERVICE_ORDER = {
	"NetService",
	"AnalyticsService",
	"WorldService",
	"AtmosphereService",
	"FeedbackService",
	"PlotService",
	"GateService",
	"EggService",
	"ConveyorService",
	"BookService",
	"RebirthService",
	"WeatherService",
	"IncomeService",
	"StealService",
	"FusionService",
	"SnatchNpcService",
	"BubbleService",
	"LeaderboardService",
	"DataService",
}

local serverRoot = ServerScriptService:FindFirstChild("Server")
local services = serverRoot and serverRoot:FindFirstChild("Services")
check("server Services folder replicated", services ~= nil)

if services then
	local loaded: { [string]: any } = {}
	local missing: { string } = {}

	for _, name in SERVICE_ORDER do
		local module = services:FindFirstChild(name)
		if not module or not module:IsA("ModuleScript") then
			table.insert(missing, `{name} (no module)`)
			continue
		end
		print(`  .... requiring {name}`)
		local ok, result = pcall(require, module :: ModuleScript)
		if ok then
			loaded[name] = result
		else
			table.insert(missing, `{name} -> {result}`)
		end
	end
	check(`all {#SERVICE_ORDER} services load`, #missing == 0, table.concat(missing, " | "))

	-- Both phases, and a failure in either is reported per service rather than
	-- swallowed. This is the check that would have caught a service dying.
	for _, phase in { "init", "start" } do
		local broken: { string } = {}
		for _, name in SERVICE_ORDER do
			local service = loaded[name]
			local fn = service and (service :: any)[phase]
			if type(fn) ~= "function" then
				continue
			end
			print(`  .... {name}:{phase}()`)
			local ok, err = pcall(fn)
			if not ok then
				table.insert(broken, `{name}:{phase}() -> {err}`)
			end
		end
		check(`every service survives {phase}()`, #broken == 0, table.concat(broken, " | "))
	end

	-- Every declared remote is really there, under the name the client asks for.
	--
	-- WHAT THIS DELIBERATELY DOES NOT CHECK, because the first version of it did
	-- and was wrong: whether each RemoteFunction has an OnServerInvoke. Roblox
	-- callback properties are WRITE-ONLY -- reading OnServerInvoke throws rather
	-- than returning the handler -- so a pcall around the read reports "no
	-- handler" for every remote in the game, including the twelve that are
	-- correctly wired. It failed CI claiming all 12 were unhandled, which was
	-- the test being broken, not the game.
	--
	-- The reason it was worth trying is still true: a RemoteFunction with no
	-- handler does not error when invoked, it YIELDS FOREVER, which on a phone
	-- is a button that does nothing. The check for that has to be the bootstrap
	-- above completing without error, since the handlers are assigned in init()
	-- and start().
	local netFolder = ReplicatedStorage:FindFirstChild("Net")
	check("Net folder exists after NetService started", netFolder ~= nil)
	if netFolder then
		local Net = require(shared:FindFirstChild("Net") :: ModuleScript) :: any
		local absent: { string } = {}
		local present = 0
		for name, spec in Net.REMOTES do
			local remote = netFolder:FindFirstChild(name)
			local wanted = if spec.kind == "event" then "RemoteEvent" else "RemoteFunction"
			if remote and remote:IsA(wanted) then
				present += 1
			else
				table.insert(absent, `{name} ({wanted})`)
			end
		end
		check(
			`all {present + #absent} declared remotes exist with the right class`,
			#absent == 0,
			table.concat(absent, ", ")
		)
	end

	-- THE RATE LIMITER, ACTUALLY CALLED.
	--
	-- THIS IS THE CHECK THAT WAS MISSING, and its absence cost three weeks.
	-- NetService.allow() builds a TokenBucket per player per remote on first
	-- use, and it was building one for EVERY declared remote -- including the
	-- server -> client ones, which declare rateCapacity = 0 because they are
	-- never rate limited. TokenBucket.new asserts capacity > 0, so allow()
	-- threw, so every remote handler in the game errored on its first line,
	-- so every button on the phone did nothing and said nothing.
	--
	-- Every other check passed throughout. init() and start() are clean,
	-- because the buckets are built lazily on the first CALL -- and a Luau
	-- task has no Players, so nothing ever made one.
	--
	-- So: make one. `allow` uses the player only as a table key, so a stand-in
	-- exercises the exact path a real player takes.
	local netService = services and services:FindFirstChild("NetService")
	if netService then
		local NetService = require(netService :: ModuleScript) :: any
		local Net = require(shared:FindFirstChild("Net") :: ModuleScript) :: any
		local stand = {} :: any

		local refused: { string } = {}
		local threw: { string } = {}
		local callable = 0
		for name, spec in Net.REMOTES do
			if spec.direction == "serverToClient" then
				continue
			end
			callable += 1
			local ok, allowed = pcall(NetService.allow, stand, name)
			if not ok then
				table.insert(threw, `{name} -> {allowed}`)
			elseif allowed ~= true then
				table.insert(refused, name)
			end
		end

		check(
			`allow() survives a first call for all {callable} client-callable remotes`,
			#threw == 0,
			table.concat(threw, " | ")
		)
		check(
			"a first call is within budget for every one of them",
			#refused == 0,
			table.concat(refused, ", ")
		)

		-- And the config the buckets are built from. A client-callable remote
		-- with a zero budget can never be called at all.
		local badBudget: { string } = {}
		for name, spec in Net.REMOTES do
			local clientCallable = spec.direction ~= "serverToClient"
			local positive = spec.rateCapacity > 0 and spec.rateRefill > 0
			if clientCallable ~= positive then
				table.insert(
					badBudget,
					`{name} ({spec.direction}, {spec.rateCapacity}/{spec.rateRefill})`
				)
			end
		end
		check(
			"every remote's rate budget matches its direction",
			#badBudget == 0,
			table.concat(badBudget, ", ")
		)
	end

	-- EVERY THING YOU CAN WALK UP TO AND PRESS, AND THE PROMPT ON IT.
	--
	-- This is the check that would have caught the round that started with
	-- "none of the buttons in game works. I tried buying, activating the laser
	-- gate, and opening the kitchen". Each of those is a ProximityPrompt built
	-- at run time by a service that walks the world looking for the part to put
	-- it on -- and every one of those walks ends in `continue` when it does not
	-- find what it wanted. A prompt that is never created is not an error
	-- anywhere: it is a landmark you can stand in front of that does nothing.
	--
	-- Cheap to assert and impossible to notice otherwise, which is the whole
	-- argument for having it.
	local street = Workspace:FindFirstChild("Street")
	check("the street was built", street ~= nil)
	if street then
		local absentPrompts: { string } = {}
		local function wantPrompt(path: string, container: Instance?, promptName: string)
			local prompt = container and container:FindFirstChild(promptName)
			if not (prompt and prompt:IsA("ProximityPrompt")) then
				table.insert(absentPrompts, `{path}/{promptName}`)
			end
		end

		local bases = street:FindFirstChild("Bases")
		check("the bases folder exists", bases ~= nil)
		if bases then
			local config = shared:FindFirstChild("Config")
			local World = require(config:FindFirstChild("World") :: ModuleScript) :: any
			for index = 1, World.BASE_COUNT do
				local base = bases:FindFirstChild(`Base{index}`)
				if not base then
					table.insert(absentPrompts, `Base{index}`)
					continue
				end
				wantPrompt(`Base{index}/GateButton`, base:FindFirstChild("GateButton"), "RaiseGate")
				-- The egg nest is furniture, not a prompt: the eggs and their
				-- prompts are drawn per player by HatcheryController. What has
				-- to exist here are the cups it puts them in.
				local hatchery = base:FindFirstChild("Hatchery")
				if not (hatchery and hatchery:FindFirstChild("Nest1")) then
					table.insert(absentPrompts, `Base{index}/Hatchery/Nest1`)
				end

				-- The "put one out" prompt on each pedestal. PlotService builds
				-- the pedestals during discoverPlots(), before anybody joins,
				-- so they are here even with no players -- and a pedestal
				-- without this prompt is a Nomling you put away and can never
				-- get back.
				local pad = base:FindFirstChild("Pad")
				local posts = pad and pad:FindFirstChild(`Pedestals_{index}`)
				local firstPost = posts and posts:FindFirstChild("Pedestal1")
				wantPrompt(`Base{index}/Pedestal1`, firstPost, "Place")
			end
		end

		for _, landmark in { "EggMarket", "FusionLab" } do
			local model = street:FindFirstChild(landmark)
			if not model then
				table.insert(absentPrompts, landmark)
				continue
			end
			wantPrompt(`{landmark}/Counter`, model:FindFirstChild("Counter"), "Use")
		end

		check(
			"every landmark and base has the prompt the client binds to",
			#absentPrompts == 0,
			table.concat(absentPrompts, ", ")
		)
	end
end

-- CAN THIS EXPERIENCE FETCH ITS OWN AUDIO? ---------------------------------
-- A PROBE, NOT A CHECK, and deliberately so: a server does not render sound,
-- so a false here is suggestive rather than damning and must not fail a build.
-- It prints, and a human reads it.
--
-- The question it exists to narrow: a phone reported `sfx loaded 0/21` -- not
-- one of eight assets, short or long. All eight are Approved, and the audio and
-- the universe are owned by the SAME account (tools/check-audio.py), which
-- Roblox says is always sufficient: "your own assets are always accessible to
-- you in your own games regardless of their privacy setting."
--
-- So if the server here can resolve them, the asset-to-experience relationship
-- is sound and the fault is on the client or the device. If it cannot, no
-- amount of client code will help and the assets themselves are the problem.
if shared then
	local audioModule = shared:FindFirstChild("Config")
	audioModule = audioModule and audioModule:FindFirstChild("Audio")
	if audioModule and audioModule:IsA("ModuleScript") then
		local Audio = require(audioModule) :: any
		local ids: { [string]: number } = {}
		for name, track in Audio.MUSIC do
			ids[name] = track.assetId
		end
		for name, cue in Audio.SFX do
			ids[name] = cue.assetId
		end

		local probes: { Sound } = {}
		local order: { string } = {}
		for name, assetId in ids do
			if assetId <= 0 then
				continue
			end
			local sound = Instance.new("Sound")
			sound.Name = `Probe_{name}`
			sound.SoundId = `rbxassetid://{assetId}`
			sound.Parent = SoundService
			table.insert(probes, sound)
			table.insert(order, name)
		end

		-- PreloadAsync is the documented way to force a fetch, and it throws
		-- rather than warns when an asset cannot be used -- which is the answer
		-- we want, in Roblox's own words.
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(probes)
		end)
		print(`  ---- audio probe: PreloadAsync ok={ok} {if ok then "" else tostring(err)}`)
		for i, sound in probes do
			print(`  ---- audio probe: {order[i]} loaded={sound.IsLoaded} len={sound.TimeLength}`)
			sound:Destroy()
		end
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
