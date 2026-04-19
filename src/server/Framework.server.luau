local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = script.Parent:WaitForChild("Modules")

-- Load Modules
require(Modules:WaitForChild("CameraHandler")).Setup()
local Test_Inventory = require(Modules:WaitForChild("Inventory"))

-- Main Code

local Framework = {
    Inventory = Test_Inventory,
    CurrentWeapon = nil
}