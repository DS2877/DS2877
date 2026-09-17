--!strict
--[[
	The single declaration of every remote in the game.

	NOTHING creates a RemoteEvent or RemoteFunction outside this module. One
	place to read means one place to audit -- which is the only way the
	"validate type, range, ownership and proximity" rule in docs/TECH.md stays
	true as the game grows.

	For Philip: a RemoteEvent is roughly a websocket message. The client can
	send anything it likes, including things our UI would never send, so the
	server treats every payload as hostile input.

	M0 declares no gameplay remotes yet -- only Ping, which exists so the
	smoke test can prove the transport works end to end.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Direction = "clientToServer" | "serverToClient" | "bidirectional"

export type RemoteSpec = {
	name: string,
	kind: "event" | "function",
	direction: Direction,
	--- Burst allowance per player.
	rateCapacity: number,
	--- Sustained calls per second per player.
	rateRefill: number,
	description: string,
}

local Net = {}

--- Every remote, with its rate limit. Add here first, implement second.
--- (Declared as a local so it can carry a type annotation -- Luau does not
--- allow annotating a table field assignment directly.)
local REMOTES: { [string]: RemoteSpec } = {
	Ping = {
		name = "Ping",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 3,
		rateRefill = 1,
		description = "Liveness check used by the M0 smoke test.",
	},

	--- Server -> client. The whole player-visible profile, pushed on join and
	--- after every change. Small enough to send entire, which removes a whole
	--- class of "client and server disagree" bugs.
	ProfileSync = {
		name = "ProfileSync",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "Pushes the player's profile snapshot to their client.",
	},

	--- Client -> server. Buys one egg of the named tier.
	--- The client sends only a tier key: never a price, never a rarity. Both
	--- are decided server-side from Config (docs/TECH.md, brief 5.1).
	BuyEgg = {
		name = "BuyEgg",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 4,
		rateRefill = 0.5,
		description = "Buys an egg of the given tier. Returns ok, reason.",
	},

	--- Server -> client. A short message for the player: someone took a
	--- Nomling, a snatch failed, an egg is ready. Never used for state.
	Notify = {
		name = "Notify",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "A one-line toast for the player.",
	},

	--- Server -> client. "Something just happened, and here is where."
	--- Feedback only: the client plays a sound and some particles. It never
	--- carries state, so a dropped one costs a sparkle and nothing else.
	Feedback = {
		name = "Feedback",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "Fires a juice cue (kind, position, extra) on the client.",
	},

	--- Client -> server. Buys the Nomling with this id off the belt.
	--- The id is a server-issued handle, not a description of the creature --
	--- the client cannot ask for a rarity, a mutation or a price.
	BuyFromBelt = {
		name = "BuyFromBelt",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 6,
		rateRefill = 1,
		description = "Buys a Nomling off the delivery belt. Returns ok, reason.",
	},

	--- Client -> server. Fetches the player's Fusion Book.
	--- Pulled on demand rather than pushed with every profile sync: it is
	--- hundreds of keys for a screen that is open for seconds at a time.
	GetBook = {
		name = "GetBook",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 4,
		rateRefill = 0.5,
		description = "Returns the player's discovered combinations and the totals.",
	},

	--- Client -> server. Re-Nom: trade everything for a permanent multiplier.
	--- Irreversible, so the client confirms first and the server re-checks the
	--- cost from Config rather than trusting that a confirmation happened.
	Rebirth = {
		name = "Rebirth",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 2,
		rateRefill = 0.2,
		description = "Performs a Re-Nom. Returns ok, reason.",
	},

	--- Client -> server. Takes one of YOUR OWN Nomlings off its pedestal and
	--- back into the book, freeing the slot.
	---
	--- Without this a base fills at eight creatures and the belt starts
	--- refusing purchases with no way out, which is a dead end rather than a
	--- decision.
	StoreNomling = {
		name = "StoreNomling",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 6,
		rateRefill = 1,
		description = "Moves one of your placed Nomlings back into the book.",
	},

	--- Client -> server. Fires the Bubble Wand.
	--- The client says "I pressed it"; the server decides who is in range and
	--- what happens. A client that could name its target could bubble anybody
	--- on the street from anywhere.
	Bubble = {
		name = "Bubble",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 3,
		rateRefill = 0.34,
		description = "Fires the Bubble Wand at the nearest carrier. Returns ok, reason.",
	},

	--- Client -> server. Starts a fusion from two owned Nomling ids.
	--- The client names two things it owns; the server decides everything
	--- about what comes out.
	StartFusion = {
		name = "StartFusion",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 3,
		rateRefill = 0.4,
		description = "Fuses two owned Nomlings. Returns ok, reason.",
	},

	--- Client -> server. Claims a finished fusion.
	ClaimFusion = {
		name = "ClaimFusion",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 3,
		rateRefill = 0.4,
		description = "Claims a finished fusion. Returns ok, reason.",
	},

	--- Server -> client. THE REVEAL. Carries the new creature's genome, its
	--- name, and whether this player is the first person anywhere to make it.
	FusionReveal = {
		name = "FusionReveal",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "Announces a finished fusion to the player who made it.",
	},

	--- Server -> everyone. Weather: incoming, started, or finished.
	Weather = {
		name = "Weather",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "Announces a weather event's phase to every client.",
	},

	--- Server -> everyone. A World First, announced across the server.
	WorldFirst = {
		name = "WorldFirst",
		kind = "event",
		direction = "serverToClient",
		rateCapacity = 0,
		rateRefill = 0,
		description = "Broadcasts a World First discovery to the whole server.",
	},

	--- Client -> server. Claims a finished incubator.
	--- The hatch roll happens here, on the server, when this is called -- never
	--- on purchase and never on the client.
	ClaimHatch = {
		name = "ClaimHatch",
		kind = "function",
		direction = "clientToServer",
		rateCapacity = 4,
		rateRefill = 0.5,
		description = "Claims a ready incubator and hatches it. Returns ok, reason.",
	},
}

Net.REMOTES = REMOTES

local FOLDER_NAME = "Net"

local folder: Folder? = nil

--- Server only. Creates the remote instances declared above.
function Net.build(): Folder
	assert(RunService:IsServer(), "Net.build() is server-only")

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end

	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME

	for _, spec in Net.REMOTES do
		local remote: Instance = if spec.kind == "event"
			then Instance.new("RemoteEvent")
			else Instance.new("RemoteFunction")
		remote.Name = spec.name
		remote.Parent = created
	end

	created.Parent = ReplicatedStorage
	folder = created
	return created
end

--- Resolves a declared remote by name. Errors on anything undeclared, which
--- makes a typo a startup failure rather than a silent no-op.
function Net.get(name: string): Instance
	assert(Net.REMOTES[name] ~= nil, `remote '{name}' is not declared in shared/Net`)

	local container = folder or ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
	assert(container ~= nil, "Net folder never replicated")
	folder = container :: Folder

	local remote = container:WaitForChild(name, 10)
	assert(remote ~= nil, `remote '{name}' never replicated`)
	return remote
end

return Net
