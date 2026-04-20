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

local LEAN_ROM_TORSO = math.rad(90 - GlobalConfig.LeanHandler.RANGE_OF_MOTION)
local LEAN_ROM       = math.rad(GlobalConfig.LeanHandler.RANGE_OF_MOTION)
local LEAN_ROM_XZ    = GlobalConfig.LeanHandler.RANGE_OF_MOTION / 140
local LEAN_LERP      = GlobalConfig.LeanHandler.LERP_SPEED
local WAIST_COUNTER  = GlobalConfig.LeanHandler.WAIST_COUNTER

local ServerCameraHandler = {}
ServerCameraHandler.__index = ServerCameraHandler

local function getBaseC0(motor)
    if not motor:GetAttribute("BaseC0") then
        motor:SetAttribute("BaseC0", motor.C0)
    end
    return motor:GetAttribute("BaseC0")
end

local function isValidAngle(v)
    return typeof(v) == "number" and v == v
end

-- Cache Motor6D references for a character so Heartbeat never calls FindFirstChild
local function cacheJoints(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    return {
        hrp       = hrp,
        humanoid  = character:FindFirstChildOfClass("Humanoid"),
        rootJoint = hrp and hrp:FindFirstChild("RootJoint"),
        neck      = character:FindFirstChild("Neck",     true),
        waist     = character:FindFirstChild("Waist",    true),
        leftHip   = character:FindFirstChild("LeftHip",  true),
        rightHip  = character:FindFirstChild("RightHip", true),
    }
end

-- Clear stored base C0 snapshots so they are re-captured for a fresh character
local function clearBaseC0(joints)
    for _, motor in ipairs({ joints.rootJoint, joints.neck, joints.waist, joints.leftHip, joints.rightHip }) do
        if motor then motor:SetAttribute("BaseC0", nil) end
    end
end

function ServerCameraHandler.Setup()
    local self = setmetatable({}, ServerCameraHandler)

    self.targetLook = {} -- [player] = { pitch, yaw, roll }
    self.smoothLean = {} -- [player] = { torso, result, xz }
    self.joints     = {} -- [player] = cached Motor6D references

    LookRemote.OnServerEvent:Connect(function(player, pitch, yaw, roll)
        if not isValidAngle(pitch) or not isValidAngle(yaw) then return end
        self.targetLook[player] = {
            pitch = math.clamp(pitch, -MAX_PITCH, MAX_PITCH),
            yaw   = math.clamp(yaw, -math.pi, math.pi),
            roll  = isValidAngle(roll) and math.clamp(roll, -math.pi / 4, math.pi / 4) or 0,
        }
    end)

    RunService.Heartbeat:Connect(function(dt)
        local alpha     = math.clamp(dt * SMOOTH_SPEED, 0, 1)
        local leanAlpha = 1 - LEAN_LERP ^ dt

        for player, look in pairs(self.targetLook) do
            local j = self.joints[player]
            if not (j and j.hrp) then continue end

            -- Derive lean from server-authoritative velocity
            local walkSpeed = j.humanoid and math.max(j.humanoid.WalkSpeed, 1) or 16
            local localVel  = j.hrp.CFrame:VectorToObjectSpace(j.hrp.AssemblyLinearVelocity)
            local dir       = Vector3.new(localVel.X / walkSpeed, 0, localVel.Z / walkSpeed)

            local targetTorso  = dir.X * (LEAN_ROM_TORSO - math.abs(dir.Z) * (LEAN_ROM_TORSO / 2))
            local targetResult = dir.X * (LEAN_ROM       - math.abs(dir.Z) * (LEAN_ROM       / 2))
            local targetXZ     = dir.X * (LEAN_ROM_XZ    - math.abs(dir.Z) * (LEAN_ROM_XZ    / 2))

            if dir.Z > 0.1 then
                targetTorso  *= -1
                targetResult *= -1
                targetXZ     *= -1
            end

            local sl = self.smoothLean[player]
            if not sl then
                sl = { torso = 0, result = 0, xz = 0 }
                self.smoothLean[player] = sl
            end
            sl.torso  = sl.torso  + (targetTorso  - sl.torso)  * leanAlpha
            sl.result = sl.result + (targetResult - sl.result) * leanAlpha
            sl.xz     = sl.xz    + (targetXZ     - sl.xz)     * leanAlpha

            -- RootJoint: camera strafe roll + body lean roll
            if j.rootJoint then
                local goal = getBaseC0(j.rootJoint) * CFrame.Angles(0, 0, look.roll - sl.torso)
                j.rootJoint.C0 = j.rootJoint.C0:Lerp(goal, alpha)
            end

            -- Waist: pitch (X-axis) + lean counter (Z-axis)
            if j.waist then
                local goal = getBaseC0(j.waist) * CFrame.Angles(look.pitch * WAIST_WEIGHT, 0, sl.torso * WAIST_COUNTER)
                j.waist.C0 = j.waist.C0:Lerp(goal, alpha)
            end

            -- Neck: pitch + yaw + lean counter-counter (Z-axis)
            if j.neck then
                local goal = getBaseC0(j.neck) * CFrame.fromEulerAnglesYXZ(
                    look.pitch * NECK_WEIGHT,
                    look.yaw   * NECK_YAW_WEIGHT,
                    -sl.torso  * (1 - WAIST_COUNTER)
                )
                j.neck.C0 = j.neck.C0:Lerp(goal, alpha)
            end

            -- Hips: lean positional offset + rotation
            local hipOffset = CFrame.new(-sl.xz, 0, 0) * CFrame.Angles(0, -sl.result, 0)
            if j.leftHip  then j.leftHip.C0  = j.leftHip.C0:Lerp(getBaseC0(j.leftHip)   * hipOffset, leanAlpha) end
            if j.rightHip then j.rightHip.C0 = j.rightHip.C0:Lerp(getBaseC0(j.rightHip) * hipOffset, leanAlpha) end
        end
    end)

    local function onCharacterAdded(player, character)
        -- Wait a frame so all joints exist before caching
        task.defer(function()
            local j = cacheJoints(character)
            self.joints[player]     = j
            self.targetLook[player] = { pitch = 0, yaw = 0, roll = 0 }
            self.smoothLean[player] = { torso = 0, result = 0, xz = 0 }
            clearBaseC0(j)
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            onCharacterAdded(player, character)
        end)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            onCharacterAdded(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            onCharacterAdded(player, character)
        end)
    end

    Players.PlayerRemoving:Connect(function(player)
        self.targetLook[player] = nil
        self.smoothLean[player] = nil
        self.joints[player]     = nil
    end)

    return self
end

return ServerCameraHandler
