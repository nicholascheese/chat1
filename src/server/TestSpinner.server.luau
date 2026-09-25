-- Quick test: a glowing blue, spinning cube floating above the spawn.
local RunService = game:GetService("RunService")

local cube = Instance.new("Part")
cube.Name = "TestSpinner"
cube.Size = Vector3.new(4, 4, 4)
cube.Anchored = true
cube.CanCollide = false
cube.Material = Enum.Material.Neon
cube.Color = Color3.fromRGB(0, 170, 255)
cube.Parent = workspace

local base = Vector3.new(0, 8, -15)
local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	cube.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 2), 0)) * CFrame.Angles(t, t * 1.5, 0)
end)
