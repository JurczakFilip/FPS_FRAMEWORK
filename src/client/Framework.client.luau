local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))

local Camera = workspace.CurrentCamera

local Modules = {
    CameraHandler = require(script.Parent.Modules.CameraHandler),
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler = Modules.CameraHandler.Setup()

local Framework = {
    Inventory = nil,

    WeaponConfig = nil,
    Viewmodel    = nil,
    Weaponmodel  = nil
}

function DebugPrint(message: string)
    if GlobalConfig.Debug then
        print("[IRNV_DEBUG]: "..message)
    end
end

function ToggleArmTransparency(TransparencyValue: number)
    local Character = Players.LocalPlayer.Character
    
    Character.LeftLowerArm.Transparency = TransparencyValue
    Character.LeftUpperArm.Transparency = TransparencyValue
    Character.RightLowerArm.Transparency = TransparencyValue
    Character.RightUpperArm.Transparency = TransparencyValue
    Character.LeftHand.Transparency = TransparencyValue
    Character.RightHand.Transparency = TransparencyValue
end

local AnimationPlayer = {
    _animator = nil,
    _track    = nil,
}

function AnimationPlayer:SetViewmodel(viewmodel)
    self._animator   = viewmodel.Humanoid.Animator
    if not self._animator then
        DebugPrint("AnimationPlayer: no Animator found on viewmodel.")
    end
end

function AnimationPlayer:Play(AnimationType: string)
    if not self._animator or not Framework.WeaponConfig then return end
    local animId = Framework.WeaponConfig.Animations.FPS[AnimationType]
    if not animId or animId == 0 then
        DebugPrint("AnimationPlayer: no valid AnimationId for '"..AnimationType.."'")
        return
    end
    if self._track then self._track:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    self._track = self._animator:LoadAnimation(anim)
    anim:Destroy()
    self._track:Play()
    DebugPrint("AnimationPlayer: playing '"..AnimationType.."'")
end

function AnimationPlayer:Stop()
    if self._track then
        self._track:Stop()
        self._track = nil
    end
end

function LoadSlot(Weapon)
    --Clear Previous Use
    if Framework.Viewmodel then

        AnimationPlayer:Stop()
        Framework.Viewmodel:Destroy()
        Framework.Viewmodel = nil

    elseif Framework.WeaponConfig then
    
        Framework.WeaponConfig = nil

    elseif Framework.Weaponmodel then

        Framework.Weaponmodel:Destroy()
        Framework.Weaponmodel = nil
    
    end

    --Start of Load
    local Viewmodel_Folder   = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Viewmodel")
    local Config_Folder      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponConfig")
    local Weaponmodel_Folder = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponModels")

    if Config_Folder:FindFirstChild(Weapon.WeaponName) then
        Framework.WeaponConfig = require(Config_Folder:FindFirstChild(Weapon.WeaponName))
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

    if Weaponmodel_Folder:FindFirstChild(Weapon.WeaponName) then
        Framework.Weaponmodel = Weaponmodel_Folder:FindFirstChild(Weapon.WeaponName):Clone()
        DebugPrint("Located WeaponModel and cloned!")

        if not Framework.Weaponmodel.PrimaryPart then
            DebugPrint("Failed to located Weapon Model PrimaryPart.")
        end
    else
        DebugPrint("Failed to located Weapon Model!")
    end

    DebugPrint("Toggling World Arm Transparency to 1. (ClientSide)")
    ToggleArmTransparency(1)

    DebugPrint("Creating GripMotor6D...")
    local GripMotor6D = Instance.new("Motor6D")
    GripMotor6D.Name = "GripMotor6D"

    Framework.Weaponmodel.PrimaryPart.Anchored = false

    GripMotor6D.Part0  = Framework.Viewmodel.RightArm
    GripMotor6D.Part1  = Framework.Weaponmodel.PrimaryPart
    GripMotor6D.C0     = Framework.WeaponConfig.GripOffset.C0
    GripMotor6D.C1     = Framework.WeaponConfig.GripOffset.C1
    GripMotor6D.Parent = Framework.Viewmodel.RightArm

    Framework.Weaponmodel.Parent = Framework.Viewmodel
    DebugPrint("Weapon attached via GripMotor6D.")

    AnimationPlayer:SetViewmodel(Framework.Viewmodel)
    AnimationPlayer:Play("Idle")
end

local lagRot      = nil -- trails camera rotation for sway
local SWAY_SPEED  = 0
local ROLL_SCALE  = 0
local PITCH_SCALE = 0

local BOB_FREQ       = 0     -- stride rate at full walkspeed (rad/sec)
local BOB_AMPLITUDE  = 0  -- max bob offset in studs
local BOB_FADE       = 0     -- how fast bob fades in/out on start/stop
local bobClock       = 0
local smoothMoveFact = 0

local TILT_AMOUNT    = 0 -- barrel-up / stock-down pitch at full backward speed
local TILT_FADE      = 0        -- lerp speed for tilt in/out
local smoothBackTilt = 0

ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
    LoadSlot(Framework.Inventory[1])

    TILT_AMOUNT    = Framework.WeaponConfig.TILT_AMOUNT -- barrel-up / stock-down pitch at full backward speed
    TILT_FADE      = Framework.WeaponConfig.TILT_FADE   
    BOB_FREQ       = Framework.WeaponConfig.BOB_FREQ     -- stride rate at full walkspeed (rad/sec)
    BOB_AMPLITUDE  = Framework.WeaponConfig.BOB_AMPLITUDE  -- max bob offset in studs
    BOB_FADE       = Framework.WeaponConfig.BOB_FADE   
    SWAY_SPEED     = Framework.WeaponConfig.SWAY_SPEED
    ROLL_SCALE     = Framework.WeaponConfig.ROLL_SCALE
    PITCH_SCALE    = Framework.WeaponConfig.PITCH_SCALE
end)

-- Run after Roblox's Camera/Character pass so our LocalTransparencyModifier reset
-- overrides the engine's first-person auto-hide on Camera descendants.
RunService:BindToRenderStep("ViewmodelUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camRot = Camera.CFrame - Camera.CFrame.Position

    if not lagRot then lagRot = camRot end
    lagRot = lagRot:Lerp(camRot, 1 - math.exp(-SWAY_SPEED * dt))

    local swayOffset = camRot:Inverse() * lagRot
    local rx, ry, _  = swayOffset:ToEulerAnglesYXZ()
    local swayCF     = CFrame.Angles(rx * PITCH_SCALE, 0, -ry * ROLL_SCALE)

    -- Movement state shared by bob + backward tilt
    local char        = Players.LocalPlayer.Character
    local hrp         = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid    = char and char:FindFirstChildOfClass("Humanoid")
    local grounded    = hrp and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
    local walkSpd     = humanoid and math.max(humanoid.WalkSpeed, 1) or 16
    local camLocalVel = Vector3.zero
    if grounded then
        camLocalVel = Camera.CFrame:VectorToObjectSpace(hrp.AssemblyLinearVelocity)
    end

    -- Bob: sine on X (sway) + double-freq on Y (steps), scaled by horizontal speed
    local horizMag   = (camLocalVel * Vector3.new(1, 0, 1)).Magnitude
    local targetFact = grounded and math.clamp(horizMag / walkSpd, 0, 1) or 0
    smoothMoveFact = smoothMoveFact + (targetFact - smoothMoveFact) * (1 - math.exp(-BOB_FADE * dt))

    bobClock = bobClock + dt * BOB_FREQ * smoothMoveFact
    local bobX = math.sin(bobClock)     * BOB_AMPLITUDE * smoothMoveFact
    local bobY = math.sin(bobClock * 2) * BOB_AMPLITUDE * smoothMoveFact
    local bobCF = CFrame.new(bobX, bobY, 0)

    -- Backward tilt: camera-local +Z is behind the player, so any backward velocity
    -- component (straight back, back-left, back-right) tilts the gun's muzzle up.
    local targetBack = grounded and math.clamp(camLocalVel.Z / walkSpd, 0, 1) or 0
    smoothBackTilt = smoothBackTilt + (targetBack - smoothBackTilt) * (1 - math.exp(-TILT_FADE * dt))
    local tiltCF = CFrame.Angles(-smoothBackTilt * TILT_AMOUNT, 0, 0)

    for _, v in pairs(Camera:GetChildren()) do
        if v:IsA("Model") and v.PrimaryPart then
            v:PivotTo(Camera.CFrame * GlobalConfig.VIEWMODEL_OFFSET * swayCF * bobCF * tiltCF)
        end
    end
end)