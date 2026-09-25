--!strict
-- Single source of truth for every weapon in the game.
-- The selection screen, the preview models and (later) the combat system all read from here.

export type Stats = {
	damage: number, -- 0-100, used for the UI stat bars
	fireRate: number,
	range: number,
	accuracy: number,
	mobility: number,
}

export type Gun = {
	id: string,
	displayName: string,
	class: string,
	era: string,
	description: string,
	action: string,
	caliber: string,
	magSize: number,
	rpm: number,
	accent: Color3,
	stats: Stats,
}

local GunConfig = {}

GunConfig.Order = { "M1Garand", "M16A1", "M4" }

GunConfig.Guns = {
	M1Garand = {
		id = "M1Garand",
		displayName = "M1 GARAND",
		class = "BATTLE RIFLE",
		era = "1936",
		description = "Semi-automatic .30-06 workhorse. Hits like a truck at any range, but the 8-round en-bloc clip punishes missed shots.",
		action = "SEMI-AUTO",
		caliber = ".30-06",
		magSize = 8,
		rpm = 300,
		accent = Color3.fromRGB(255, 170, 60),
		stats = { damage = 92, fireRate = 30, range = 90, accuracy = 85, mobility = 40 },
	},
	M16A1 = {
		id = "M16A1",
		displayName = "M16A1",
		class = "ASSAULT RIFLE",
		era = "1967",
		description = "Full-length 5.56 rifle with a fixed stock and carry handle. Long barrel keeps it accurate at distance on full auto.",
		action = "FULL-AUTO",
		caliber = "5.56x45",
		magSize = 20,
		rpm = 750,
		accent = Color3.fromRGB(90, 220, 140),
		stats = { damage = 62, fireRate = 78, range = 72, accuracy = 70, mobility = 60 },
	},
	M4 = {
		id = "M4",
		displayName = "M4 CARBINE",
		class = "CARBINE",
		era = "1994",
		description = "Compact flat-top carbine with a red dot and foregrip. Fast handling and controllable recoil for close-quarters fights.",
		action = "FULL-AUTO",
		caliber = "5.56x45",
		magSize = 30,
		rpm = 850,
		accent = Color3.fromRGB(70, 170, 255),
		stats = { damage = 55, fireRate = 88, range = 55, accuracy = 74, mobility = 85 },
	},
} :: { [string]: Gun }

GunConfig.StatLabels = {
	{ key = "damage", label = "DAMAGE" },
	{ key = "fireRate", label = "FIRE RATE" },
	{ key = "range", label = "RANGE" },
	{ key = "accuracy", label = "ACCURACY" },
	{ key = "mobility", label = "MOBILITY" },
}

function GunConfig.get(id: string): Gun?
	return GunConfig.Guns[id]
end

return GunConfig
