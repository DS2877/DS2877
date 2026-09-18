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

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))

local Fault = require(script.Parent.Parent:WaitForChild("Fault"))

local AudioController = {}
AudioController.Name = "AudioController"

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local theme: Sound? = nil
local duckUntil = 0
local rng = Random.new()

--- Where the music fader starts before it rides up. Not zero: a fade that
--- begins at silence makes "the tween never ran" and "there is no music"
--- indistinguishable, which cost a whole playtest round.
local MUSIC_FADE_FROM = 0.35

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
	duckUntil = os.clock() + (seconds or Audio.DUCK_SECONDS)
	TweenService:Create(
		musicGroup,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = Audio.DUCK_VOLUME }
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

	-- THE GROUP IS A FADER, NOT A LEVEL. This is the whole reason for "I don't
	-- have a themesong playing in the background" while Roblox reported every
	-- asset Approved and owned by the right account.
	--
	-- SoundGroup.Volume MULTIPLIES Sound.Volume. The old code set the sound to
	-- track.volume (0.32) and then set the GROUP to track.volume as well, so
	-- what came out was 0.32 x 0.32 -- about 10% -- of a level that was already
	-- chosen to be discreet on a phone in public. Roughly 3% of full scale.
	-- Playing, correct, loaded, entirely inaudible, and invisible from the code
	-- because both numbers looked reasonable on their own line.
	--
	-- So: the sound carries the mix level, the group carries 0..1 and nothing
	-- else. It fades in from MUSIC_FADE_FROM rather than from zero, so a failure
	-- between here and the tween finishing is quiet music rather than no music.
	musicGroup.Volume = MUSIC_FADE_FROM
	sound:Play()
	TweenService:Create(
		musicGroup,
		TweenInfo.new(track.fadeSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Volume = 1 }
	):Play()

	-- DID THE ASSET ACTUALLY ARRIVE? An id that is valid, approved and owned
	-- still plays nothing if this client failed to fetch it, and Sound raises
	-- no error for that.
	--
	-- PreloadAsync is the documented way to force the fetch and is the only
	-- thing that prints Roblox's own reason for a refusal. It yields, so it
	-- gets its own thread, and it is pcall'd because it throws on an asset the
	-- experience is not allowed to use -- which is itself the answer.
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync({ sound })
		end)
		if not ok then
			Fault.report(`theme {track.assetId} preload refused: {err}`)
		end
	end)

	-- AND THEN REPORT THE STATE, NOT A GUESS. The first version of this check
	-- fired on `not IsLoaded` alone, which says nothing about whether there is
	-- music coming out of the phone -- so it risked becoming a permanent red
	-- line that hides the next real fault. It now stays quiet when the track is
	-- genuinely playing, and when it is not it prints everything needed to tell
	-- the three candidates apart in one line:
	--
	--   sfx 0/7 too      -- the whole account's audio is unreachable here.
	--   sfx 7/7, theme 0 -- only the LONG asset is, which points at Roblox's
	--                       asset privacy: audio is private by default and an
	--                       experience needs explicit permission
	--                       (create.roblox.com/docs/audio/assets, docs/VERIFY.md).
	--   loaded and playing but silent -- a volume bug, ours.
	task.delay(12, function()
		if theme ~= sound then
			return
		end
		if sound.IsPlaying and sound.TimeLength > 0 then
			return
		end

		local ready, total = 0, 0
		for _, pool in pools do
			for _, cue in pool do
				total += 1
				if cue.IsLoaded then
					ready += 1
				end
			end
		end

		Fault.report(
			`theme {track.assetId}: loaded={sound.IsLoaded} playing={sound.IsPlaying} `
				.. `len={sound.TimeLength} vol={sound.Volume}x{musicGroup.Volume} `
				.. `sfx loaded {ready}/{total}`
		)
	end)
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
					{ Volume = 1 }
				):Play()
			end
		end
	end)
end

return AudioController
