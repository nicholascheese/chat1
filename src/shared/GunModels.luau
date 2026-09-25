--!strict
-- Builds each weapon out of plain Parts so the game works without uploading any meshes.
-- Swap a builder for a real mesh later by returning a cloned Model instead.
--
-- Local gun space (studs):  +X = muzzle,  +Y = up,  +Z = right side of the gun.
-- The origin sits roughly at the trigger / grip.

local GunModels = {}

type Finish = { color: Color3, material: Enum.Material, reflectance: number?, transparency: number? }

local FINISH: { [string]: Finish } = {
	wood = { color = Color3.fromRGB(112, 62, 30), material = Enum.Material.Wood },
	woodDark = { color = Color3.fromRGB(82, 45, 22), material = Enum.Material.Wood },
	steel = { color = Color3.fromRGB(52, 54, 58), material = Enum.Material.Metal, reflectance = 0.05 },
	parkerized = { color = Color3.fromRGB(62, 64, 60), material = Enum.Material.Metal },
	anodized = { color = Color3.fromRGB(34, 35, 38), material = Enum.Material.Metal },
	polymer = { color = Color3.fromRGB(26, 27, 29), material = Enum.Material.SmoothPlastic },
	rubber = { color = Color3.fromRGB(18, 18, 20), material = Enum.Material.Fabric },
	tan = { color = Color3.fromRGB(176, 148, 104), material = Enum.Material.SmoothPlastic },
	brass = { color = Color3.fromRGB(205, 160, 72), material = Enum.Material.Metal, reflectance = 0.15 },
	lens = { color = Color3.fromRGB(120, 200, 255), material = Enum.Material.Glass, transparency = 0.35 },
	dot = { color = Color3.fromRGB(255, 40, 40), material = Enum.Material.Neon },
}

type Builder = {
	model: Model,
	root: BasePart,
}

local function add(b: Builder, part: BasePart, size: Vector3, pos: Vector3, finish: string, rot: Vector3?)
	local f = FINISH[finish]
	local r = rot or Vector3.zero
	part.Size = size
	part.CFrame = b.root.CFrame
		* CFrame.new(pos)
		* CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	part.Color = f.color
	part.Material = f.material
	part.Reflectance = f.reflectance or 0
	part.Transparency = f.transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = b.model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.root
	weld.Part1 = part
	weld.Parent = part
end

-- Rectangular block. `rotZ` tilts the part in the gun's side profile (positive = front end up).
local function block(b: Builder, size: Vector3, pos: Vector3, finish: string, rotZ: number?)
	add(b, Instance.new("Part"), size, pos, finish, Vector3.new(0, 0, rotZ or 0))
end

-- Cylinder. Default axis runs along the barrel (X). Use axis "Y" or "Z" for knobs and pins.
local function cyl(b: Builder, length: number, diameter: number, pos: Vector3, finish: string, axis: string?)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local rot = Vector3.zero
	if axis == "Y" then
		rot = Vector3.new(0, 0, 90)
	elseif axis == "Z" then
		rot = Vector3.new(0, 90, 0)
	end
	add(b, part, Vector3.new(length, diameter, diameter), pos, finish, rot)
end

-- Row of small ribs for Picatinny rails.
local function rail(b: Builder, fromX: number, toX: number, y: number, width: number)
	local x = fromX
	while x <= toX do
		block(b, Vector3.new(0.045, 0.035, width), Vector3.new(x, y, 0), "anodized")
		x += 0.11
	end
end

local function newBuilder(name: string): Builder
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	return { model = model, root = root }
end

-- Shared AR-15 pattern receiver used by both the M16A1 and M4.
local function arReceiver(b: Builder, gripFinish: string)
	block(b, Vector3.new(1.1, 0.24, 0.2), Vector3.new(-0.3, 0.12, 0), "anodized") -- upper
	block(b, Vector3.new(0.9, 0.24, 0.18), Vector3.new(-0.3, -0.12, 0), "anodized") -- lower
	block(b, Vector3.new(0.3, 0.14, 0.2), Vector3.new(-0.08, -0.28, 0), "anodized") -- mag well
	block(b, Vector3.new(0.32, 0.1, 0.02), Vector3.new(-0.2, 0.1, 0.105), "steel") -- ejection port cover
	block(b, Vector3.new(0.08, 0.05, 0.24), Vector3.new(-0.82, 0.22, 0), "anodized") -- charging handle
	cyl(b, 0.2, 0.08, Vector3.new(-0.56, 0.18, 0.1), "steel") -- forward assist
	block(b, Vector3.new(0.2, 0.46, 0.16), Vector3.new(-0.64, -0.36, 0), gripFinish, -20) -- pistol grip
	block(b, Vector3.new(0.36, 0.04, 0.08), Vector3.new(-0.36, -0.31, 0), "anodized") -- trigger guard
	block(b, Vector3.new(0.04, 0.13, 0.04), Vector3.new(-0.4, -0.22, 0), "steel", 12) -- trigger
	cyl(b, 0.06, 0.06, Vector3.new(-0.55, 0.0, 0.1), "steel", "Z") -- selector
end

local builders: { [string]: () -> Model } = {}

builders.M1Garand = function()
	local b = newBuilder("M1Garand")

	-- Stock
	block(b, Vector3.new(1.35, 0.5, 0.22), Vector3.new(-1.75, -0.13, 0), "wood", 6) -- butt
	block(b, Vector3.new(0.06, 0.52, 0.23), Vector3.new(-2.42, -0.21, 0), "steel", 6) -- butt plate
	block(b, Vector3.new(0.75, 0.28, 0.2), Vector3.new(-0.85, -0.03, 0), "wood", 12) -- wrist
	block(b, Vector3.new(1.0, 0.3, 0.22), Vector3.new(-0.25, 0.0, 0), "wood") -- receiver bed
	block(b, Vector3.new(1.6, 0.22, 0.22), Vector3.new(1.0, 0.04, 0), "wood") -- forend

	-- Handguards
	block(b, Vector3.new(0.5, 0.1, 0.18), Vector3.new(0.4, 0.27, 0), "woodDark")
	block(b, Vector3.new(0.6, 0.1, 0.16), Vector3.new(1.3, 0.27, 0), "woodDark")

	-- Barrel bands
	block(b, Vector3.new(0.05, 0.34, 0.24), Vector3.new(0.85, 0.13, 0), "parkerized")
	block(b, Vector3.new(0.1, 0.3, 0.24), Vector3.new(1.85, 0.13, 0), "parkerized")

	-- Receiver + action
	block(b, Vector3.new(1.0, 0.2, 0.2), Vector3.new(-0.35, 0.22, 0), "parkerized")
	block(b, Vector3.new(0.34, 0.05, 0.14), Vector3.new(-0.25, 0.34, 0), "brass") -- en-bloc clip
	block(b, Vector3.new(0.6, 0.04, 0.03), Vector3.new(0.35, 0.18, 0.12), "parkerized") -- op rod
	block(b, Vector3.new(0.08, 0.07, 0.09), Vector3.new(0.05, 0.2, 0.14), "parkerized") -- op rod handle

	-- Sights
	block(b, Vector3.new(0.14, 0.14, 0.14), Vector3.new(-0.78, 0.38, 0), "parkerized")
	cyl(b, 0.05, 0.1, Vector3.new(-0.78, 0.37, 0.1), "steel", "Z") -- windage knob
	block(b, Vector3.new(0.06, 0.16, 0.05), Vector3.new(2.45, 0.34, 0), "parkerized") -- front post
	block(b, Vector3.new(0.08, 0.12, 0.02), Vector3.new(2.45, 0.32, 0.05), "parkerized")
	block(b, Vector3.new(0.08, 0.12, 0.02), Vector3.new(2.45, 0.32, -0.05), "parkerized")

	-- Barrel + gas cylinder
	cyl(b, 2.05, 0.1, Vector3.new(1.58, 0.22, 0), "steel")
	cyl(b, 0.5, 0.13, Vector3.new(2.3, 0.15, 0), "parkerized")

	-- Trigger group
	block(b, Vector3.new(0.3, 0.04, 0.08), Vector3.new(-0.45, -0.26, 0), "parkerized")
	block(b, Vector3.new(0.04, 0.1, 0.08), Vector3.new(-0.3, -0.2, 0), "parkerized")
	block(b, Vector3.new(0.04, 0.12, 0.04), Vector3.new(-0.5, -0.18, 0), "steel", 15)

	return b.model
end

builders.M16A1 = function()
	local b = newBuilder("M16A1")
	arReceiver(b, "polymer")

	-- Fixed A1 stock
	block(b, Vector3.new(1.1, 0.26, 0.2), Vector3.new(-1.42, 0.03, 0), "polymer")
	block(b, Vector3.new(1.1, 0.2, 0.19), Vector3.new(-1.48, -0.12, 0), "polymer", 10)
	block(b, Vector3.new(0.06, 0.5, 0.21), Vector3.new(-2.0, -0.07, 0), "rubber")

	-- Carry handle + rear sight
	block(b, Vector3.new(0.75, 0.07, 0.08), Vector3.new(-0.35, 0.42, 0), "anodized")
	block(b, Vector3.new(0.12, 0.2, 0.1), Vector3.new(-0.66, 0.32, 0), "anodized")
	block(b, Vector3.new(0.1, 0.18, 0.08), Vector3.new(-0.02, 0.31, 0), "anodized")
	block(b, Vector3.new(0.06, 0.1, 0.06), Vector3.new(-0.66, 0.48, 0), "steel")

	-- Handguard, delta ring, barrel
	cyl(b, 1.15, 0.3, Vector3.new(0.85, 0.12, 0), "polymer")
	cyl(b, 0.08, 0.36, Vector3.new(0.26, 0.12, 0), "anodized")
	cyl(b, 0.05, 0.31, Vector3.new(1.42, 0.12, 0), "anodized")
	cyl(b, 1.3, 0.08, Vector3.new(2.0, 0.12, 0), "steel")

	-- Triangle front sight
	block(b, Vector3.new(0.12, 0.14, 0.12), Vector3.new(1.65, 0.16, 0), "parkerized")
	block(b, Vector3.new(0.08, 0.3, 0.06), Vector3.new(1.65, 0.3, 0), "parkerized")
	block(b, Vector3.new(0.1, 0.08, 0.06), Vector3.new(1.65, 0.04, 0), "parkerized") -- bayonet lug

	-- Three-prong flash hider
	cyl(b, 0.28, 0.12, Vector3.new(2.72, 0.12, 0), "parkerized")

	-- 20 round magazine
	block(b, Vector3.new(0.26, 0.5, 0.14), Vector3.new(-0.06, -0.55, 0), "steel", 3)
	block(b, Vector3.new(0.28, 0.04, 0.16), Vector3.new(-0.05, -0.8, 0), "anodized", 3)

	return b.model
end

builders.M4 = function()
	local b = newBuilder("M4")
	arReceiver(b, "tan")

	-- Flat-top rail on the upper
	block(b, Vector3.new(1.1, 0.06, 0.14), Vector3.new(-0.3, 0.27, 0), "anodized")
	rail(b, -0.8, 0.2, 0.31, 0.16)

	-- Collapsible stock on buffer tube
	cyl(b, 0.9, 0.16, Vector3.new(-1.2, 0.1, 0), "anodized")
	block(b, Vector3.new(0.55, 0.3, 0.2), Vector3.new(-1.5, 0.07, 0), "tan")
	block(b, Vector3.new(0.45, 0.18, 0.18), Vector3.new(-1.55, -0.12, 0), "tan", 15)
	block(b, Vector3.new(0.07, 0.5, 0.2), Vector3.new(-1.8, -0.02, 0), "rubber")

	-- Quad rail handguard
	block(b, Vector3.new(1.0, 0.3, 0.3), Vector3.new(0.75, 0.12, 0), "anodized")
	block(b, Vector3.new(1.0, 0.06, 0.14), Vector3.new(0.75, 0.3, 0), "anodized")
	rail(b, 0.3, 1.2, 0.34, 0.16)
	block(b, Vector3.new(1.0, 0.12, 0.04), Vector3.new(0.75, 0.12, 0.17), "anodized")
	block(b, Vector3.new(1.0, 0.12, 0.04), Vector3.new(0.75, 0.12, -0.17), "anodized")

	-- Barrel, gas block, birdcage
	cyl(b, 0.85, 0.09, Vector3.new(1.6, 0.12, 0), "steel")
	block(b, Vector3.new(0.1, 0.14, 0.14), Vector3.new(1.35, 0.12, 0), "parkerized")
	cyl(b, 0.25, 0.12, Vector3.new(2.12, 0.12, 0), "parkerized")

	-- Vertical foregrip
	block(b, Vector3.new(0.14, 0.36, 0.14), Vector3.new(1.0, -0.2, 0), "tan")

	-- Curved 30 round magazine
	block(b, Vector3.new(0.26, 0.35, 0.14), Vector3.new(-0.06, -0.44, 0), "tan", 4)
	block(b, Vector3.new(0.26, 0.35, 0.14), Vector3.new(0.006, -0.781, 0), "tan", 18)
	block(b, Vector3.new(0.3, 0.05, 0.16), Vector3.new(0.065, -0.962, 0), "polymer", 18)

	-- Red dot sight
	block(b, Vector3.new(0.3, 0.1, 0.14), Vector3.new(-0.15, 0.36, 0), "anodized")
	cyl(b, 0.45, 0.28, Vector3.new(-0.15, 0.55, 0), "anodized")
	cyl(b, 0.04, 0.3, Vector3.new(0.06, 0.55, 0), "polymer") -- objective ring
	cyl(b, 0.02, 0.22, Vector3.new(0.09, 0.55, 0), "lens")
	cyl(b, 0.02, 0.22, Vector3.new(-0.385, 0.55, 0), "lens")
	cyl(b, 0.01, 0.03, Vector3.new(0.105, 0.55, 0), "dot")
	cyl(b, 0.08, 0.1, Vector3.new(-0.15, 0.71, 0), "anodized", "Y")
	cyl(b, 0.08, 0.1, Vector3.new(-0.15, 0.55, 0.16), "anodized", "Z")

	return b.model
end

-- Returns a fresh, anchored, non-colliding Model for the given gun id.
function GunModels.build(id: string): Model
	local builder = builders[id]
	assert(builder, "No model builder for gun: " .. tostring(id))
	return builder()
end

return GunModels
