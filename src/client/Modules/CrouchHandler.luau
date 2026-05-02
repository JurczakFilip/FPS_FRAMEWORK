local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local CrouchRemote = IRNVRep:WaitForChild("Remotes"):WaitForChild("Crouch")
local LocalPlayer  = Players.LocalPlayer

local CrouchHandler = {}
CrouchHandler.__index = CrouchHandler

function CrouchHandler.Setup()
    local self = setmetatable({}, CrouchHandler)
    self.IsCrouching = false

    local function onCharacterAdded(char)
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            if self.IsCrouching then
                self.IsCrouching = false
                CrouchRemote:FireServer(false)
            end
        end)
    end

    if LocalPlayer.Character then
        onCharacterAdded(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

    return self
end

function CrouchHandler:SetCrouch(active: boolean)
    if active == self.IsCrouching then return end
    self.IsCrouching = active
    CrouchRemote:FireServer(active)
end

return CrouchHandler
