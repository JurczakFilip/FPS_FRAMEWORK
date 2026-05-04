local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))

local ArmTransparency = {}

function ArmTransparency.Set(value: number, character: Model?)
    character = character or Players.LocalPlayer.Character
    if not character then return end
    for _, partName in ipairs(GlobalConfig.ArmParts) do
        local part = character:FindFirstChild(partName) or character:WaitForChild(partName, 2)
        if part and part:IsA("BasePart") then
            part.Transparency = value
        end
    end
end

return ArmTransparency
