--!strict
-- Runs the weapon selection screen: opens it on join and after every death,
-- handles keyboard/gamepad shortcuts, and asks the server to deploy with the chosen gun.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)
local Showroom = require(script.Parent.Showroom)
local SelectionUI = require(script.Parent.SelectionUI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local deployRequest = remotes:WaitForChild("DeployRequest") :: RemoteEvent
local openArmory = remotes:WaitForChild("OpenArmory") :: RemoteEvent

local player = Players.LocalPlayer
local DEPLOY_TIMEOUT = 8

local lastIndex = 1 -- remembered between lives
local isOpen = false

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}
local PREV_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonL1 }
local NEXT_KEYS = { Enum.KeyCode.E, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonR1 }
local DEPLOY_KEYS = { Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA }

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

local function waitForLivingCharacter(timeout: number): Model?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			return character
		end
		task.wait(0.1)
	end
	return nil
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	setCoreGui(false)

	local count = #GunConfig.Order
	local current = 0
	local deploying = false
	local showroom = Showroom.new()
	local ui: SelectionUI.SelectionUI
	local inputConnection: RBXScriptConnection

	local function selectGun(index: number)
		index = (index - 1) % count + 1
		if index == current or deploying then
			return
		end
		current = index
		lastIndex = index
		local id = GunConfig.Order[index]
		showroom:setGun(id)
		ui:showGun(index, GunConfig.Guns[id])
	end

	local function close()
		inputConnection:Disconnect()
		showroom:destroy()
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		setCoreGui(true)
		isOpen = false
	end

	local function deploy()
		if deploying then
			return
		end
		deploying = true
		task.spawn(function()
			ui:playOutro()
			deployRequest:FireServer(GunConfig.Order[current])
			local character = waitForLivingCharacter(DEPLOY_TIMEOUT)
			close()
			if character then
				ui:fadeOutAndDestroy()
			else
				-- Server refused or timed out: rebuild the armory so the player can try again
				ui:destroy()
				open()
			end
		end)
	end

	ui = SelectionUI.new({ onSelect = selectGun, onDeploy = deploy })

	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if NUMBER_KEYS[key] and NUMBER_KEYS[key] <= count then
			selectGun(NUMBER_KEYS[key])
		elseif table.find(PREV_KEYS, key) then
			selectGun(current - 1)
		elseif table.find(NEXT_KEYS, key) then
			selectGun(current + 1)
		elseif table.find(DEPLOY_KEYS, key) then
			deploy()
		end
	end)

	selectGun(lastIndex)
	ui:playIntro()
end

openArmory.OnClientEvent:Connect(open)
open()
