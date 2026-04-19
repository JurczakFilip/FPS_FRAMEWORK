local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = script.Parent:WaitForChild("Modules")
local Players = game:GetService("Players")

-- Load Modules
require(Modules:WaitForChild("CameraHandler")).Setup()
local Test_Inventory = require(Modules:WaitForChild("Inventory"))

-- Main Code

local Framework = {
    Test_Inventory = Test_Inventory,
    CurrentWeapon = nil
}

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon"):FireClient(player, Framework.Test_Inventory)
    end)
end)