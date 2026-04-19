local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig  = require(IRNVRep:WaitForChild("GlobalConfig"))
local LookRemote    = IRNVRep:WaitForChild("Remotes"):WaitForChild("CameraHandler")

local NECK_WEIGHT     = GlobalConfig.PitchReplication.NECK_WEIGHT
local WAIST_WEIGHT    = GlobalConfig.PitchReplication.WAIST_WEIGHT
local NECK_YAW_WEIGHT = GlobalConfig.PitchReplication.NECK_YAW_WEIGHT
local MAX_PITCH       = GlobalConfig.PitchReplication.MAX_PITCH
local SMOOTH_SPEED    = GlobalConfig.PitchReplication.SMOOTH_SPEED

local ServerCameraHandler = {}
ServerCameraHandler.__index = ServerCameraHandler

-- Captures the resting C0 of a Motor6D on first touch, stored as an attribute.
local function getBaseC0(motor)
    if not motor:GetAttribute("BaseC0") then
        motor:SetAttribute("BaseC0", motor.C0)
    end
    return motor:GetAttribute("BaseC0")
end

-- Clears base C0 snapshots so they are re-captured for a fresh character.
local function clearBaseC0(character)
    local head       = character:FindFirstChild("Head")
    local upperTorso = character:FindFirstChild("UpperTorso")
    if head then
        local neck = head:FindFirstChild("Neck")
        if neck then neck:SetAttribute("BaseC0", nil) end
    end
    if upperTorso then
        local waist = upperTorso:FindFirstChild("Waist")
        if waist then waist:SetAttribute("BaseC0", nil) end
    end
end

local function isValidAngle(v)
    return typeof(v) == "number" and v == v -- exists + not NaN
end

function ServerCameraHandler.Setup()
    local self = setmetatable({}, ServerCameraHandler)

    -- targetLook[player] = { pitch = number, yaw = number }
    self.targetLook = {}

    -- Receive pitch + relative yaw from clients
    LookRemote.OnServerEvent:Connect(function(player, pitch, yaw)
        if not isValidAngle(pitch) or not isValidAngle(yaw) then return end
        self.targetLook[player] = {
            pitch = math.clamp(pitch, -MAX_PITCH, MAX_PITCH),
            yaw   = math.clamp(yaw, -math.pi, math.pi),
        }
    end)

    -- Apply look angles to Motor6Ds each physics step
    RunService.Heartbeat:Connect(function(dt)
        local alpha = math.clamp(dt * SMOOTH_SPEED, 0, 1)

        for player, look in pairs(self.targetLook) do
            local character = player.Character
            if not character then continue end

            local head       = character:FindFirstChild("Head")
            local upperTorso = character:FindFirstChild("UpperTorso")
            if not head or not upperTorso then continue end

            local neck  = head:FindFirstChild("Neck")
            local waist = upperTorso:FindFirstChild("Waist")
            if not neck or not waist then continue end

            local neckBase  = getBaseC0(neck)
            local waistBase = getBaseC0(waist)

            -- Waist: vertical tilt only
            local waistGoal = waistBase * CFrame.Angles(look.pitch * WAIST_WEIGHT, 0, 0)

            -- Neck: vertical tilt + horizontal turn (shows full look direction)
            local neckGoal = neckBase
                * CFrame.fromEulerAnglesYXZ(look.pitch * NECK_WEIGHT, look.yaw * NECK_YAW_WEIGHT, 0)

            neck.C0  = neck.C0:Lerp(neckGoal,  alpha)
            waist.C0 = waist.C0:Lerp(waistGoal, alpha)
        end
    end)

    -- Reset on respawn
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self.targetLook[player] = { pitch = 0, yaw = 0 }
            clearBaseC0(character)
        end)
    end)

    -- Handle players already in-game when this script runs
    for _, player in ipairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(function(character)
            self.targetLook[player] = { pitch = 0, yaw = 0 }
            clearBaseC0(character)
        end)
    end

    -- Clean up on disconnect
    Players.PlayerRemoving:Connect(function(player)
        self.targetLook[player] = nil
    end)

    return self
end

return ServerCameraHandler
