local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))
local CFG = GlobalConfig.LeanHandler

local ROM       = math.rad(CFG.RANGE_OF_MOTION)
local ROM_TORSO = math.rad(90 - CFG.RANGE_OF_MOTION)
local ROM_XZ    = CFG.RANGE_OF_MOTION / 140

-- ──────────────────────────────────────────────────────────────────────────────
-- Joint helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function gatherJoints(character)
    local hrp        = character:FindFirstChild("HumanoidRootPart")
    local lowerTorso = character:FindFirstChild("LowerTorso")
    local upperTorso = character:FindFirstChild("UpperTorso")
    local humanoid   = character:FindFirstChildOfClass("Humanoid")

    if not (hrp and lowerTorso and upperTorso and humanoid) then return nil end

    local rootJoint = hrp:FindFirstChild("RootJoint")
    local waist     = lowerTorso:FindFirstChild("Waist")
    local neck      = upperTorso:FindFirstChild("Neck")
    local leftHip   = lowerTorso:FindFirstChild("LeftHip")
    local rightHip  = lowerTorso:FindFirstChild("RightHip")

    if not (rootJoint and waist and neck and leftHip and rightHip) then return nil end

    return {
        hrp      = hrp,
        humanoid = humanoid,

        rootJoint = rootJoint,
        waist     = waist,
        neck      = neck,
        leftHip   = leftHip,
        rightHip  = rightHip,

        -- Snapshot resting C0 values now, while character is in default pose
        rootJointC0 = rootJoint.C0,
        waistC0     = waist.C0,
        neckC0      = neck.C0,
        leftHipC0   = leftHip.C0,
        rightHipC0  = rightHip.C0,
    }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Per-character lean calculation
-- ──────────────────────────────────────────────────────────────────────────────

local function calculate(state, dt)
    local j        = state.joints
    local hrp      = j.hrp
    local humanoid = j.humanoid

    if not hrp.Parent then return end

    local walkSpeed = math.max(humanoid.WalkSpeed, 1)
    local localVel  = hrp.CFrame:VectorToObjectSpace(hrp.AssemblyLinearVelocity)
    local dir       = Vector3.new(localVel.X / walkSpeed, 0, localVel.Z / walkSpeed)

    local xResult      = dir.X * (ROM       - math.abs(dir.Z) * (ROM       / 2))
    local xResultTorso = dir.X * (ROM_TORSO - math.abs(dir.Z) * (ROM_TORSO / 2))
    local xResultXZ    = dir.X * (ROM_XZ    - math.abs(dir.Z) * (ROM_XZ    / 2))

    if dir.Z > 0.1 then
        xResult      *= -1
        xResultTorso *= -1
        xResultXZ    *= -1
    end

    local alpha = 1 - CFG.LERP_SPEED ^ dt

    -- RootJoint rolls the whole character body
    local rootTarget = j.rootJointC0 * CFrame.Angles(0, 0, -xResultTorso)
    j.rootJoint.C0 = j.rootJoint.C0:Lerp(rootTarget, alpha)

    -- Waist partially counter-rolls so the upper body leans less than the lower
    -- WAIST_COUNTER controls what fraction the waist absorbs (rest goes to the neck)
    local waistTarget = j.waistC0 * CFrame.Angles(0, 0, xResultTorso * CFG.WAIST_COUNTER)
    j.waist.C0 = j.waist.C0:Lerp(waistTarget, alpha)

    -- Neck counter-rolls the remaining amount so the head stays level
    local neckTarget = j.neckC0 * CFrame.Angles(0, 0, xResultTorso * (1 - CFG.WAIST_COUNTER))
    j.neck.C0 = j.neck.C0:Lerp(neckTarget, alpha)

    -- Hips rotate on Y so the legs face the movement direction during a strafe
    local rightHipTarget = j.rightHipC0 * CFrame.new(-xResultXZ, 0, 0) * CFrame.Angles(0, -xResult, 0)
    local leftHipTarget  = j.leftHipC0  * CFrame.new(-xResultXZ, 0, 0) * CFrame.Angles(0, -xResult, 0)
    j.rightHip.C0 = j.rightHip.C0:Lerp(rightHipTarget, alpha)
    j.leftHip.C0  = j.leftHip.C0:Lerp(leftHipTarget,  alpha)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Module
-- ──────────────────────────────────────────────────────────────────────────────

local LeanHandler = {}
LeanHandler.__index = LeanHandler

function LeanHandler.Setup()
    local self = setmetatable({}, LeanHandler)

    self.states = {}  -- keyed by Player

    RunService:BindToRenderStep(
        "LeanHandler",
        Enum.RenderPriority.Character.Value + 1,
        function(dt)
            for _, state in pairs(self.states) do
                local ok, err = pcall(calculate, state, dt)
                if not ok then
                    warn("LeanHandler:", err)
                end
            end
        end
    )

    local function onCharacterAdded(player, character)
        self.states[player] = nil
        task.spawn(function()
            task.wait()  -- let character joints settle to their resting C0 before snapshotting
            local joints = gatherJoints(character)
            if not joints then
                warn("LeanHandler: could not gather joints for", player.Name)
                return
            end
            self.states[player] = { joints = joints }
        end)
    end

    local function setupPlayer(player)
        player.CharacterAdded:Connect(function(character)
            onCharacterAdded(player, character)
        end)
        player.CharacterRemoving:Connect(function()
            self.states[player] = nil
        end)
        if player.Character then
            onCharacterAdded(player, player.Character)
        end
    end

    Players.PlayerAdded:Connect(setupPlayer)
    Players.PlayerRemoving:Connect(function(player)
        self.states[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player)
    end

    return self
end

return LeanHandler
