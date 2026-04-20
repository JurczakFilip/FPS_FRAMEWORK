local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))
local CFG = GlobalConfig.LeanHandler

local ROM       = math.rad(CFG.RANGE_OF_MOTION)
local ROM_TORSO = math.rad(90 - CFG.RANGE_OF_MOTION)
local ROM_XZ    = CFG.RANGE_OF_MOTION / 140

local Character  = script.Parent
local humanoid   = Character:WaitForChild("Humanoid", 10)
local hrp        = Character:WaitForChild("HumanoidRootPart", 10)
local lowerTorso = Character:WaitForChild("LowerTorso", 10)
local upperTorso = Character:WaitForChild("UpperTorso", 10)

if not (humanoid and hrp and lowerTorso and upperTorso) then
    warn("LeanHandler: missing character parts")
    return
end

local rootJoint = hrp:WaitForChild("RootJoint", 10)
local waist     = lowerTorso:WaitForChild("Waist", 10)
local neck      = upperTorso:WaitForChild("Neck", 10)
local leftHip   = lowerTorso:WaitForChild("LeftHip", 10)
local rightHip  = lowerTorso:WaitForChild("RightHip", 10)

if not (rootJoint and waist and neck and leftHip and rightHip) then
    warn("LeanHandler: missing Motor6D joints")
    return
end

local rootJointC0 = rootJoint.C0
local waistC0     = waist.C0
local neckC0      = neck.C0
local leftHipC0   = leftHip.C0
local rightHipC0  = rightHip.C0

RunService:BindToRenderStep("LeanHandler", Enum.RenderPriority.Character.Value + 1, function(dt)
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

    rootJoint.C0 = rootJoint.C0:Lerp(rootJointC0 * CFrame.Angles(0, 0, -xResultTorso), alpha)
    waist.C0     = waist.C0:Lerp(waistC0 * CFrame.Angles(0, 0, xResultTorso * CFG.WAIST_COUNTER), alpha)
    neck.C0      = neck.C0:Lerp(neckC0  * CFrame.Angles(0, 0, -xResultTorso * (1 - CFG.WAIST_COUNTER)), alpha)

    local hipOffset = CFrame.new(-xResultXZ, 0, 0) * CFrame.Angles(0, -xResult, 0)
    rightHip.C0 = rightHip.C0:Lerp(rightHipC0 * hipOffset, alpha)
    leftHip.C0  = leftHip.C0:Lerp(leftHipC0  * hipOffset, alpha)
end)
