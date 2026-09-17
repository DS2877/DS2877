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
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))

local HomeController = {}
HomeController.Name = "HomeController"

local player = Players.LocalPlayer

local beacon: BasePart? = nil
local distanceLabel: TextLabel? = nil
local myPad: BasePart? = nil

--- Height of the column. Tall enough to clear the buildings behind the bases,
--- because a marker you cannot see over the scenery is not a marker.
local BEAM_HEIGHT = 90

local function findMyPad(): BasePart?
	local street = Workspace:FindFirstChild("Street")
	local bases = street and street:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	for _, base in bases:GetChildren() do
		local pad = base:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") and pad:GetAttribute("OwnerUserId") == player.UserId then
			return pad
		end
	end
	return nil
end

local function buildBeacon(pad: BasePart): BasePart
	local column = Instance.new("Part")
	column.Name = "HomeBeacon"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Size = Vector3.new(3, BEAM_HEIGHT, 3)
	column.CFrame = pad.CFrame * CFrame.new(0, BEAM_HEIGHT / 2, 0)
	-- Your base's own sweet colour, not a fixed mint. Each plot is a different
	-- colour now, so a beam that matches turns "somewhere over there" into
	-- "the peach one" -- and the beam stops being the only way to tell.
	column.Color = pad.Color
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
	distance.TextColor3 = pad.Color
	distance.TextStrokeTransparency = 0.3
	distance.Text = ""
	distance.Parent = sign
	distanceLabel = distance

	return column
end

function HomeController.start()
	-- Polled rather than event-driven: the pad's owner is set by the server
	-- whenever a plot is assigned or released, and StreamingEnabled means the
	-- Bases folder may not even exist on the client yet when this starts. One
	-- cheap check a second is the robust version of both problems.
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local pad = findMyPad()
				local live = beacon ~= nil and (beacon :: BasePart).Parent ~= nil
				if pad ~= myPad or (pad ~= nil and not live) then
					myPad = pad
					if beacon then
						beacon:Destroy()
						beacon = nil
						distanceLabel = nil
					end
					if pad then
						beacon = buildBeacon(pad)
					end
				end
			end)
			if not ok then
				warn(`[HomeController] beacon refresh failed: {err}`)
			end
		end
	end)

	-- The distance is the half that actually helps: "YOUR BASE" tells you
	-- which way, a falling number tells you that you are getting there.
	RunService.Heartbeat:Connect(function()
		local label, pad = distanceLabel, myPad
		if not label or not pad then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			label.Text = ""
			return
		end
		local away = (root.Position - pad.Position).Magnitude
		-- Close enough that you are standing on it; the beam has done its job.
		label.Text = if away < 30 then "you're home" else `{math.floor(away)} studs away`
	end)
end

return HomeController
