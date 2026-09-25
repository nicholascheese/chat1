--!strict
-- The 2D overlay of the weapon selection screen. Pure presentation: it tells the controller
-- when the player clicks a card or DEPLOY, and the controller tells it which gun to show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)

type Gun = GunConfig.Gun

local TEXT = Color3.fromRGB(236, 239, 245)
local MUTED = Color3.fromRGB(138, 145, 160)
local PANEL = Color3.fromRGB(12, 13, 17)
local STROKE = Color3.fromRGB(58, 62, 72)
local BLACK = Color3.new(0, 0, 0)

local SCRAMBLE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#/%<>"

-- Replace with your own uploaded sound ids (rbxassetid://...) for custom UI audio.
local SOUNDS = {
	hover = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.08, pitch = 1.6 },
	select = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, pitch = 1.1 },
	deploy = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 0.7 },
}

local SelectionUI = {}
SelectionUI.__index = SelectionUI

export type Callbacks = {
	onSelect: (index: number) -> (),
	onDeploy: () -> (),
}

type Card = {
	button: TextButton,
	bar: Frame,
	stroke: UIStroke,
	gradient: UIGradient,
	name: TextLabel,
	content: Frame,
	hovered: boolean,
}

type StatRow = {
	fill: Frame,
	value: TextLabel,
	number: NumberValue,
}

export type SelectionUI = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		callbacks: Callbacks,
		cards: { Card },
		stats: { [string]: StatRow },
		accentTargets: { { instance: Instance, property: string } },
		viewportConnection: RBXScriptConnection,
		leftPanel: Frame,
		rightPanel: Frame,
		fade: Frame,
		classTag: TextLabel,
		classPill: Frame,
		nameLabel: TextLabel,
		metaLabel: TextLabel,
		descLabel: TextLabel,
		tiles: { [string]: TextLabel },
		deployButton: TextButton,
		deployLabel: TextLabel,
		deployShine: UIGradient,
		selectedIndex: number,
		accent: Color3,
		scrambleToken: number,
		alive: boolean,
		deploying: boolean,
	},
	SelectionUI
))

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, delay: number?): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out, 0, false, delay or 0),
		props
	)
	t:Play()
	return t
end

local function playSound(def: { id: string, volume: number, pitch: number })
	if def.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props)
end

local function buildVignette(gui: ScreenGui)
	local edges = {
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.fromScale(0, 0.65), rot = -90 },
		{ size = UDim2.new(0.3, 0, 1, 0), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ size = UDim2.new(0.3, 0, 1, 0), pos = UDim2.fromScale(0.7, 0), rot = 180 },
	}
	for _, edge in edges do
		create("Frame", {
			Name = "Vignette",
			BackgroundColor3 = BLACK,
			BorderSizePixel = 0,
			Size = edge.size,
			Position = edge.pos,
			Parent = gui,
		}, {
			create("UIGradient", {
				Rotation = edge.rot,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
end

function SelectionUI.new(callbacks: Callbacks): SelectionUI
	local self = setmetatable({}, SelectionUI) :: SelectionUI
	self.callbacks = callbacks
	self.cards = {}
	self.stats = {}
	self.tiles = {}
	self.accentTargets = {}
	self.selectedIndex = 0
	self.accent = Color3.new(1, 1, 1)
	self.scrambleToken = 0
	self.alive = true
	self.deploying = false

	local player = Players.LocalPlayer
	local gui = create("ScreenGui", {
		Name = "ArmoryUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	})
	self.gui = gui

	-- Keeps the layout readable on small screens (phones, small windows)
	local root = create("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local uiScale = create("UIScale", { Parent = root })
	local function rescale()
		local camera = workspace.CurrentCamera
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1400, size.Y / 800), 0.5, 1.15)
		root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
	end
	rescale()
	self.viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	buildVignette(gui)
	self:_buildBars(root, player)
	self:_buildBrackets(root)
	self:_buildLeftPanel(root)
	self:_buildRightPanel(root)
	self:_buildDeployButton(root)

	self.fade = create("Frame", {
		Name = "Fade",
		BackgroundColor3 = BLACK,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	return self
end

-- Registers an instance property that should follow the selected gun's accent colour.
function SelectionUI._accent(self: SelectionUI, instance: Instance, property: string)
	table.insert(self.accentTargets, { instance = instance, property = property })
end


function SelectionUI._buildBars(self: SelectionUI, root: Frame, player: Player)
	local top = create("Frame", {
		Name = "TopBar",
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = root,
	})
	local accentLine = create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = top,
	}, {
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	self:_accent(accentLine, "BackgroundColor3")

	local mark = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Rotation = 45,
		Parent = top,
	})
	self:_accent(mark, "BackgroundColor3")

	label({
		Text = "ARMORY",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0.5, 0),
		Size = UDim2.fromOffset(120, 30),
		Parent = top,
	})
	label({
		Text = "//  SELECT PRIMARY WEAPON",
		Font = Enum.Font.RobotoMono,
		TextSize = 14,
		TextColor3 = MUTED,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 180, 0.5, 0),
		Size = UDim2.fromOffset(300, 30),
		Parent = top,
	})
	label({
		Text = "OPERATOR  " .. string.upper(player.DisplayName),
		Font = Enum.Font.RobotoMono,
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(400, 30),
		Parent = top,
	})

	local bottom = create("Frame", {
		Name = "BottomBar",
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = root,
	})
	local hints = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -96, 1, 0),
		Parent = bottom,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 28),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local hintList = {
		{ "DRAG", "ROTATE" },
		{ "SCROLL", "ZOOM" },
		{ "Q / E", "CYCLE" },
		{ "1 - " .. #GunConfig.Order, "SELECT" },
		{ "ENTER", "DEPLOY" },
	}
	for i, hint in hintList do
		local item = create("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			LayoutOrder = i,
			Parent = hints,
		}, {
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		create("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(40, 43, 50),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			Font = Enum.Font.RobotoMono,
			TextSize = 12,
			TextColor3 = TEXT,
			Text = hint[1],
			LayoutOrder = 1,
			Parent = item,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 3) }),
			create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		})
		label({
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			Font = Enum.Font.RobotoMono,
			TextSize = 12,
			TextColor3 = MUTED,
			Text = hint[2],
			LayoutOrder = 2,
			Parent = item,
		})
	end
end

-- HUD corner brackets framing the gun in the middle of the screen
function SelectionUI._buildBrackets(self: SelectionUI, root: Frame)
	local frame = create("Frame", {
		Name = "Brackets",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.42),
		Parent = root,
	})
	local LEN, THICK = 26, 2
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local pos = UDim2.fromScale(corner.X, corner.Y)
		for _, horizontal in { true, false } do
			local line = create("Frame", {
				BorderSizePixel = 0,
				BackgroundTransparency = 0.35,
				AnchorPoint = corner,
				Position = pos,
				Size = if horizontal then UDim2.fromOffset(LEN, THICK) else UDim2.fromOffset(THICK, LEN),
				Parent = frame,
			})
			self:_accent(line, "BackgroundColor3")
		end
	end
	local tag = label({
		Name = "Readout",
		Font = Enum.Font.RobotoMono,
		TextSize = 11,
		TextColor3 = MUTED,
		Text = "PREVIEW // LIVE",
		Position = UDim2.new(0, 0, 1, 8),
		Size = UDim2.fromOffset(200, 14),
		Parent = frame,
	})
	tag.TextTransparency = 0.2
end

function SelectionUI._buildLeftPanel(self: SelectionUI, root: Frame)
	local panel = create("Frame", {
		Name = "Weapons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(320, 420),
		Parent = root,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	self.leftPanel = panel

	label({
		Text = "PRIMARY  ·  " .. #GunConfig.Order .. " AVAILABLE",
		Font = Enum.Font.RobotoMono,
		TextSize = 13,
		TextColor3 = MUTED,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
		Parent = panel,
	})

	for index, id in GunConfig.Order do
		local gun = GunConfig.Guns[id]
		local button = create("TextButton", {
			Name = id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.25,
			Size = UDim2.new(1, 0, 0, 78),
			LayoutOrder = index,
			ClipsDescendants = true,
			Parent = panel,
		})
		local stroke = create("UIStroke", { Color = STROKE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
		local gradient = create("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) }),
			Parent = button,
		})

		local bar = create("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = gun.accent,
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundTransparency = 1,
			Parent = button,
		})

		-- Content lives in its own frame so it can slide on hover without breaking the list layout
		local content = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = button })
		label({
			Text = string.format("%02d", index),
			Font = Enum.Font.RobotoMono,
			TextSize = 26,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(0, 44, 1, 0),
			Parent = content,
		})
		local name = label({
			Text = gun.displayName,
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			Position = UDim2.fromOffset(72, 16),
			Size = UDim2.new(1, -110, 0, 26),
			Parent = content,
		})
		label({
			Text = gun.class .. "  ·  " .. gun.caliber,
			Font = Enum.Font.RobotoMono,
			TextSize = 12,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(72, 44),
			Size = UDim2.new(1, -110, 0, 16),
			Parent = content,
		})
		label({
			Text = "[" .. index .. "]",
			Font = Enum.Font.RobotoMono,
			TextSize = 12,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(30, 16),
			Parent = content,
		})

		local card: Card = {
			button = button,
			bar = bar,
			stroke = stroke,
			gradient = gradient,
			name = name,
			content = content,
			hovered = false,
		}
		table.insert(self.cards, card)

		button.MouseEnter:Connect(function()
			card.hovered = true
			if self.selectedIndex ~= index then
				playSound(SOUNDS.hover)
			end
			self:_refreshCard(index)
		end)
		button.MouseLeave:Connect(function()
			card.hovered = false
			self:_refreshCard(index)
		end)
		button.Activated:Connect(function()
			self.callbacks.onSelect(index)
		end)
	end
end

function SelectionUI._refreshCard(self: SelectionUI, index: number)
	local card = self.cards[index]
	local gun = GunConfig.Guns[GunConfig.Order[index]]
	local selected = index == self.selectedIndex

	tween(card.bar, 0.25, { BackgroundTransparency = if selected then 0 else 1 })
	tween(card.stroke, 0.25, {
		Color = if selected then gun.accent else STROKE,
		Transparency = if selected then 0.2 else 0,
	})
	tween(card.button, 0.25, {
		BackgroundColor3 = if selected then gun.accent:Lerp(PANEL, 0.82) elseif card.hovered then Color3.fromRGB(28, 30, 36) else PANEL,
	})
	tween(card.content, 0.25, { Position = UDim2.fromOffset(if selected or card.hovered then 8 else 0, 0) })
	tween(card.name, 0.25, { TextColor3 = if selected then gun.accent:Lerp(TEXT, 0.35) else TEXT })
	card.gradient.Transparency = if selected
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.3) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
end

function SelectionUI._buildRightPanel(self: SelectionUI, root: Frame)
	local panel = create("Frame", {
		Name = "Details",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, -30),
		Size = UDim2.fromOffset(400, 470),
		Parent = root,
	})
	self.rightPanel = panel

	local pill = create("Frame", {
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		Parent = panel,
	}, {
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	self.classPill = pill
	self:_accent(pill, "BackgroundColor3")
	self.classTag = label({
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(12, 12, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = pill,
	})

	self.nameLabel = label({
		Font = Enum.Font.GothamBlack,
		TextSize = 54,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = panel,
	})
	self.metaLabel = label({
		Font = Enum.Font.RobotoMono,
		TextSize = 13,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = panel,
	})
	local divider = create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = panel,
	}, {
		create("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	self:_accent(divider, "BackgroundColor3")

	self.descLabel = label({
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(190, 195, 206),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = panel,
	})

	-- Stat bars
	local statsFrame = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 204),
		Size = UDim2.new(1, 0, 0, 170),
		Parent = panel,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, stat in GunConfig.StatLabels do
		local row = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = i,
			Parent = statsFrame,
		})
		label({
			Text = stat.label,
			Font = Enum.Font.RobotoMono,
			TextSize = 12,
			TextColor3 = MUTED,
			Size = UDim2.new(0.5, 0, 0, 14),
			Parent = row,
		})
		local value = label({
			Text = "0",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, 0, 0, 14),
			Parent = row,
		})
		local track = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 5),
			Parent = row,
		})
		local fill = create("Frame", {
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		}, {
			create("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
			}),
		})
		self:_accent(fill, "BackgroundColor3")
		-- Segment notches give the bars a tactical, "measured" look
		for s = 1, 9 do
			create("Frame", {
				BackgroundColor3 = BLACK,
				BorderSizePixel = 0,
				Position = UDim2.new(s / 10, -1, 0, 0),
				Size = UDim2.new(0, 2, 1, 0),
				ZIndex = 2,
				Parent = track,
			})
		end
		local number = create("NumberValue", { Parent = row })
		number.Changed:Connect(function(v: number)
			value.Text = tostring(math.round(v))
		end)
		self.stats[stat.key] = { fill = fill, value = value, number = number }
	end

	-- Spec tiles
	local tiles = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 390),
		Size = UDim2.new(1, 0, 0, 64),
		Parent = panel,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, key in { "MAG", "RPM", "ACTION" } do
		local tile = create("Frame", {
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.25,
			Size = UDim2.new(1 / 3, -6, 1, 0),
			LayoutOrder = i,
			Parent = tiles,
		}, {
			create("UIStroke", { Color = STROKE, Thickness = 1 }),
		})
		label({
			Text = key,
			Font = Enum.Font.RobotoMono,
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 14),
			Parent = tile,
		})
		self.tiles[key] = label({
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextScaled = false,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -24, 0, 26),
			Parent = tile,
		})
	end
end

function SelectionUI._buildDeployButton(self: SelectionUI, root: Frame)
	local button = create("TextButton", {
		Name = "Deploy",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -72),
		Size = UDim2.fromOffset(400, 66),
		Parent = root,
	})
	self.deployButton = button
	self:_accent(button, "BackgroundColor3")

	local glow = create("UIStroke", { Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	self:_accent(glow, "Color")

	-- A diagonal highlight that sweeps across the button
	self.deployShine = create("UIGradient", {
		Rotation = 20,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.85, 0.85, 0.85)),
			ColorSequenceKeypoint.new(0.45, Color3.new(0.85, 0.85, 0.85)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.55, Color3.new(0.85, 0.85, 0.85)),
			ColorSequenceKeypoint.new(1, Color3.new(0.85, 0.85, 0.85)),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = button,
	})

	self.deployLabel = label({
		Text = "DEPLOY",
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(12, 12, 14),
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(1, -48, 0, 32),
		Parent = button,
	})
	label({
		Text = "PRESS ENTER",
		Font = Enum.Font.RobotoMono,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(12, 12, 14),
		Position = UDim2.fromOffset(24, 42),
		Size = UDim2.new(1, -48, 0, 14),
		Parent = button,
	})
	label({
		Text = ">>",
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(12, 12, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(60, 40),
		Parent = button,
	})

	local scale = create("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, 0.2, { Scale = 1.03 })
		self:_sweepShine()
		playSound(SOUNDS.hover)
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.2, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		self.callbacks.onDeploy()
	end)

	-- Idle pulse on the outline + periodic shine
	task.spawn(function()
		while self.alive do
			tween(glow, 0.9, { Thickness = 5, Transparency = 0.85 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.9)
			tween(glow, 0.9, { Thickness = 2, Transparency = 0.4 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.9)
			if self.alive and math.random() < 0.5 then
				self:_sweepShine()
			end
		end
	end)
end

function SelectionUI._sweepShine(self: SelectionUI)
	self.deployShine.Offset = Vector2.new(-1, 0)
	tween(self.deployShine, 0.6, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
end

-- "Decrypt" effect: random glyphs resolve left-to-right into the real text.
function SelectionUI._scramble(self: SelectionUI, target: TextLabel, text: string, duration: number)
	self.scrambleToken += 1
	local token = self.scrambleToken
	task.spawn(function()
		local start = os.clock()
		while self.alive and token == self.scrambleToken do
			local progress = math.min((os.clock() - start) / duration, 1)
			local revealed = math.floor(progress * #text)
			local out = string.sub(text, 1, revealed)
			for i = revealed + 1, #text do
				local ch = string.sub(text, i, i)
				if ch == " " then
					out ..= " "
				else
					local r = math.random(1, #SCRAMBLE_CHARS)
					out ..= string.sub(SCRAMBLE_CHARS, r, r)
				end
			end
			target.Text = out
			if progress >= 1 then
				break
			end
			task.wait(0.03)
		end
	end)
end

function SelectionUI.showGun(self: SelectionUI, index: number, gun: Gun)
	local previous = self.selectedIndex
	self.selectedIndex = index
	if previous ~= 0 and previous ~= index then
		self:_refreshCard(previous)
		playSound(SOUNDS.select)
	end
	self:_refreshCard(index)

	-- Accent colour sweep across the whole UI
	self.accent = gun.accent
	for _, target in self.accentTargets do
		tween(target.instance, 0.4, { [target.property] = gun.accent })
	end

	self.classTag.Text = gun.class
	self:_scramble(self.nameLabel, gun.displayName, 0.35)
	self.metaLabel.Text = string.format("EST. %s   ·   %s   ·   %s", gun.era, gun.caliber, gun.action)
	self.descLabel.Text = gun.description
	self.descLabel.TextTransparency = 1
	tween(self.descLabel, 0.5, { TextTransparency = 0 })

	for i, stat in GunConfig.StatLabels do
		local row = self.stats[stat.key]
		local v = (gun.stats :: any)[stat.key] :: number
		tween(row.fill, 0.6, { Size = UDim2.fromScale(v / 100, 1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, (i - 1) * 0.05)
		tween(row.number, 0.6, { Value = v }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, (i - 1) * 0.05)
	end

	self.tiles.MAG.Text = tostring(gun.magSize)
	self.tiles.RPM.Text = tostring(gun.rpm)
	self.tiles.ACTION.Text = gun.action
end

function SelectionUI.playIntro(self: SelectionUI)
	self.fade.BackgroundTransparency = 0
	tween(self.fade, 1.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)

	local leftTarget = self.leftPanel.Position
	local rightTarget = self.rightPanel.Position
	self.leftPanel.Position = leftTarget - UDim2.fromOffset(420, 0)
	self.rightPanel.Position = rightTarget + UDim2.fromOffset(460, 0)
	tween(self.leftPanel, 0.9, { Position = leftTarget }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.35)
	tween(self.rightPanel, 0.9, { Position = rightTarget }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.45)

	local deployTarget = self.deployButton.Position
	self.deployButton.Position = deployTarget + UDim2.fromOffset(0, 140)
	tween(self.deployButton, 0.8, { Position = deployTarget }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.7)
end

-- Plays the deploy transition. Yields until the screen is black.
function SelectionUI.playOutro(self: SelectionUI)
	if self.deploying then
		return
	end
	self.deploying = true
	playSound(SOUNDS.deploy)
	self.deployLabel.Text = "DEPLOYING..."

	tween(self.leftPanel, 0.5, { Position = self.leftPanel.Position - UDim2.fromOffset(420, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(self.rightPanel, 0.5, { Position = self.rightPanel.Position + UDim2.fromOffset(460, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

	self.fade.BackgroundColor3 = self.accent:Lerp(Color3.new(1, 1, 1), 0.6)
	self.fade.BackgroundTransparency = 0.4
	local flash = tween(self.fade, 0.15, { BackgroundTransparency = 1 })
	flash.Completed:Wait()
	self.fade.BackgroundColor3 = BLACK
	local black = tween(self.fade, 0.6, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
	black.Completed:Wait()
end

-- Fades the black deploy screen away to reveal the game, then removes the UI.
function SelectionUI.fadeOutAndDestroy(self: SelectionUI)
	for _, child in self.gui:GetChildren() do
		if child ~= self.fade and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	tween(self.fade, 0.8, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad).Completed:Wait()
	self:destroy()
end

function SelectionUI.destroy(self: SelectionUI)
	self.alive = false
	self.viewportConnection:Disconnect()
	self.gui:Destroy()
end

return SelectionUI
