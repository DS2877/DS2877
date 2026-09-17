--!strict
--[[
	Blocklists for generated Nomling names.

	WHY THIS EXISTS: the generator concatenates a head and a tail, and
	concatenation is exactly how accidental words appear. 876 names today, more
	with every content update, all shown to children. Manual screening does not
	scale and would not survive a single new species.

	tests/unit/namegen.spec.luau enumerates the FULL cross-product against these
	lists and fails CI on any hit. When a collision is found, the fix is to
	change the offending head or tail token in Nomlings.luau -- never to add a
	runtime filter. The generator stays pure and deterministic.

	Matching is SUBSTRING and case-insensitive, because "Taco" .. "ssup" would
	pass a word-boundary check and fail a human one.

	⚠️ THE PROFANITY LIST IS A STARTER, NOT A FINISHED ARTEFACT. It covers the
	obvious English cases plus a few high-frequency non-English ones, because
	Roblox auto-translates and our audience is global (docs/GDD.md). Before
	launch it should be replaced with a maintained multilingual list. Track as
	an M4 task.
]]

local NameSafety = {}

--- Substrings that must never appear in a generated name.
NameSafety.PROFANITY = {
	-- English
	"arse",
	"ass",
	"bastard",
	"bitch",
	"bollock",
	"bugger",
	"clit",
	"cock",
	"crap",
	"cum",
	"damn",
	"dick",
	"dildo",
	"fag",
	"fuck",
	"hell",
	"jizz",
	"knob",
	"nigg",
	"piss",
	"prick",
	"pussy",
	"queer",
	"rape",
	"retard",
	"shit",
	"slut",
	"spic",
	"tit",
	"twat",
	"wank",
	"whore",
	-- Swedish
	"fitta",
	"hora",
	"kuk",
	"jävla",
	"skit",
	-- German / Dutch
	"arsch",
	"fotze",
	"kanker",
	"scheiss",
	"scheiß",
	-- Spanish / Portuguese
	"caralho",
	"coño",
	"joder",
	"merda",
	"mierda",
	"puta",
	"verga",
	-- French
	"connard",
	"merde",
	"putain",
	-- Italian
	"cazzo",
	"stronzo",
	-- Russian (transliterated)
	"blyat",
	"suka",
	-- Turkish
	"orospu",
	"piç",
	-- Tagalog / Indonesian
	"anjing",
	"bangsat",
	"kontol",
	"puki",
	"tangina",
}

--- Brands and trademarks. The snack half of the roster is the risk surface,
--- and a future seasonal species could easily collide.
NameSafety.BRANDS = {
	"cocacola",
	"coke",
	"pepsi",
	"mcdonald",
	"burgerking",
	"kfc",
	"subway",
	"starbucks",
	"nestle",
	"kelloggs",
	"pringles",
	"oreo",
	"nutella",
	"haribo",
	"cadbury",
	"hershey",
	"mars",
	"snickers",
	"twix",
	"kitkat",
	"doritos",
	"cheetos",
	"lays",
	"dominos",
	"pizzahut",
	"taco bell",
	"tacobell",
	"wendys",
	"dunkin",
	"krispykreme",
	"benjerry",
	"haagen",
	"pokemon",
	"pikachu",
	"digimon",
	"mario",
	"minecraft",
	"fortnite",
	"disney",
	"pixar",
	"marvel",
	"nintendo",
	"sonic",
}

--- Terms likely to trip Roblox's own text filter, so a name never renders as
--- "####" in the reveal banner.
NameSafety.FILTER_RISK = {
	"discord",
	"roblox",
	"admin",
	"mod",
	"hack",
	"exploit",
	"scam",
	"free robux",
	"robux",
	"giveaway",
	"kill",
	"die",
	"gun",
	"blood",
	"sex",
	"porn",
	"nude",
	"drug",
	"weed",
	"vape",
	"beer",
	"wine",
	"vodka",
	"whisky",
	"rum",
}

--[[
	Words that are safe despite containing a flagged substring.

	Without this, a substring list is unusable: "Titan" contains "tit",
	"shell" contains "hell", "class" contains "ass". These are stripped from
	the name before scanning, so the real matches still land -- "Sushitiger"
	has no allowlisted word to strip and is still caught.

	Only add a word here when it is genuinely innocent. Never add one to make
	a failing test pass.
]]
NameSafety.ALLOWLIST = {
	"titan",
	"title",
	"tit for tat",
	"competition",
	"constitution",
	"assassin",
	"class",
	"glass",
	"grass",
	"pass",
	"bass",
	"compass",
	"hello",
	"shell",
	"shelter",
	"michelle",
	"cocktail",
	"cocoa",
	"cockatoo",
	"peacock",
	"analysis",
	"canal",
	"banal",
	"grape",
	"therapist",
	"scrape",
	"dickens",
	"sussex",
	"scunthorpe",
	"penistone",
	"mars bar",
	"marsh",
	"marshmallow",
}

--- Returns the offending term, or nil when the name is clean.
function NameSafety.check(name: string): string?
	local lowered = string.lower(name)
	-- Strip spaces so an affix boundary cannot hide a collision:
	-- "Mega Sshit" and "Megasshit" must both be caught.
	local squashed = string.gsub(lowered, "%s+", "")

	-- Strip innocent words first so their letters cannot trigger a match.
	for _, safe in NameSafety.ALLOWLIST do
		local needle = string.gsub(string.lower(safe), "%s+", "")
		squashed = string.gsub(squashed, needle, "")
	end

	for _, list in { NameSafety.PROFANITY, NameSafety.BRANDS, NameSafety.FILTER_RISK } do
		for _, term in list do
			local needle = string.gsub(string.lower(term), "%s+", "")
			if string.find(squashed, needle, 1, true) then
				return term
			end
		end
	end
	return nil
end

return NameSafety
