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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local TutorialController = {}
TutorialController.Name = "TutorialController"

local player = Players.LocalPlayer
local banner: Frame
local bannerText: TextLabel
local helpPanel: Frame
local snapshot: { [string]: any }? = nil

type Step = { text: string, done: (snap: { [string]: any }) -> boolean }

--- In order. The first step that is not done is the one shown.
local STEPS: { Step } = {
	{
		text = "Your first Nomling is hatching — wait for the green button",
		done = function(snap)
			return (snap.hatched or 0) >= 1
		end,
	},
	{
		text = "It's earning coins! Now walk to the BELT in the middle of the street",
		done = function(snap)
			return (snap.nomlings or 0) >= 2
		end,
	},
	{
		text = "Buy a Nomling off the belt — check for a ✨ MUTATION ✨, they earn much more",
		done = function(snap)
			return (snap.nomlings or 0) >= 3
		end,
	},
	{
		text = "Tap 🧪 FUSE and combine two Nomlings — you'll get one nobody has ever seen",
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
	},
}

local HELP_LINES = {
	"🥚  Your base is behind you. Nomlings on pedestals earn coins every second.",
	"🛻  The BELT runs down the middle of the street. Walk up to a Nomling and buy it.",
	"✨  A mutated Nomling glows and earns several times more. Grab those.",
	"🧪  The FUSION KITCHEN combines two Nomlings into one that has never existed.",
	"🏆  Be the first player anywhere to make one and your name goes on it forever.",
	"🦝  Walk into another player's base and hold SNATCH to borrow one of theirs!",
	"🏃  Carrying makes you slower. Get it back to YOUR base to keep it.",
	"🛡️  Brand-new players cannot be snatched from, and neither can you at first.",
	"⛅  Weather sweeps in every so often: big coin boost, and it can MUTATE the Nomlings you have out.",
	"🫧  Tap the bubble button to rescue a Nomling a snatcher is running off with.",
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
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The objective banner sits top-centre: out of the thumbs' way, and not
	-- over the purse in the top-left.
	banner = Instance.new("Frame")
	banner.Name = "Objective"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 10)
	banner.Size = UDim2.new(0.86, 0, 0, 52)
	banner.BackgroundColor3 = Style.PALETTE.nomBlue
	banner.BorderSizePixel = 0
	banner.Parent = gui
	corner(banner, 14)

	bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.new(1, -20, 1, -10)
	bannerText.Position = UDim2.new(0, 10, 0, 5)
	bannerText.BackgroundTransparency = 1
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextScaled = true
	bannerText.TextWrapped = true
	bannerText.TextColor3 = Style.PALETTE.nomCream
	bannerText.TextStrokeTransparency = 0.5
	bannerText.Text = ""
	bannerText.Parent = banner

	-- A help button that is always there, because the banner eventually goes
	-- away and a player who forgets has nowhere else to look.
	local help = Instance.new("TextButton")
	help.Name = "Help"
	help.AnchorPoint = Vector2.new(1, 0)
	help.Position = UDim2.new(1, -12, 0, 12)
	help.Size = UDim2.new(0, 56, 0, 56)
	help.BackgroundColor3 = Style.PALETTE.nomPink
	help.BorderSizePixel = 0
	help.Font = Enum.Font.FredokaOne
	help.TextScaled = true
	help.TextColor3 = Style.PALETTE.nomCream
	help.Text = "?"
	help.Parent = gui
	corner(help, 28)

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

local function refresh()
	local snap = snapshot
	if not snap then
		return
	end
	for _, step in STEPS do
		if not step.done(snap) then
			bannerText.Text = step.text
			banner.Visible = true
			return
		end
	end
	-- Every step cleared. The banner goes; the help button stays.
	banner.Visible = false
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
end

return TutorialController
