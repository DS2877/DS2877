--!strict
--[[
	Tells the player what to do next.

	Added after the first playtest: "the game doesn't show me how to play."
	That is the single most expensive kind of bug this project can have --
	Phase 0 confirmed first-play bounce rate is one of the heaviest discovery
	signals Roblox publishes, measured at under 60 seconds and 61-180 seconds.
	A player who does not know what to press leaves inside that window.

	The step is DERIVED FROM PROFILE STATE, never stored as "tutorial step 3".
	So it survives a rejoin, it cannot get stuck, and a returning player is not
	told to hatch their first egg for a second time.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Income = require(Shared:WaitForChild("Logic"):WaitForChild("Income"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))
local World = require(Shared:WaitForChild("Config"):WaitForChild("World"))

local BaseHudController = require(script.Parent:WaitForChild("BaseHudController"))

local TutorialController = {}
TutorialController.Name = "TutorialController"

local player = Players.LocalPlayer
local banner: Frame
local bannerText: TextLabel
local helpPanel: Frame
local snapshot: { [string]: any }? = nil

--- `target` names where in the world this step happens, if anywhere. The banner
--- says WHAT to do; the marker says WHERE, which is the half a nine-year-old
--- actually needs. "I don't know what to press" and "I don't know where to go"
--- are different complaints and the first playtest raised both.
--- `live` may replace the line with one that counts. A step whose instruction
--- you cannot yet follow -- "buy one off the belt" with 12 coins in your purse
--- -- reads as a broken game unless it tells you how far off you are.
type Step = {
	text: string,
	done: (snap: { [string]: any }) -> boolean,
	target: ("belt" | "kitchen" | "market" | "neighbour" | "nest")?,
	live: ((snap: { [string]: any }) -> string?)?,
}

--- The cheapest thing the belt can ever offer: a common, at the standard
--- payback. Derived rather than typed in, so it follows the economy.
local BELT_FLOOR = math.max(1, math.floor(Economy.BASE_INCOME.common * World.BELT_PAYBACK_SECONDS))

--- In order. The first step that is not done is the one shown.
local STEPS: { Step } = {
	{
		-- NOT "wait for the green button". There was no green button: the old
		-- HUD tray went mint-green while an egg was still COUNTING DOWN, so the
		-- wording pointed at the state that means "not yet", and a playtester
		-- waited through it -- "nothing ever happens, there is no green button."
		--
		-- The egg is now a real egg in a nest in your base, and the marker below
		-- points at it, so the instruction can name a place instead of a colour.
		text = "Your first egg is in the NEST in your base — tap it when it says TAP TO HATCH",
		done = function(snap)
			return (snap.hatched or 0) >= 1
		end,
		target = "nest",
	},
	{
		text = "It's earning coins! Now walk to the BELT in the middle of the street",
		done = function(snap)
			return (snap.nomlings or 0) >= 2
		end,
		target = "belt",
	},
	{
		text = "Buy a Nomling off the belt — check for a ✨ MUTATION ✨, they earn much more",
		done = function(snap)
			return (snap.nomlings or 0) >= 3
		end,
		target = "belt",
		live = function(snap)
			local coins = snap.coins or 0
			if coins >= BELT_FLOOR then
				return nil
			end
			-- Saving up IS the step. Say so, instead of pointing at a belt the
			-- player cannot buy from and letting them decide the game is broken.
			return `Saving up for the belt: {Income.format(coins)} / {Income.format(BELT_FLOOR)} coins — your Nomlings are earning it now`
		end,
	},
	{
		target = "kitchen",
		text = "Tap the green FUSE button and combine two Nomlings — you'll get one nobody has ever seen",
		done = function(snap)
			-- Cleared once they own something gen 2 or better, which only
			-- fusing can produce.
			for _, entry in (snap.roster or {}) do
				if (entry.gen or 1) >= 2 then
					return true
				end
			end
			return false
		end,
	},
	{
		text = "Now the fun part — walk into someone else's base and hold SNATCH!",
		done = function(snap)
			return (snap.playtime or 0) > 300
		end,
		target = "neighbour",
	},
}

local HELP_LINES = {
	"🥚  Your base is behind you. Nomlings on pedestals earn coins every second.",
	"🚚  The BELT runs down the middle of the street. Walk up to a Nomling and buy it.",
	"✨  A mutated Nomling glows and earns several times more. Grab those.",
	"🍳  The FUSION KITCHEN combines two Nomlings into one that has never existed.",
	"🏆  Be the first player anywhere to make one and your name goes on it forever.",
	"🦝  Walk into another player's base and hold SNATCH to borrow one of theirs!",
	"🏃  Carrying makes you slower. Get it back to YOUR base to keep it.",
	"🛡️  Brand-new players cannot be snatched from, and neither can you at first.",
	"⛅  Weather sweeps in every so often: big coin boost, and it can MUTATE the Nomlings you have out.",
	"💙  Tap the blue SAVE button to rescue a Nomling a snatcher is running off with.",
	"🔒  Stand in your base and tap LASER GATE to lock it for a minute.",
	"💰  You keep earning while you're away — come back to a pile of coins.",
}

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The banner does NOT pick its own position any more. It fills the slot the
	-- HUD hands it, which is whatever is left of the top row after the purse and
	-- before the rail. Positioned by hand it ran under the Roblox menu buttons
	-- and over the coin count, and the rail's "?" landed on top of it.
	banner = Instance.new("Frame")
	banner.Name = "Objective"
	banner.Size = UDim2.fromScale(1, 1)
	banner.BackgroundColor3 = Style.PALETTE.nomBlue
	-- SEE-THROUGH, from a playtest: "the banner at the top that says things is
	-- too big and should be a bit see-through." It is a hint, not a headline --
	-- it must not read as more important than the street behind it.
	banner.BackgroundTransparency = 0.35
	banner.BorderSizePixel = 0
	banner.ZIndex = 4
	banner.Visible = false
	banner.Parent = BaseHudController.objectiveSlot()
	corner(banner, 14)

	bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.new(1, -18, 1, -8)
	bannerText.Position = UDim2.new(0, 9, 0, 4)
	bannerText.BackgroundTransparency = 1
	bannerText.Font = Enum.Font.GothamMedium
	bannerText.TextScaled = true
	bannerText.TextWrapped = true
	bannerText.TextColor3 = Style.PALETTE.nomCream
	-- A stroke, because the background is now translucent and the text has to
	-- stay readable against whatever the street happens to put behind it.
	bannerText.TextStrokeTransparency = 0.25
	bannerText.ZIndex = 5
	bannerText.Text = ""
	bannerText.Parent = banner

	-- Two short lines at this height, not one line of 40 px type.
	local bannerCap = Instance.new("UITextSizeConstraint")
	bannerCap.MaxTextSize = 16
	bannerCap.MinTextSize = 8
	bannerCap.Parent = bannerText

	-- A help button that is always there, because the banner eventually goes
	-- away and a player who forgets has nowhere else to look. It lives on the
	-- HUD's rail so the right-edge stack cannot collide at any screen size.
	local help = BaseHudController.railButton("Help", 10, Style.PALETTE.nomPink)
	local helpLabel = Instance.new("TextLabel")
	helpLabel.Size = UDim2.fromScale(1, 1)
	helpLabel.BackgroundTransparency = 1
	helpLabel.Font = Enum.Font.FredokaOne
	helpLabel.TextScaled = true
	helpLabel.TextColor3 = Style.PALETTE.nomCream
	helpLabel.Text = "?"
	helpLabel.Parent = help

	helpPanel = Instance.new("Frame")
	helpPanel.Name = "HelpPanel"
	helpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	helpPanel.Position = UDim2.fromScale(0.5, 0.5)
	helpPanel.Size = UDim2.new(0.9, 0, 0, 40 + #HELP_LINES * 44)
	helpPanel.BackgroundColor3 = Style.PALETTE.nomCream
	helpPanel.BorderSizePixel = 0
	helpPanel.Visible = false
	helpPanel.Parent = gui
	corner(helpPanel, 18)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = helpPanel

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = helpPanel

	for _, line in HELP_LINES do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 38)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham
		row.TextScaled = true
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Style.PALETTE.ink
		row.Text = line
		row.Parent = helpPanel
	end

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, 0, 0, 52)
	close.BackgroundColor3 = Style.PALETTE.nomOrange
	close.BorderSizePixel = 0
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Style.PALETTE.nomCream
	close.Text = "Got it!"
	close.Parent = helpPanel
	corner(close, 14)

	help.Activated:Connect(function()
		helpPanel.Visible = not helpPanel.Visible
	end)
	close.Activated:Connect(function()
		helpPanel.Visible = false
	end)
end

--- A bobbing arrow over wherever the current step happens.
local marker: BasePart? = nil
local markerTarget: Vector3? = nil

local function ensureMarker(): BasePart?
	if marker and marker.Parent then
		return marker
	end
	local part = Instance.new("Part")
	part.Name = "TutorialMarker"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	-- A wedge points, which is the entire job. A glowing block would only be a
	-- glowing block.
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(3, 3, 3)
	part.Color = Color3.fromRGB(255, 214, 92)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.15
	part.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 18
	light.Color = part.Color
	light.Parent = part

	marker = part
	return part
end

--- Where a step's target is, in world space. Resolved fresh each time so it
--- follows the player down the street rather than pointing at one fixed spot.
local function resolveTarget(kind: string): Vector3?
	local street = Workspace:FindFirstChild("Street")
	if not street then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.Position else nil

	if kind == "nest" then
		-- Your own base's egg bench. Resolved from the profile's base index
		-- rather than by searching for a pad you own, for the same reason the
		-- home beacon is: the base you want may be the far end of the street.
		local index = tonumber(snapshot and snapshot.baseIndex)
		if not index then
			return nil
		end
		local bases = street:FindFirstChild("Bases")
		local base = bases and bases:FindFirstChild(`Base{index}`)
		local hatchery = base and base:FindFirstChild("Hatchery")
		local bench = hatchery and hatchery:FindFirstChild("Bench")
		return if bench and bench:IsA("BasePart")
			then bench.Position + Vector3.new(0, 9, 0)
			else nil
	elseif kind == "belt" then
		-- The nearest point ON the belt, so the arrow is always a short walk
		-- away instead of at one end of a 520-stud road.
		local z = if at then math.clamp(at.Z, -240, 240) else 0
		return Vector3.new(0, 8, z)
	elseif kind == "kitchen" then
		local lab = street:FindFirstChild("FusionLab")
		local counter = lab and lab:FindFirstChild("Counter")
		return if counter and counter:IsA("BasePart")
			then counter.Position + Vector3.new(0, 8, 0)
			else nil
	elseif kind == "market" then
		local market = street:FindFirstChild("EggMarket")
		local counter = market and market:FindFirstChild("Counter")
		return if counter and counter:IsA("BasePart")
			then counter.Position + Vector3.new(0, 8, 0)
			else nil
	elseif kind == "neighbour" then
		-- Any base that is not yours. Points at a real destination rather than
		-- a vague instruction to "go find someone".
		local bases = street:FindFirstChild("Bases")
		if not bases then
			return nil
		end
		for _, base in bases:GetChildren() do
			local pad = base:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then
				local owner = pad:GetAttribute("OwnerUserId")
				if owner ~= player.UserId then
					return pad.Position + Vector3.new(0, 10, 0)
				end
			end
		end
	end
	return nil
end

local function refresh()
	local snap = snapshot
	if not snap then
		return
	end
	for _, step in STEPS do
		if not step.done(snap) then
			bannerText.Text = (step.live and step.live(snap)) or step.text
			banner.Visible = true
			markerTarget = if step.target then resolveTarget(step.target) else nil
			if marker then
				marker.Transparency = if markerTarget then 0.15 else 1
			end
			return
		end
	end
	-- Every step cleared. The banner goes, the marker goes, the help button stays.
	banner.Visible = false
	markerTarget = nil
	if marker then
		marker.Transparency = 1
	end
end

function TutorialController.start()
	build()

	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) == "table" then
			snapshot = snap
			refresh()
		end
	end)

	-- The marker bobs and spins so it reads as a marker rather than as scenery.
	RunService.RenderStepped:Connect(function()
		local target = markerTarget
		local part = ensureMarker()
		if not part then
			return
		end
		if not target then
			part.Transparency = 1
			return
		end
		local clock = os.clock()
		part.Transparency = 0.15
		part.CFrame = CFrame.new(target + Vector3.new(0, math.sin(clock * 2.4) * 0.7, 0))
			* CFrame.Angles(0, clock * 1.6, math.rad(45))
	end)

	-- The target has to be re-resolved as the player moves, or the belt marker
	-- stays where they first saw it.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if snapshot then
				pcall(refresh)
			end
		end
	end)
end

return TutorialController
