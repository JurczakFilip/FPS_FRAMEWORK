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

    Config      = nil,
    Viewmodel   = nil,
    Weaponmodel = nil
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

    elseif Framework.Config then
    
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

ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
    LoadSlot(Framework.Inventory[1])
end)

-- Run after Roblox's Camera/Character pass so our LocalTransparencyModifier reset
-- overrides the engine's first-person auto-hide on Camera descendants.

local smoothCamPos = nil

RunService.RenderStepped:Connect(function(dt)
    if not smoothCamPos then smoothCamPos = Camera.CFrame.Position end
    smoothCamPos = smoothCamPos:Lerp(Camera.CFrame.Position, 1 - math.exp(-25 * dt))

    local smoothedCamCF = CFrame.new(smoothCamPos) * (Camera.CFrame - Camera.CFrame.Position)

    for _, v in pairs(Camera:GetChildren()) do
        if v:IsA("Model") and v.PrimaryPart then
            v:PivotTo(smoothedCamCF * GlobalConfig.VIEWMODEL_OFFSET)
        end
    end
end)