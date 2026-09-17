--!strict
--[[
	Per-device quality scaling.

	The server sets one look for everybody (AtmosphereService). This decides
	what THIS phone can afford, which has to be a local decision -- turning off
	depth of field for a player on an old handset must not change the scene for
	anybody else.

	IT MEASURES RATHER THAN GUESSES. There is no reliable way to ask a Roblox
	client how fast it is, and device-name heuristics rot. So it watches the
	actual frame rate and steps down a tier when the game has been below the
	threshold for a sustained stretch -- sustained, because a single hitch while
	the place streams in is not a slow phone.

	IT ONLY EVER STEPS DOWN, never back up. A player whose frame rate recovers
	does not want the effects flickering back on mid-session, and hunting
	between two tiers looks worse than sitting on the lower one.

	Order of sacrifice is set in Config/Visual: sun rays and depth of field go
	first because they cost the most and carry the least, then clouds, then
	bloom. Atmosphere and the colour grade are never dropped -- they are nearly
	free and they are most of the look.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Config"):WaitForChild("Visual"))

local AtmosphereController = {}
AtmosphereController.Name = "AtmosphereController"

local TIERS = { "high", "medium", "low" }
local current = 1

--- Effects are disabled rather than destroyed, so a tier change is reversible
--- and nothing has to be rebuilt.
local function apply(tierName: string)
	local tier = Visual.QUALITY[tierName]
	if not tier then
		return
	end

	-- Every assignment is guarded. This runs on a player's device against
	-- instances the server made, and one unexpected property would otherwise
	-- stop the rest of the tier from applying.
	local function setEnabled(className: string, enabled: boolean)
		local effect = Lighting:FindFirstChildOfClass(className)
		if effect then
			pcall(function()
				(effect :: any).Enabled = enabled
			end)
		end
	end

	setEnabled("BloomEffect", tier.bloom)
	setEnabled("ColorCorrectionEffect", tier.colorCorrection)
	setEnabled("SunRaysEffect", tier.sunRays)
	setEnabled("DepthOfFieldEffect", tier.dof)

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		pcall(function()
			(clouds :: any).Enabled = tier.clouds
		end)
	end

	print(`[AtmosphereController] quality: {tierName}`)
end

function AtmosphereController.start()
	-- Wait for the server's effects to replicate before touching them.
	task.spawn(function()
		local deadline = os.clock() + 15
		while os.clock() < deadline and not Lighting:FindFirstChildOfClass("BloomEffect") do
			task.wait(0.25)
		end
		apply(TIERS[current])
	end)

	task.spawn(function()
		-- Give the place time to stream in. Measuring during the first seconds
		-- of a join would demote almost every device.
		task.wait(12)

		local slowFor = 0
		local samples = 0
		local accumulated = 0

		local connection = RunService.RenderStepped:Connect(function(delta)
			accumulated += delta
			samples += 1
		end)

		while current < #TIERS do
			task.wait(1)
			if samples == 0 then
				continue
			end
			local fps = samples / accumulated
			samples = 0
			accumulated = 0

			if fps < Visual.DOWNGRADE_FPS then
				slowFor += 1
				if slowFor >= Visual.DOWNGRADE_SECONDS then
					current += 1
					apply(TIERS[current])
					slowFor = 0
					-- Give the change a moment to take effect before judging again.
					task.wait(5)
				end
			else
				-- A single hitch is not a slow phone.
				slowFor = 0
			end
		end

		connection:Disconnect()
	end)
end

return AtmosphereController
