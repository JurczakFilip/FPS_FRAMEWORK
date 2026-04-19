local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))

local Camera = workspace.CurrentCamera

local Modules = {
    CameraHandler = require(script.Parent.Modules.CameraHandler),
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler = Modules.CameraHandler.Setup()

local Framework = {
    Inventory = nil,

    Config    = nil,
    Viewmodel = nil
}

function DebugPrint(message: string)
    if GlobalConfig.Debug then
        print("[IRNV_DEBUG]: "..message)
    end
end

function LoadSlot(Weapon)
    local Viewmodel_Folder = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Viewmodel")
    local Config_Folder    = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponConfig")

    if Config_Folder:FindFirstChild(Weapon.WeaponName) then
        Framework.Config = require(Config_Folder:FindFirstChild(Weapon.WeaponName))
        DebugPrint("Found Weapon Config!")
    else
        DebugPrint("Failed to locate Weapon Config.")
    end

    if Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel) then
        Framework.Viewmodel = Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel):Clone()
        DebugPrint("Found Viewmodel!")
        DebugPrint("Attempting to Assign Viewmodel to Camera...")
        Framework.Viewmodel.Parent = Camera
        DebugPrint("Assigned Viewmodel to camera!")
    else
        DebugPrint("Failed to locate Viewmodel.")
    end
end

ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
    LoadSlot(Framework.Inventory[1])
end)

local VIEWMODEL_OFFSET = CFrame.new(0.5, -1.5, -0.5)

RunService.RenderStepped:Connect(function()
    for i, v in pairs(Camera:GetChildren()) do
        if v:IsA("Model") then
            v:SetPrimaryPartCFrame(Camera.CFrame * VIEWMODEL_OFFSET)
            -- Reset LocalTransparencyModifier so Roblox doesn't hide the parts
            for _, part in ipairs(v:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 0
                end
            end
        end
    end
end)