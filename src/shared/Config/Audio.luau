--!strict
--[[
	Every sound in the game, and the asset it comes from.

	ASSET IDS ARE FILLED IN AFTER UPLOAD. A Roblox sound needs an asset that
	lives on Roblox's servers; the .ogg in assets/audio/ is the source, and
	tools/upload-audio.py turns it into an id. Until an id is set here the
	entry is INERT -- the audio controller skips it silently rather than
	spamming the log with failed loads, so a missing upload degrades the game
	instead of breaking it.

	Volumes are deliberately low. This is a phone game played in public, often
	near other people, and a loop that is too loud is the fastest way to get
	muted permanently -- after which none of the audio design matters.
]]

local Audio = {}

export type Track = {
	assetId: number,
	volume: number,
	--- Seconds; 0 means "let the file decide".
	loopSeconds: number,
	fadeSeconds: number,
}

export type Cue = {
	assetId: number,
	volume: number,
	--- Randomised pitch range, so a sound heard fifty times a minute does not
	--- turn into a woodpecker. The single cheapest trick in game audio.
	pitchMin: number,
	pitchMax: number,
}

local MUSIC: { [string]: Track } = {
	--- "Nomling Glade" -- tools/music/score.py, docs/MUSIC.md.
	theme = {
		assetId = 0,
		volume = 0.32,
		loopSeconds = 110,
		fadeSeconds = 2.5,
	},
}

local SFX: { [string]: Cue } = {
	coin = { assetId = 0, volume = 0.18, pitchMin = 0.94, pitchMax = 1.12 },
	purchase = { assetId = 0, volume = 0.35, pitchMin = 0.98, pitchMax = 1.02 },
	hatch = { assetId = 0, volume = 0.45, pitchMin = 1.0, pitchMax = 1.0 },
	reveal = { assetId = 0, volume = 0.55, pitchMin = 1.0, pitchMax = 1.0 },
	snatchAlarm = { assetId = 0, volume = 0.40, pitchMin = 1.0, pitchMax = 1.0 },
	snatchGrab = { assetId = 0, volume = 0.35, pitchMin = 0.96, pitchMax = 1.06 },
	deny = { assetId = 0, volume = 0.25, pitchMin = 0.98, pitchMax = 1.02 },
}

Audio.MUSIC = MUSIC
Audio.SFX = SFX

--- How far the music ducks under a reveal, and for how long. A reveal is the
--- product; the theme gets out of its way.
Audio.DUCK_VOLUME = 0.35
Audio.DUCK_SECONDS = 2.5

--- True when the entry actually points at something playable.
function Audio.isReady(entry: { assetId: number }): boolean
	return entry.assetId > 0
end

function Audio.soundId(entry: { assetId: number }): string
	return `rbxassetid://{entry.assetId}`
end

return Audio
