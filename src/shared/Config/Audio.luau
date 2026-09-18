--!strict
--[[
	Every sound in the game, and the asset it comes from.

	ASSET IDS ARE FILLED IN AFTER UPLOAD. A Roblox sound needs an asset that
	lives on Roblox's servers; the .ogg in assets/audio/ is the source, and
	tools/upload-audio.py turns it into an id. Until an id is set here the
	entry is INERT -- the audio controller skips it silently rather than
	spamming the log with failed loads, so a missing upload degrades the game
	instead of breaking it.

	All eight were uploaded on 2026-09-17 and the ids below are live. DO NOT
	re-run the upload to "refresh" them: Roblox audio is not updatable in place,
	so a re-run mints NEW assets and spends the monthly quota (10/month while
	the account is not ID-verified, and there are eight files). Changing a sound
	means re-rendering it and uploading deliberately, not by accident.

	Volumes are deliberately low. This is a phone game played in public, often
	near other people, and a loop that is too loud is the fastest way to get
	muted permanently -- after which none of the audio design matters.

	EVERY NUMBER HERE IS THE FINAL LEVEL. It is what comes out of the speaker,
	not a value something else scales again. AudioController's SoundGroups are
	plain 0..1 faders; for a while the music group was being set to a track
	volume as well, which multiplied 0.32 by 0.32 and made the theme inaudible
	while every asset was approved, loaded and playing. If a level needs
	changing, change it here -- and nowhere else.
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
		assetId = 75643474514379,
		volume = 0.32,
		loopSeconds = 110,
		fadeSeconds = 2.5,
	},
}

local SFX: { [string]: Cue } = {
	coin = { assetId = 77598228361385, volume = 0.18, pitchMin = 0.94, pitchMax = 1.12 },
	purchase = { assetId = 117104174715104, volume = 0.35, pitchMin = 0.98, pitchMax = 1.02 },
	hatch = { assetId = 112783269074814, volume = 0.45, pitchMin = 1.0, pitchMax = 1.0 },
	reveal = { assetId = 80554080887908, volume = 0.55, pitchMin = 1.0, pitchMax = 1.0 },
	snatchAlarm = { assetId = 73916737620191, volume = 0.40, pitchMin = 1.0, pitchMax = 1.0 },
	snatchGrab = { assetId = 127735790445507, volume = 0.35, pitchMin = 0.96, pitchMax = 1.06 },
	deny = { assetId = 71979898233075, volume = 0.25, pitchMin = 0.98, pitchMax = 1.02 },
}

Audio.MUSIC = MUSIC
Audio.SFX = SFX

--- Cues that exist but must not play.
---
--- `coin` fires every time the purse ticks up, which on a base earning steadily
--- is several times a second. A playtester's verdict was blunt -- "the sound
--- from earnings is terrible, remove/mute for now" -- and a sound heard that
--- often has to be nearly nothing or it becomes the whole game.
---
--- MUTED HERE RATHER THAN DELETED. The asset is uploaded and Roblox audio
--- cannot be replaced in place, so throwing the id away would spend another of
--- ten monthly upload slots to get it back. Removing a name from this table is
--- the whole of turning it on again; the coin still FLIES, because the picture
--- was never the problem.
local MUTED: { [string]: boolean } = {
	coin = true,
}

Audio.MUTED = MUTED

--- True when a cue is declared but deliberately silenced.
function Audio.isMuted(name: string): boolean
	return MUTED[name] == true
end

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
