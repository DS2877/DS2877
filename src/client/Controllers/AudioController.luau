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

--- Fetches every sound the game owns, and reports only what genuinely failed.
---
--- NO TIMER, and that is the point. The previous version waited twelve seconds
--- and then reported whatever state it found, which produced a red panel on a
--- phone reading `sfx loaded 0/21` -- alarming, and meaningless. Roblox does
--- not fetch a Sound's asset until the Sound is played or preloaded, and those
--- twenty-one pooled effects had never been played, so "none loaded" was the
--- expected reading rather than a fault. The theme, meanwhile, was simply still
--- downloading: it is a 113-second track, and twelve seconds is not a deadline,
--- it is a guess.
---
--- PreloadAsync blocks until each asset is resolved or refused, so after it
--- returns, TimeLength == 0 means the asset is genuinely unusable and anything
--- else means it is fine. That is a fact rather than a snapshot.
---
--- Preloading is also just better: the first coin sound of a session no longer
--- arrives late because its asset was still on the way.
local function preloadEverything(track: Sound?)
	local queue: { Sound } = {}
	if track then
		table.insert(queue, track)
	end
	for _, pool in pools do
		for _, cue in pool do
			table.insert(queue, cue)
		end
	end
	if #queue == 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(queue)
		end)
		if not ok then
			Fault.report(`audio preload refused: {err}`)
			return
		end

		local failed: { string } = {}
		for _, cue in queue do
			if cue.TimeLength <= 0 then
				table.insert(failed, cue.Name)
			end
		end
		if #failed > 0 then
			Fault.report(
				`audio unusable after preload ({#failed}/{#queue}): {table.concat(failed, ", ")}`
			)
		end
	end)
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

	preloadEverything(sound)
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
	-- Belt and braces: startMusic preloads with the theme, but it returns early
	-- when there is no theme asset yet, and the effects still deserve fetching.
	if not theme then
		preloadEverything(nil)
	end

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
