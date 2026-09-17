--!strict
--[[
	Plays the music and the sound effects.

	Client-side on purpose: music is a per-player experience, and every sound
	here is feedback for something that player did. Nothing is replicated, so
	nothing costs bandwidth.

	Three things make game audio feel expensive rather than cheap, and all
	three are here:

	1. NOTHING STARTS ABRUPTLY. The theme fades in; ducking ramps rather than
	   jumping.
	2. REPEATED SOUNDS ARE PITCH-VARIED. A coin heard fifty times a minute at
	   exactly the same pitch turns into a woodpecker within a minute.
	3. THE MUSIC GETS OUT OF THE WAY. A reveal ducks the theme, because the
	   reveal is the product and the loop is the furniture.

	Missing assets are skipped silently -- see Config/Audio.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))

local AudioController = {}
AudioController.Name = "AudioController"

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local theme: Sound? = nil
local duckUntil = 0
local rng = Random.new()

--- A small pool per cue. Creating a Sound per play would churn instances on a
--- phone; reusing a handful does not.
local POOL_SIZE = 3
local pools: { [string]: { Sound } } = {}
local poolCursor: { [string]: number } = {}

local function buildPool(name: string, cue: Audio.Cue)
	local sounds: { Sound } = {}
	for i = 1, POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = `{name}_{i}`
		sound.SoundId = Audio.soundId(cue)
		sound.Volume = cue.volume
		sound.SoundGroup = sfxGroup
		sound.Parent = SoundService
		sounds[i] = sound
	end
	pools[name] = sounds
	poolCursor[name] = 0
end

--- Plays a one-shot cue by name. Unknown or not-yet-uploaded names are a
--- no-op, so callers never need to check.
function AudioController.play(name: string)
	local cue = Audio.SFX[name]
	if not cue or not Audio.isReady(cue) then
		return
	end
	local pool = pools[name]
	if not pool then
		return
	end
	local index = (poolCursor[name] % POOL_SIZE) + 1
	poolCursor[name] = index
	local sound = pool[index]
	sound.PlaybackSpeed = rng:NextNumber(cue.pitchMin, cue.pitchMax)
	sound:Play()
end

--- Pulls the music down for a moment. Used by the reveal.
function AudioController.duck(seconds: number?)
	if not theme then
		return
	end
	local track = Audio.MUSIC.theme
	duckUntil = os.clock() + (seconds or Audio.DUCK_SECONDS)
	TweenService:Create(
		musicGroup,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = track.volume * Audio.DUCK_VOLUME }
	):Play()
end

local function startMusic()
	local track = Audio.MUSIC.theme
	if not Audio.isReady(track) then
		-- Expected before the first upload. Said once, at info level, so it is
		-- discoverable without being noise.
		print("[AudioController] no theme asset id yet -- see docs/MUSIC.md")
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Theme"
	sound.SoundId = Audio.soundId(track)
	sound.Looped = true
	sound.Volume = track.volume
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	theme = sound

	-- AUDIBLE FIRST, PRETTY SECOND. This used to set the group to 0 and rely on
	-- a tween to bring it up, which means any failure between here and the
	-- tween completing leaves the music playing at silence -- indistinguishable
	-- from no music at all, and impossible to tell apart from a missing asset.
	--
	-- Roblox confirmed all eight assets Approved while a playtester reported
	-- total silence, so the fault is on this side and this is the one place
	-- where a fade could swallow it. Start at volume, fade from slightly under
	-- it: still a fade in, but the failure mode is "it started a bit loud"
	-- rather than "there is no music in this game".
	musicGroup.Volume = track.volume * 0.35
	sound:Play()
	TweenService:Create(
		musicGroup,
		TweenInfo.new(track.fadeSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Volume = track.volume }
	):Play()
end

function AudioController.start()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 0
	musicGroup.Parent = SoundService

	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "SFX"
	sfxGroup.Volume = 1
	sfxGroup.Parent = SoundService

	for name, cue in Audio.SFX do
		if Audio.isReady(cue) then
			buildPool(name, cue)
		end
	end

	startMusic()

	-- Restore the music level once a duck expires. Polled rather than
	-- scheduled so overlapping ducks extend cleanly instead of fighting.
	task.spawn(function()
		while true do
			task.wait(0.2)
			if theme and duckUntil > 0 and os.clock() >= duckUntil then
				duckUntil = 0
				TweenService:Create(
					musicGroup,
					TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Volume = Audio.MUSIC.theme.volume }
				):Play()
			end
		end
	end)
end

return AudioController
