--!strict
--[[
	A beam of light over YOUR base, from anywhere on the street.

	Straight from a playtest: "I also can't find my base." Eight bases line one
	520-stud road and they are built from the same parts in the same colours,
	so from halfway down the street they are eight identical shapes. The sign
	carries your name, but you have to be close enough to read a sign to know
	which sign to read -- which is circular, and is exactly the position a lost
	player is in.

	So the beacon is deliberately unsubtle: a tall neon column and a label that
	renders THROUGH the scenery, readable from either end of the road. It is
	yours alone -- built on the client, from the pad's OwnerUserId attribute --
	so the street is not a forest of eight beams.

	It is a SIGNPOST, never a shortcut. There is no teleport here and there must
	not be: carrying a snatched Nomling home is the whole risk half of stealing,
	and a button that skips the run would delete it.

	POSITION COMES FROM THE SERVER, not from finding the pad. The first version
	searched Workspace for a Pad whose OwnerUserId matched, which fails under
	StreamingEnabled: the radius is 512 studs and the street is 520, so a base
	at the far end is not replicated to the client at all. The beacon was
	therefore missing in exactly the situation it exists for -- being far from
	home -- and the report was "I don't seem to get a base, or it's not obvious
	how to find it". The profile sync now carries baseX/baseZ.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local HomeController = {}
HomeController.Name = "HomeController"

local player = Players.LocalPlayer

local beacon: BasePart? = nil
local distanceLabel: TextLabel? = nil
--- Where the server says home is. nil until the first profile sync lands, or
--- while the player has no base assigned at all.
local homePosition: Vector3? = nil
local homeIndex: number? = nil

--- Height of the column. Tall enough to clear the buildings behind the bases,
--- because a marker you cannot see over the scenery is not a marker.
local BEAM_HEIGHT = 90

--- The colour of this player's base, so the beam matches the plot it points
--- at. Falls back to mint if the index is missing, which only happens before
--- the first sync.
local function homeColour(): Color3
	local index = homeIndex
	if not index then
		return Style.PALETTE.nomMint
	end
	return Style.BASE_PAD[(index - 1) % #Style.BASE_PAD + 1]
end

local function buildBeacon(at: Vector3): BasePart
	local column = Instance.new("Part")
	column.Name = "HomeBeacon"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Size = Vector3.new(3, BEAM_HEIGHT, 3)
	column.CFrame = CFrame.new(at + Vector3.new(0, BEAM_HEIGHT / 2, 0))
	-- Your base's own sweet colour, not a fixed mint. Each plot is a different
	-- colour now, so a beam that matches turns "somewhere over there" into
	-- "the peach one" -- and the beam stops being the only way to tell.
	column.Color = homeColour()
	column.Material = Enum.Material.Neon
	column.Transparency = 0.72
	-- Client-only: parenting under Camera keeps it out of anything that walks
	-- Workspace looking for real world objects, and it is never replicated.
	column.Parent = Workspace.CurrentCamera

	local sign = Instance.new("BillboardGui")
	sign.Name = "HomeSign"
	sign.Size = UDim2.fromScale(14, 4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, BEAM_HEIGHT / 2 + 4, 0)
	-- Through the scenery and from the far end of the road. Both deliberate:
	-- being lost is the problem this solves.
	sign.AlwaysOnTop = true
	sign.MaxDistance = 1000
	sign.Parent = column

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Style.PALETTE.nomCream
	title.TextStrokeTransparency = 0.15
	title.Text = "YOUR BASE"
	title.Parent = sign

	local distance = Instance.new("TextLabel")
	distance.Size = UDim2.fromScale(1, 0.38)
	distance.Position = UDim2.fromScale(0, 0.62)
	distance.BackgroundTransparency = 1
	distance.Font = Enum.Font.GothamBold
	distance.TextScaled = true
	distance.TextColor3 = homeColour()
	distance.TextStrokeTransparency = 0.3
	distance.Text = ""
	distance.Parent = sign
	distanceLabel = distance

	return column
end

function HomeController.start()
	-- The server is the only thing that knows where home is, so the beacon
	-- follows the profile sync rather than searching the world.
	local sync = Net.get("ProfileSync") :: RemoteEvent
	sync.OnClientEvent:Connect(function(snap)
		if type(snap) ~= "table" then
			return
		end
		local x, z = tonumber(snap.baseX), tonumber(snap.baseZ)
		homeIndex = tonumber(snap.baseIndex)
		homePosition = if x and z then Vector3.new(x, 0, z) else nil
	end)

	-- Rebuilt on a tick rather than on the sync, because the beacon is parented
	-- to CurrentCamera and a camera swap silently takes it with it. Checking
	-- that it is still alive is the same cheap loop as checking whether home
	-- moved, so one loop does both.
	task.spawn(function()
		local builtAt: Vector3? = nil
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local home = homePosition
				local live = beacon ~= nil and (beacon :: BasePart).Parent ~= nil
				if home ~= builtAt or (home ~= nil and not live) then
					builtAt = home
					if beacon then
						beacon:Destroy()
						beacon = nil
						distanceLabel = nil
					end
					if home then
						beacon = buildBeacon(home)
					end
				end
			end)
			if not ok then
				warn(`[HomeController] beacon refresh failed: {err}`)
			end
		end
	end)

	-- The distance is the half that actually helps: "YOUR BASE" tells you which
	-- way, a falling number tells you that you are getting there.
	RunService.Heartbeat:Connect(function()
		local label, home = distanceLabel, homePosition
		if not label or not home then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			label.Text = ""
			return
		end
		-- Flat distance: the beam is 90 studs tall and counting its height in
		-- would tell a player standing on their own base that it is 45 away.
		local here = root.Position
		local away = (Vector2.new(here.X, here.Z) - Vector2.new(home.X, home.Z)).Magnitude
		label.Text = if away < 30 then "you're home" else `{math.floor(away)} studs away`
	end)
end

return HomeController
