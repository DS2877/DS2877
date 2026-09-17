--!strict
--[[
	Applies the art direction to Lighting.

	Server-side because Lighting and the post-processing effects under it
	replicate: one place sets the look and every player gets it, with no chance
	of two clients disagreeing about what time of day it is.

	Per-device quality scaling is the CLIENT's job (AtmosphereController) -- it
	turns individual effects off on a phone that cannot afford them, which is a
	local decision and must not change the scene for anybody else.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Config"):WaitForChild("Visual"))

local AtmosphereService = {}
AtmosphereService.Name = "AtmosphereService"

local function rgb(triplet: { number }): Color3
	return Color3.fromRGB(triplet[1], triplet[2], triplet[3])
end

--- Replaces an existing instance of a class under a parent, so this service is
--- safe to run twice and leaves no duplicates behind.
local function replace(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

function AtmosphereService.start()
	local light = Visual.LIGHTING
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = light.clockTime
	Lighting.GeographicLatitude = light.geographicLatitude
	Lighting.Brightness = light.brightness
	Lighting.ExposureCompensation = light.exposureCompensation
	Lighting.Ambient = rgb(light.ambient)
	Lighting.OutdoorAmbient = rgb(light.outdoorAmbient)
	Lighting.ShadowSoftness = light.shadowSoftness
	Lighting.EnvironmentDiffuseScale = light.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = light.environmentSpecularScale
	Lighting.GlobalShadows = true
	-- Atmosphere supersedes legacy fog. Leaving FogEnd at its default would
	-- fight the haze and flatten the street.
	Lighting.FogEnd = light.fogEnd

	local atmosphere = replace(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	local air = Visual.ATMOSPHERE
	atmosphere.Density = air.density
	atmosphere.Offset = air.offset
	atmosphere.Color = rgb(air.color)
	atmosphere.Decay = rgb(air.decay)
	atmosphere.Glare = air.glare
	atmosphere.Haze = air.haze

	local sky = replace(Lighting, "Sky", "Sky") :: Sky
	sky.SunAngularSize = Visual.SKY.sunAngularSize
	sky.MoonAngularSize = Visual.SKY.moonAngularSize
	sky.StarCount = Visual.SKY.starCount

	local bloom = replace(Lighting, "BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = Visual.BLOOM.intensity
	bloom.Size = Visual.BLOOM.size
	bloom.Threshold = Visual.BLOOM.threshold

	local grade = replace(Lighting, "ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	grade.Brightness = Visual.COLOR_CORRECTION.brightness
	grade.Contrast = Visual.COLOR_CORRECTION.contrast
	grade.Saturation = Visual.COLOR_CORRECTION.saturation
	grade.TintColor = rgb(Visual.COLOR_CORRECTION.tintColor)

	local rays = replace(Lighting, "SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = Visual.SUN_RAYS.intensity
	rays.Spread = Visual.SUN_RAYS.spread

	local dof = replace(Lighting, "DepthOfFieldEffect", "DepthOfField") :: DepthOfFieldEffect
	dof.FarIntensity = Visual.DEPTH_OF_FIELD.farIntensity
	dof.FocusDistance = Visual.DEPTH_OF_FIELD.focusDistance
	dof.InFocusRadius = Visual.DEPTH_OF_FIELD.inFocusRadius
	dof.NearIntensity = Visual.DEPTH_OF_FIELD.nearIntensity

	-- Volumetric clouds live on Terrain, not Lighting. One instance, and the
	-- sky stops being a flat backdrop.
	local clouds = replace(Workspace.Terrain, "Clouds", "Clouds") :: Clouds
	clouds.Cover = Visual.CLOUDS.cover
	clouds.Density = Visual.CLOUDS.density
	clouds.Color = rgb(Visual.CLOUDS.color)

	print("[AtmosphereService] art direction applied")
end

return AtmosphereService
