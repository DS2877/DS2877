--!strict
--[[
	The Fusion Book: what this player has discovered.

	"Collect them all" is the stickiest hook there is for a nine-year-old, and
	it is free content -- the creatures already exist, the book just makes the
	space VISIBLE. A player who can see 137 of 876 filled in has a reason to
	keep fusing that no amount of coins-per-second provides.

	The book is recorded on ACQUISITION, wherever a creature comes from: hatched,
	bought off the belt, fused, or snatched from somebody else. One place decides
	the key so those four paths cannot disagree.

	It survives a Re-Nom. What a player has discovered is the one thing they
	cannot be asked to give up twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameGen = require(Shared:WaitForChild("Logic"):WaitForChild("NameGen"))
local Net = require(Shared:WaitForChild("Net"))
local Nomlings = require(Shared:WaitForChild("Config"):WaitForChild("Nomlings"))
local Profile = require(Shared:WaitForChild("Logic"):WaitForChild("Profile"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local BookService = {}
BookService.Name = "BookService"

--- The Book key for a stored creature.
---
--- A fused creature carries a snack from one parent and an animal from another,
--- so each half is resolved back to the species that contributed it.
function BookService.keyFor(nomling: Profile.Nomling): string?
	local snackSpecies = Nomlings.BY_SNACK[nomling.snack]
	local animalSpecies = Nomlings.BY_ANIMAL[nomling.animal]
	if not snackSpecies or not animalSpecies then
		-- A creature from a content update this server does not know about.
		-- Skipped rather than guessed at: a wrong key would be permanent.
		return nil
	end
	local affix = if nomling.gen >= 3
		then NameGen.affixForSeed(nomling.seed, Nomlings.GEN3_AFFIXES)
		else nil
	return NameGen.comboKey(snackSpecies.id, animalSpecies.id, nomling.gen, affix)
end

--- Records a creature. Returns true only the first time, so a caller can
--- celebrate a genuinely new discovery and stay quiet about a duplicate.
function BookService.record(data: Profile.Data, nomling: Profile.Nomling): boolean
	local key = BookService.keyFor(nomling)
	if not key then
		return false
	end
	return Profile.discover(data, key)
end

--- Totals, derived from the roster rather than hardcoded, so adding a species
--- updates the denominator automatically (docs/NOMLINGS.md 3).
function BookService.totals(): { species: number, gen2: number, gen3: number, all: number }
	local n = #Nomlings.SPECIES
	local gen2 = n * n
	local gen3 = gen2 * #Nomlings.GEN3_AFFIXES
	return { species = n, gen2 = gen2, gen3 = gen3, all = n + gen2 + gen3 }
end

function BookService.start()
	local remote = Net.get("GetBook") :: RemoteFunction
	remote.OnServerInvoke = function(player)
		local data = DataService.get(player)
		if not data then
			return nil
		end
		-- The whole set, but only when asked. Sending it in every profile sync
		-- would put hundreds of keys on the wire once a second for a screen
		-- that is open for a few seconds at a time.
		local discovered: { string } = {}
		for key in data.book do
			table.insert(discovered, key)
		end
		return {
			discovered = discovered,
			count = #discovered,
			totals = BookService.totals(),
		}
	end
end

return BookService
