--!strict
--[[
	Shared type definitions.

	Kept engine-free where possible so tests/unit (Lune) can require the pure
	logic modules without a DataModel.
]]

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic" | "secret"

--- Integer parts-per-million. Every odds table MUST sum to exactly 1,000,000.
--- This is a compliance requirement, not a balance one -- Roblox requires
--- disclosed odds to total 100%. See docs/COMPLIANCE.md section 2.
export type Ppm = number

export type OddsTable = { [Rarity]: Ppm }

export type Genome = {
	snack: string,
	animal: string,
	gen: number,
	affix: string?,
	mutation: string?,
	seed: number,
}

export type Service = {
	Name: string,
	init: (() -> ())?,
	start: (() -> ())?,
}

export type Controller = Service

return {}
