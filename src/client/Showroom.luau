--!strict
-- The 3D armory the player sees behind the selection UI: a dark room with a glowing
-- turntable, spotlights and a holographic wall, plus the camera that orbits the gun.
-- Everything here is created on the client only, so every player gets their own private lobby.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)
local GunModels = require(ReplicatedStorage.Shared.GunModels)

local ORIGIN = Vector3.new(0, 600, 0) -- far above the map so it never overlaps gameplay
local GUN_POINT = ORIGIN + Vector3.new(0, 4.6, 0)
local PEDESTAL_TOP = ORIGIN.Y + 1.45

local CAMERA_HEIGHT = 1.1
local ZOOM_DEFAULT = 11
local ZOOM_MIN = 6.5
local ZOOM_MAX = 14
local AUTO_SPIN_SPEED = 0.4 -- rad/s
local AUTO_SPIN_DELAY = 2.5 -- seconds after the player lets go
local SWAP_OUT_TIME = 0.22
local SWAP_IN_TIME = 0.55

local RENDER_STEP = "ArmoryShowroom"

local Showroom = {}
Showroom.__index = Showroom

export type Showroom = typeof(setmetatable(
	{} :: {
		folder: Folder,
		accentParts: { BasePart },
		accentLights: { Light },
		pedestalLight: PointLight,
		scanRing: BasePart,
		holoTitle: TextLabel,
		holoSub: TextLabel,
		effects: { Instance },
		connections: { RBXScriptConnection },
		savedLighting: { [string]: any },

		gun: Model?,
		outgoing: Model?,
		outgoingT: number,
		incomingT: number,
		scanT: number,

		yaw: number,
		yawVelocity: number,
		dragging: boolean,
		lastInteract: number,
		zoom: number,
		zoomTarget: number,
		camOffset: Vector3,
		clock: number,
	},
	Showroom
))

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Vertical cylinder (Roblox cylinders run along X, so tip it onto its side).
local function disc(height: number, diameter: number, y: number, props: { [string]: any }): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(ORIGIN.X, y, ORIGIN.Z) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
end

local function spotlight(parent: Instance, from: Vector3, color: Color3, brightness: number, angle: number): SpotLight
	local holder = part({
		Name = "LightRig",
		Size = Vector3.new(0.6, 0.6, 0.6),
		Transparency = 1,
		CFrame = CFrame.lookAt(from, GUN_POINT),
		Parent = parent,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color = color
	light.Brightness = brightness
	light.Range = 40
	light.Angle = angle
	light.Shadows = true
	light.Parent = holder
	return light
end

local function easeOutBack(t: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function easeInQuad(t: number): number
	return t * t
end

function Showroom.new(): Showroom
	local self = setmetatable({}, Showroom) :: Showroom
	self.accentParts = {}
	self.accentLights = {}
	self.effects = {}
	self.connections = {}
	self.savedLighting = {}
	self.outgoingT = 1
	self.incomingT = 1
	self.scanT = 1
	self.yaw = math.rad(-25)
	self.yawVelocity = 0
	self.dragging = false
	self.lastInteract = -math.huge
	self.zoom = ZOOM_DEFAULT + 4 -- starts pulled back and glides in
	self.zoomTarget = ZOOM_DEFAULT
	self.camOffset = Vector3.zero
	self.clock = 0

	self:_buildRoom()
	self:_applyAtmosphere()
	self:_bindInput()
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_step(dt)
	end)
	return self
end

function Showroom._buildRoom(self: Showroom)
	local folder = Instance.new("Folder")
	folder.Name = "ArmoryShowroom"
	self.folder = folder

	local wallColor = Color3.fromRGB(22, 23, 27)
	local trimColor = Color3.fromRGB(38, 40, 46)

	-- Shell
	part({ Name = "Floor", Size = Vector3.new(80, 1, 80), CFrame = CFrame.new(ORIGIN - Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(30, 32, 36), Material = Enum.Material.DiamondPlate, Parent = folder })
	part({ Name = "Ceiling", Size = Vector3.new(80, 1, 80), CFrame = CFrame.new(ORIGIN + Vector3.new(0, 24, 0)),
		Color = Color3.fromRGB(10, 10, 12), Material = Enum.Material.Metal, Parent = folder })
	local backWall = part({ Name = "BackWall", Size = Vector3.new(80, 26, 1), CFrame = CFrame.new(ORIGIN + Vector3.new(0, 12, -18)),
		Color = wallColor, Material = Enum.Material.Metal, Parent = folder })
	part({ Name = "FrontWall", Size = Vector3.new(80, 26, 1), CFrame = CFrame.new(ORIGIN + Vector3.new(0, 12, 30)),
		Color = wallColor, Material = Enum.Material.Metal, Parent = folder })
	for _, side in { -1, 1 } do
		part({ Name = "SideWall", Size = Vector3.new(1, 26, 50), CFrame = CFrame.new(ORIGIN + Vector3.new(side * 24, 12, 6)),
			Color = wallColor, Material = Enum.Material.Metal, Parent = folder })
	end

	-- Back wall ribs + light strips
	for x = -20, 20, 5 do
		part({ Name = "Rib", Size = Vector3.new(0.8, 26, 0.8), CFrame = CFrame.new(ORIGIN + Vector3.new(x, 12, -17.3)),
			Color = trimColor, Material = Enum.Material.Metal, Parent = folder })
	end
	table.insert(self.accentParts, part({ Name = "Strip", Size = Vector3.new(48, 0.12, 0.2),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 1.2, -16.8)), Material = Enum.Material.Neon, Parent = folder }))
	for _, x in { -20, -15, 15, 20 } do
		table.insert(self.accentParts, part({ Name = "LightBar", Size = Vector3.new(0.15, 20, 0.1),
			CFrame = CFrame.new(ORIGIN + Vector3.new(x, 12, -16.85)), Material = Enum.Material.Neon, Transparency = 0.25, Parent = folder }))
	end
	-- Floor guide lines leading from the camera to the turntable
	for _, x in { -2.6, 2.6 } do
		table.insert(self.accentParts, part({ Name = "FloorLine", Size = Vector3.new(0.12, 0.04, 18),
			CFrame = CFrame.new(ORIGIN + Vector3.new(x, 0.02, 14)), Material = Enum.Material.Neon, Transparency = 0.35, Parent = folder }))
	end

	-- Holographic wall text
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- +Z, facing into the room
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = backWall

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.6)
	title.Size = UDim2.fromScale(0.35, 0.22)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextTransparency = 0.82
	title.Text = ""
	title.Parent = gui
	self.holoTitle = title

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.745)
	sub.Size = UDim2.fromScale(0.3, 0.03)
	sub.Font = Enum.Font.RobotoMono
	sub.TextScaled = true
	sub.TextTransparency = 0.6
	sub.Text = ""
	sub.Parent = gui
	self.holoSub = sub

	-- Turntable
	disc(1.4, 9, ORIGIN.Y + 0.7, { Name = "Pedestal", Color = Color3.fromRGB(26, 27, 31), Material = Enum.Material.Metal, Parent = folder })
	disc(0.1, 8.4, PEDESTAL_TOP, { Name = "PedestalTop", Color = Color3.fromRGB(46, 48, 54), Material = Enum.Material.DiamondPlate, Parent = folder })
	table.insert(self.accentParts, disc(0.18, 9.3, ORIGIN.Y + 1.15, { Name = "Ring", Material = Enum.Material.Neon, Parent = folder }))
	table.insert(self.accentParts, disc(0.04, 11.5, ORIGIN.Y + 0.03, { Name = "FloorHalo", Material = Enum.Material.Neon, Transparency = 0.55, Parent = folder }))
	table.insert(self.accentParts, disc(7, 6.8, PEDESTAL_TOP + 3.5, { Name = "Beam", Material = Enum.Material.Neon, Transparency = 0.965, Parent = folder }))

	-- Sweeping "scan" ring played when a gun materializes
	self.scanRing = disc(0.03, 7.5, PEDESTAL_TOP, { Name = "Scan", Material = Enum.Material.Neon, Transparency = 1, Parent = folder })
	table.insert(self.accentParts, self.scanRing)

	-- Lights
	spotlight(folder, ORIGIN + Vector3.new(7, 15, 9), Color3.fromRGB(255, 244, 228), 5, 40) -- key
	spotlight(folder, ORIGIN + Vector3.new(-9, 8, 7), Color3.fromRGB(170, 190, 255), 1.4, 50) -- fill
	table.insert(self.accentLights, spotlight(folder, ORIGIN + Vector3.new(0, 11, -12), Color3.new(1, 1, 1), 7, 35)) -- rim

	local glowAnchor = part({ Name = "PedestalGlow", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1,
		CFrame = CFrame.new(ORIGIN.X, PEDESTAL_TOP + 0.5, ORIGIN.Z), Parent = folder })
	local pedestalLight = Instance.new("PointLight")
	pedestalLight.Range = 9
	pedestalLight.Brightness = 1.5
	pedestalLight.Parent = glowAnchor
	self.pedestalLight = pedestalLight
	table.insert(self.accentLights, pedestalLight)

	-- Floating dust in the light beams
	local dustVolume = part({ Name = "Dust", Size = Vector3.new(26, 12, 18), Transparency = 1,
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 7, 2)), Parent = folder })
	local dust = Instance.new("ParticleEmitter")
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Rate = 14
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.1, 0.35)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.05)
	dust.LightEmission = 1
	dust.LightInfluence = 0
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = dustVolume

	folder.Parent = workspace
end

function Showroom._applyAtmosphere(self: Showroom)
	for _, key in { "Ambient", "ExposureCompensation" } do
		self.savedLighting[key] = (Lighting :: any)[key]
	end
	Lighting.Ambient = Color3.fromRGB(18, 19, 24)
	Lighting.ExposureCompensation = 0.2

	local camera = workspace.CurrentCamera
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 0.92
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.12
	grade.Saturation = -0.08
	grade.TintColor = Color3.fromRGB(235, 242, 255)
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.55
	dof.NearIntensity = 0
	dof.FocusDistance = ZOOM_DEFAULT
	dof.InFocusRadius = 5
	for _, effect in { bloom, grade, dof } do
		effect.Parent = camera
		table.insert(self.effects, effect)
	end
end

function Showroom._bindInput(self: Showroom)
	local function isPointer(input: InputObject)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if isPointer(input) then
			self.dragging = true
			self.lastInteract = self.clock
		end
	end))

	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			self.dragging = false
			self.lastInteract = self.clock
		end
	end))

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			self.zoomTarget = math.clamp(self.zoomTarget - input.Position.Z * 0.9, ZOOM_MIN, ZOOM_MAX)
		elseif self.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			self.yawVelocity = input.Delta.X * 0.35 -- rad/s fling when released
			self.yaw += input.Delta.X * 0.012
			self.lastInteract = self.clock
		end
	end))

	-- Pinch to zoom on touch screens
	table.insert(self.connections, UserInputService.TouchPinch:Connect(function(_, _, velocity, _, processed)
		if not processed then
			self.zoomTarget = math.clamp(self.zoomTarget - (velocity :: number) * 0.05, ZOOM_MIN, ZOOM_MAX)
		end
	end))
end

-- Instantly recolour the room's neon, then flash the pedestal light.
function Showroom.setAccent(self: Showroom, color: Color3)
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, p in self.accentParts do
		TweenService:Create(p, info, { Color = color }):Play()
	end
	for _, light in self.accentLights do
		TweenService:Create(light, info, { Color = color }):Play()
	end
	self.holoTitle.TextColor3 = color
	self.holoSub.TextColor3 = color

	self.pedestalLight.Brightness = 6
	TweenService:Create(self.pedestalLight, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Brightness = 1.5 }):Play()
end

function Showroom.setGun(self: Showroom, id: string)
	local config = GunConfig.get(id)
	assert(config, "Unknown gun " .. id)

	-- Send the old gun down into the pedestal
	if self.outgoing then
		self.outgoing:Destroy()
	end
	self.outgoing = self.gun
	self.outgoingT = 0

	local model = GunModels.build(id)
	local center = model:GetBoundingBox()
	model.WorldPivot = center
	model:ScaleTo(0.6)
	model:PivotTo(CFrame.new(GUN_POINT - Vector3.new(0, 2, 0)))
	model.Parent = self.folder
	self.gun = model
	self.incomingT = 0
	self.scanT = 0

	self.holoTitle.Text = config.displayName
	self.holoSub.Text = string.format("%s  //  %s  //  EST. %s", config.class, config.caliber, config.era)
	self:setAccent(config.accent)
end

function Showroom._step(self: Showroom, dt: number)
	self.clock += dt
	local t = self.clock

	-- Turntable rotation: drag with inertia, then drift back to a slow auto spin.
	self.yawVelocity *= math.exp(-4 * dt)
	if not self.dragging then
		local idle = t - self.lastInteract > AUTO_SPIN_DELAY
		self.yaw += (self.yawVelocity + (if idle then AUTO_SPIN_SPEED else 0)) * dt
	end

	local bob = math.sin(t * 1.3) * 0.08
	local tilt = math.rad(math.sin(t * 0.7) * 2.5)
	local baseCF = CFrame.new(GUN_POINT + Vector3.new(0, bob, 0)) * CFrame.Angles(0, self.yaw, tilt)

	-- Incoming gun rises out of the pedestal and pops to full size
	if self.gun then
		if self.incomingT < 1 then
			self.incomingT = math.min(self.incomingT + dt / SWAP_IN_TIME, 1)
			local e = easeOutBack(self.incomingT)
			self.gun:ScaleTo(if self.incomingT >= 1 then 1 else 0.6 + 0.4 * e)
			local rise = (1 - e) * -2
			local extraSpin = (1 - e) * math.rad(-120)
			self.gun:PivotTo(baseCF * CFrame.new(0, rise, 0) * CFrame.Angles(0, extraSpin, 0))
		else
			self.gun:PivotTo(baseCF)
		end
	end

	-- Outgoing gun sinks and shrinks away
	if self.outgoing then
		self.outgoingT = math.min(self.outgoingT + dt / SWAP_OUT_TIME, 1)
		local e = easeInQuad(self.outgoingT)
		self.outgoing:ScaleTo(math.max(1 - 0.9 * e, 0.05))
		self.outgoing:PivotTo(baseCF * CFrame.new(0, -2.5 * e, 0) * CFrame.Angles(0, e * math.rad(160), 0))
		if self.outgoingT >= 1 then
			self.outgoing:Destroy()
			self.outgoing = nil
		end
	end

	-- Hologram scan ring sweeping up through the new gun
	if self.scanT < 1 then
		self.scanT = math.min(self.scanT + dt / 0.7, 1)
		local y = PEDESTAL_TOP + self.scanT * 6
		self.scanRing.CFrame = CFrame.new(ORIGIN.X, y, ORIGIN.Z) * CFrame.Angles(0, 0, math.rad(90))
		self.scanRing.Transparency = 0.2 + 0.8 * self.scanT
	end

	-- Camera: glide-in zoom, slow breathing sway and mouse parallax
	self.zoom += (self.zoomTarget - self.zoom) * (1 - math.exp(-6 * dt))
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 38
	-- Free the mouse in case we came back from first person (which locks it to the centre)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	local viewport = camera.ViewportSize
	local mouse = UserInputService:GetMouseLocation()
	local nx = math.clamp((mouse.X / math.max(viewport.X, 1)) * 2 - 1, -1, 1)
	local ny = math.clamp((mouse.Y / math.max(viewport.Y, 1)) * 2 - 1, -1, 1)
	local targetOffset = Vector3.new(nx * 0.7, -ny * 0.35, 0)
	self.camOffset = self.camOffset:Lerp(targetOffset, 1 - math.exp(-3 * dt))

	local sway = Vector3.new(math.sin(t * 0.5) * 0.12, math.sin(t * 0.8) * 0.06, 0)
	local camPos = GUN_POINT + Vector3.new(0, CAMERA_HEIGHT, self.zoom) + self.camOffset + sway
	camera.CFrame = CFrame.lookAt(camPos, GUN_POINT + Vector3.new(0, 0.1, 0))

	for _, effect in self.effects do
		if effect:IsA("DepthOfFieldEffect") then
			effect.FocusDistance = self.zoom
		end
	end
end

function Showroom.destroy(self: Showroom)
	RunService:UnbindFromRenderStep(RENDER_STEP)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	for _, effect in self.effects do
		effect:Destroy()
	end
	for key, value in self.savedLighting do
		(Lighting :: any)[key] = value
	end
	self.folder:Destroy()
end

return Showroom
