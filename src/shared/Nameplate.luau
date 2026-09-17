--!strict
--[[
	The sign over a Nomling's head.

	ONE headline and ONE detail line, at different sizes, in one BillboardGui.
	The first version put everything in a single TextScaled label, which makes
	every line the same size -- so at any distance the name, the rarity and the
	price were equally small, and a phone playtest screenshot showed the whole
	street as stacks of unreadable grey text.

	A billboard sized in scale shrinks with distance, so legibility is a
	function of how many lines share the box. Two labels with a real size
	difference means the thing you need from across the street (is it mutated?
	what does it cost?) stays readable after the thing you only need up close
	has stopped being.

	Lives in Shared rather than Logic: it builds Instances, so Lune cannot test
	it, and `src/shared/Logic/` is reserved for modules that require nothing.
]]

local Style = require(script.Parent:WaitForChild("Style"))

local Nameplate = {}

export type Config = {
	--- The loud line. A mutation, or the creature's name.
	headline: string,
	headlineColor: Color3?,
	--- The quiet line underneath: rarity, income, price.
	detail: string,
	--- Rarity's colour belongs on the line that carries the rarity WORD, not on
	--- the name -- colour and label together is what GDD 5.16 asks for, and a
	--- common creature's grey on the headline just reads as "disabled".
	detailColor: Color3?,
	--- Studs above the anchor's centre.
	height: number,
	--- Past this the sign is texture, not information.
	maxDistance: number,
}

local function line(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	colour: Color3,
	weight: number
): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = size
	text.Position = position
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = false
	text.TextColor3 = colour
	text.TextStrokeTransparency = weight
	text.Text = ""
	text.Parent = parent
	return text
end

--- Builds the sign and parents it to `anchor`. Returns it so the caller can
--- keep updating the text without rebuilding.
function Nameplate.build(anchor: BasePart, config: Config): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(11, 3.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, config.height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = config.maxDistance
	gui.Parent = anchor

	-- 62/38. Enough of a difference to read as a hierarchy rather than as two
	-- lines that happen to be slightly different.
	local headline = line(
		gui,
		UDim2.fromScale(1, 0.62),
		UDim2.fromScale(0, 0),
		config.headlineColor or Style.PALETTE.nomCream,
		0.25
	)
	headline.Text = config.headline

	local detail = line(
		gui,
		UDim2.fromScale(1, 0.38),
		UDim2.fromScale(0, 0.62),
		config.detailColor or Style.PALETTE.nomCream,
		0.3
	)
	detail.Text = config.detail

	return gui, headline, detail
end

return Nameplate
