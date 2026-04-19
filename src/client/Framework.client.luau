local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))

local Modules = {
    CameraHandler = require(script.Parent.Modules.CameraHandler),
    LeanHandler   = require(script.Parent.Modules.LeanHandler),
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler = Modules.CameraHandler.Setup()
local LeanHandler   = Modules.LeanHandler.Setup()

local Framework = {
    Inventory = nil,

    Config    = nil,
    Viewmodel = nil
}

function DebugPrint(message: string)
    if GlobalConfig.Debug then
        warn("[IRNV_DEBUG]: "..message)
    end
end

function LoadSlot(Weapon)
    local Viewmodel_Folder = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Viewmodel")
    local Config_Folder    = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponConfig")

    if Config_Folder:FindFirstChild(Weapon) then
        Framework.Config = require(Config_Folder:FindFirstChild(Weapon))
        DebugPrint("Found Weapon Config!")
    end

    if Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel) then
        Framework.Viewmodel = Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel):Clone()
        DebugPrint("Found Viewmodel!")
    end
end

ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
    LoadSlot(Framework.Inventory[1])
end)