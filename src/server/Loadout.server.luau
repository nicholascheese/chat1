--!strict
-- Players stay in the armory (no character) until they pick a gun and press DEPLOY.
-- When they die they go back to the armory to choose again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfig = require(ReplicatedStorage.Shared.GunConfig)

local RESPAWN_DELAY = 3
local DEPLOY_COOLDOWN = 1

Players.CharacterAutoLoads = false

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local deployRequest = Instance.new("RemoteEvent")
deployRequest.Name = "DeployRequest" -- client -> server: (gunId)
deployRequest.Parent = remotes

local openArmory = Instance.new("RemoteEvent")
openArmory.Name = "OpenArmory" -- server -> client: show the selection screen
openArmory.Parent = remotes

remotes.Parent = ReplicatedStorage

local lastDeploy: { [Player]: number } = {}

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		task.wait(RESPAWN_DELAY)
		if player.Parent ~= Players then
			return
		end
		player.CameraMode = Enum.CameraMode.Classic
		if player.Character == character then
			character:Destroy()
			player.Character = nil
		end
		openArmory:FireClient(player)
	end)
end

deployRequest.OnServerEvent:Connect(function(player: Player, gunId: unknown)
	if typeof(gunId) ~= "string" or not GunConfig.get(gunId) then
		return
	end
	-- Only allowed from the armory, i.e. while the player has no living character.
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return
		end
	end
	local now = os.clock()
	if now - (lastDeploy[player] or 0) < DEPLOY_COOLDOWN then
		return
	end
	lastDeploy[player] = now

	player:SetAttribute("PrimaryWeapon", gunId)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player:LoadCharacter()
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastDeploy[player] = nil
end)
