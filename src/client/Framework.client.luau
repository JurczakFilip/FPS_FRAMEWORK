local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local PRELOAD_FOLDER  = Instance.new("Folder")
PRELOAD_FOLDER.Name   = "[IRNV_FPS] Preload"
PRELOAD_FOLDER.Parent = LocalPlayer

local ANIM_FOLDER  = Instance.new("Folder")
ANIM_FOLDER.Name   = "Animations"
ANIM_FOLDER.Parent = PRELOAD_FOLDER

local SOUND_FOLDER  = Instance.new("Folder")
SOUND_FOLDER.Name   = "Sounds"
SOUND_FOLDER.Parent = PRELOAD_FOLDER

local IRNVRep       = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig  = require(IRNVRep:WaitForChild("GlobalConfig"))
local WeaponEffects = IRNVRep:WaitForChild("WeaponEffects")

local Camera  = workspace.CurrentCamera
local baseFOV = Camera.FieldOfView

local Modules = {
    CameraHandler   = require(script.Parent.Modules.CameraHandler),
    GUI_Handler     = require(script.Parent.Modules.GUI_Handler),
    ArmTransparency = require(script.Parent.Modules.ArmTransparency),
    AnimationPlayer = require(script.Parent.Modules.AnimationPlayer),
    MuzzleEffects   = require(script.Parent.Modules.MuzzleEffects),
    SoundSystem     = require(script.Parent.Modules.SoundSystem),
    BulletVisual    = require(script.Parent.Modules.BulletVisual),
    CrouchHandler   = require(script.Parent.Modules.CrouchHandler),
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler   = Modules.CameraHandler.Setup()
local GUIHandler      = Modules.GUI_Handler.Init()
local ArmTransparency = Modules.ArmTransparency
local AnimationPlayer = Modules.AnimationPlayer.new(ANIM_FOLDER)
local MuzzleEffects   = Modules.MuzzleEffects
local SoundSystem     = Modules.SoundSystem.Init(SOUND_FOLDER, Camera, WeaponEffects)
local BulletVisual    = Modules.BulletVisual.Init(SoundSystem)
local CrouchHandler   = Modules.CrouchHandler.Setup()

local Framework = {
    Inventory     = nil,
    WeaponConfig  = nil,
    Viewmodel     = nil,
    WeaponModel   = nil,
    AimPart       = nil,
    MuzzlePart    = nil,
    MuzzleEffects = nil,
}

local function DebugPrint(message: string)
    if GlobalConfig.Debug then
        print("[IRNV_DEBUG]: " .. message)
    end
end

local IRNVRemotes     = IRNVRep:WaitForChild("Remotes")
local ShootRemote     = IRNVRemotes:WaitForChild("Shoot")
local PT_ACTIONRemote = IRNVRemotes:WaitForChild("PT_ACTION")
local TracerRemote    = IRNVRemotes:WaitForChild("TracerVisual")
local ReloadRemote    = IRNVRemotes:WaitForChild("Reload")

local cursorReleased        = false
local isAiming              = false
local adsAlpha              = 0
local isShooting            = false
local isBursting            = false
local timeSinceLastShot     = math.huge
local shotCount             = 0
local recoilPitchAccum      = 0
local recoilYawAccum        = 0
local lastEmptyMagSoundTime = -math.huge

local currentAmmo = 0
local reserveAmmo = 0
local isReloading = false
local reloadToken = 0

local FIRE_MODE_ORDER = GlobalConfig.Fire.FIRE_MODE_ORDER
local currentFireMode = FIRE_MODE_ORDER[1]

local function initFireMode()
    if not Framework.WeaponConfig then return end
    for _, mode in ipairs(FIRE_MODE_ORDER) do
        if Framework.WeaponConfig.FireModes[mode] then
            currentFireMode = mode
            GUIHandler:SetFireMode(mode)
            return
        end
    end
end

local function cycleFireMode()
    if not Framework.WeaponConfig then return end
    local idx = table.find(FIRE_MODE_ORDER, currentFireMode) or 1
    for i = 1, #FIRE_MODE_ORDER do
        local nextIdx  = (idx + i - 1) % #FIRE_MODE_ORDER + 1
        local nextMode = FIRE_MODE_ORDER[nextIdx]
        if Framework.WeaponConfig.FireModes[nextMode] then
            currentFireMode = nextMode
            DebugPrint("Fire mode: " .. currentFireMode)
            SoundSystem:Play("Global_FireModeSwitch")
            GUIHandler:SetFireMode(nextMode)
            return
        end
    end
end

local function LoadSlot(Weapon)
    if Framework.Viewmodel then
        AnimationPlayer:Stop()
        Framework.Viewmodel:Destroy()
        Framework.Viewmodel = nil
    end
    Framework.WeaponConfig = nil
    Framework.WeaponModel  = nil

    local Viewmodel_Folder   = IRNVRep:WaitForChild("Viewmodel")
    local Config_Folder      = IRNVRep:WaitForChild("WeaponConfig")
    local Weaponmodel_Folder = IRNVRep:WaitForChild("WeaponModels")

    if Config_Folder:FindFirstChild(Weapon.WeaponName) then
        Framework.WeaponConfig = require(Config_Folder:FindFirstChild(Weapon.WeaponName))
        DebugPrint("Found Weapon Config!")
    else
        DebugPrint("Failed to locate Weapon Config.")
    end

    if Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel) then
        Framework.Viewmodel        = Viewmodel_Folder:FindFirstChild(GlobalConfig.Viewmodel):Clone()
        Framework.Viewmodel.Parent = Camera
        DebugPrint("Viewmodel assigned to camera.")
    else
        DebugPrint("Failed to locate Viewmodel.")
    end

    if Weaponmodel_Folder:FindFirstChild(Weapon.WeaponName) then
        Framework.WeaponModel = Weaponmodel_Folder:FindFirstChild(Weapon.WeaponName):Clone()
        DebugPrint("Located WeaponModel and cloned!")
        if not Framework.WeaponModel.PrimaryPart then
            DebugPrint("Failed to locate Weapon Model PrimaryPart.")
        end
    else
        DebugPrint("Failed to locate Weapon Model!")
    end

    ArmTransparency.Set(1)

    local GripMotor6D  = Instance.new("Motor6D")
    GripMotor6D.Name   = "[CLIENT] GripMotor6D"
    GripMotor6D.Part0  = Framework.Viewmodel.RightArm
    GripMotor6D.Part1  = Framework.WeaponModel.PrimaryPart
    GripMotor6D.C0     = Framework.WeaponConfig.GripOffset.C0
    GripMotor6D.C1     = Framework.WeaponConfig.GripOffset.C1
    GripMotor6D.Parent = Framework.Viewmodel.RightArm
    Framework.WeaponModel.PrimaryPart.Anchored = false
    Framework.WeaponModel.Parent = Framework.Viewmodel
    DebugPrint("Weapon attached via GripMotor6D.")

    Framework.AimPart    = Framework.WeaponModel:FindFirstChild("AimPart",    true)
    Framework.MuzzlePart = Framework.WeaponModel:FindFirstChild("MuzzlePart", true)
    DebugPrint(Framework.AimPart    and "AimPart found."    or "No AimPart — ADS disabled.")
    DebugPrint(Framework.MuzzlePart and "MuzzlePart found." or "No MuzzlePart — tracer starts from camera.")

    local visualName = Framework.WeaponConfig.Effects and Framework.WeaponConfig.Effects.Visual
    Framework.MuzzleEffects = MuzzleEffects.Clone(Framework.MuzzlePart, visualName)

    AnimationPlayer:Preload(Framework.Viewmodel, Framework.WeaponConfig)
    SoundSystem:PreloadWeapon(Framework.WeaponConfig)
    AnimationPlayer:Play("Idle")
    initFireMode()

    local Character  = Players.LocalPlayer.Character
    local RightHand  = Character and Character:FindFirstChild("RightHand")
    local WorldModel = RightHand and RightHand:FindFirstChild("[SERVER]_" .. Weapon.WeaponName)
    if WorldModel then WorldModel:Destroy() end

    GUIHandler.AMMO_GUI.WeaponLabel.Text  = Weapon.WeaponName
    GUIHandler.AMMO_GUI.AmmoFrame.Visible = true
end

TracerRemote.OnClientEvent:Connect(function(origin: Vector3, direction: Vector3, speed: number, shooterChar, whizCategory: string?, shootSoundId: number?)
    local filter = shooterChar and { shooterChar } or {}
    SoundSystem:Play3DAt(origin, shootSoundId)
    BulletVisual.Run(origin, direction, speed, filter, whizCategory)
    MuzzleEffects.Flash(MuzzleEffects.GetOrCreateForChar(shooterChar))
end)

local function reload()
    local cfg = Framework.WeaponConfig
    if not cfg or isReloading or reserveAmmo <= 0 or currentAmmo >= cfg.MaxMag then return end

    isReloading  = true
    reloadToken += 1
    local token  = reloadToken
    SoundSystem:Play("Reload")
    AnimationPlayer:PlayThen("Reload", isAiming and "Aiming" or "Idle")
    ReloadRemote:FireServer()

    task.delay(cfg.ReloadTime, function()
        if reloadToken ~= token then return end
        local needed = cfg.MaxMag - currentAmmo
        local given  = math.min(needed, reserveAmmo)
        currentAmmo  = currentAmmo + given
        reserveAmmo  = reserveAmmo - given
        isReloading  = false
        GUIHandler:TweenReload(currentAmmo, reserveAmmo, cfg.MaxMag)
    end)
end

local function fireSingleShot()
    local cfg = Framework.WeaponConfig
    if not cfg or currentAmmo <= 0 then return end

    local patternIdx = math.min(shotCount + 1, #cfg.Recoil.Pattern)
    local patMul     = cfg.Recoil.Pattern[patternIdx]
    local vKick = (math.random() * (cfg.Recoil.Vertical.Y   - cfg.Recoil.Vertical.X)   + cfg.Recoil.Vertical.X)   * patMul
    local hKick = (math.random() * (cfg.Recoil.Horizontal.Y - cfg.Recoil.Horizontal.X) + cfg.Recoil.Horizontal.X) * patMul
    local vRad  = math.rad(vKick)
    local hRad  = math.rad(hKick)

    CameraHandler.RecoilPitch = CameraHandler.RecoilPitch - vRad
    CameraHandler.RecoilYaw   = CameraHandler.RecoilYaw   + hRad
    recoilPitchAccum  = recoilPitchAccum + vRad
    recoilYawAccum    = recoilYawAccum   + hRad
    shotCount         = shotCount + 1
    timeSinceLastShot = 0
    currentAmmo      -= 1
    GUIHandler:UpdateAmmo(currentAmmo, reserveAmmo, cfg.MaxMag)
    MuzzleEffects.Flash(Framework.MuzzleEffects)

    local dir       = Camera.CFrame.LookVector
    local char      = Players.LocalPlayer.Character
    local muzzlePos = Framework.MuzzlePart and Framework.MuzzlePart.CFrame.Position
        or Camera.CFrame.Position

    local filter = { Camera }
    if char then table.insert(filter, char) end

    BulletVisual.Run(
        muzzlePos, dir,
        (cfg.MuzzleVelocity.X + cfg.MuzzleVelocity.Y) / 2,
        filter,
        cfg.Effects and cfg.Effects.WhizCategory,
        cfg.Effects and cfg.Effects.Visual,
        cfg.MaxRange
    )

    SoundSystem:Play("Shoot")
    ShootRemote:FireServer(dir)
    AnimationPlayer:PlayThen("Shoot", isAiming and "Aiming" or "Idle")
end

local function tryFire()
    local cfg = Framework.WeaponConfig
    if not cfg or isBursting or isReloading then return end
    if CameraHandler.IsAltLook then return end
    if currentAmmo <= 0 then
        local now = tick()
        if now - lastEmptyMagSoundTime >= GlobalConfig.Fire.EMPTY_MAG_DEBOUNCE then
            SoundSystem:Play("Global_EmptyMag")
            lastEmptyMagSoundTime = now
        end
        return
    end

    local minInterval = 60 / ((cfg.RPM.X + cfg.RPM.Y) / 2)
    if timeSinceLastShot < minInterval then return end

    if currentFireMode == "Burst" then
        local burstCount = cfg.BurstCount or GlobalConfig.Fire.DEFAULT_BURST_COUNT
        isBursting = true
        task.spawn(function()
            for i = 1, burstCount do
                fireSingleShot()
                if i < burstCount then task.wait(minInterval) end
            end
            isBursting = false
        end)
    else
        fireSingleShot()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == GlobalConfig.Crouch.KEY then
        if GlobalConfig.Crouch.TOGGLE then
            CrouchHandler:SetCrouch(not CrouchHandler.IsCrouching)
        else
            CrouchHandler:SetCrouch(true)
        end
        return
    end

    if input.KeyCode == GlobalConfig.AltLook.KEY then
        if isAiming then
            isAiming = false
            SoundSystem:Play("AimOut")
            AnimationPlayer:PlayThen("AimOut", "Idle")
            PT_ACTIONRemote:FireServer(1)
        end
        CameraHandler:SetAltLook(true)
        return
    end

    if input.KeyCode == Enum.KeyCode.F3 then
        cursorReleased = not cursorReleased
        if cursorReleased then
            UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        else
            UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = true
        if currentFireMode == "Semi" or currentFireMode == "Burst" then
            tryFire()
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isReloading or CameraHandler.IsAltLook then return end
        isAiming = true
        SoundSystem:Play("AimIn")
        AnimationPlayer:PlayThen("AimIn", "Aiming")
        PT_ACTIONRemote:FireServer(2)
    elseif input.KeyCode == Enum.KeyCode.M then
        cycleFireMode()
    elseif input.KeyCode == Enum.KeyCode.R then
        reload()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == GlobalConfig.Crouch.KEY and not GlobalConfig.Crouch.TOGGLE then
        CrouchHandler:SetCrouch(false)
        return
    end

    if input.KeyCode == GlobalConfig.AltLook.KEY then
        CameraHandler:SetAltLook(false)
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isReloading then return end
        isAiming = false
        SoundSystem:Play("AimOut")
        AnimationPlayer:PlayThen("AimOut", "Idle")
        PT_ACTIONRemote:FireServer(1)
    end
end)

local lagRot      = nil
local SWAY_SPEED  = 0
local ROLL_SCALE  = 0
local PITCH_SCALE = 0

local BOB_FREQ       = 0
local BOB_AMPLITUDE  = 0
local BOB_FADE       = 0
local bobClock       = 0
local smoothMoveFact = 0

local TILT_AMOUNT    = 0
local TILT_FADE      = 0
local smoothBackTilt = 0

local FALL_TILT      = 0
local FALL_STIFFNESS = 0
local FALL_DAMPING   = 0
local LAND_KICK      = 0
local LAND_STIFFNESS = 0
local LAND_DAMPING   = 0

local fallSpringPos = 0
local fallSpringVel = 0
local landSpringPos = 0
local landSpringVel = 0
local prevGrounded  = nil
local airVertVel    = 0

local IK_ENABLED    = false
local IK_CHECK_DIST = 0
local IK_MAX_PUSH   = 0
local IK_MAX_ANGLE  = 0
local IK_LERP_SPEED = GlobalConfig.IK.FALLBACK_LERP_SPEED
local ikPushFactor  = 0
local ikParams      = RaycastParams.new()
ikParams.FilterType = Enum.RaycastFilterType.Exclude

IRNVRemotes:WaitForChild("LoadInventory").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
end)

IRNVRemotes:WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Weapon)
    LoadSlot(Weapon)

    local cfg      = Framework.WeaponConfig
    TILT_AMOUNT    = cfg.TILT_AMOUNT
    TILT_FADE      = cfg.TILT_FADE
    BOB_FREQ       = cfg.BOB_FREQ
    BOB_AMPLITUDE  = cfg.BOB_AMPLITUDE
    BOB_FADE       = cfg.BOB_FADE
    SWAY_SPEED     = cfg.SWAY_SPEED
    ROLL_SCALE     = cfg.ROLL_SCALE
    PITCH_SCALE    = cfg.PITCH_SCALE
    FALL_TILT      = cfg.FALL_TILT
    FALL_STIFFNESS = cfg.FALL_STIFFNESS
    FALL_DAMPING   = cfg.FALL_DAMPING
    LAND_KICK      = cfg.LAND_KICK
    LAND_STIFFNESS = cfg.LAND_STIFFNESS
    LAND_DAMPING   = cfg.LAND_DAMPING

    reloadToken += 1
    currentAmmo  = cfg.MaxMag
    reserveAmmo  = cfg.ReserveAmmo or 0
    isReloading  = false
    isAiming     = false
    isShooting   = false
    GUIHandler:UpdateAmmo(currentAmmo, reserveAmmo, cfg.MaxMag)

    local ikCfg   = cfg.IK or {}
    IK_ENABLED    = ikCfg.Enabled   == true
    IK_CHECK_DIST = ikCfg.CheckDist or 0
    IK_MAX_PUSH   = ikCfg.MaxPush   or 0
    IK_MAX_ANGLE  = ikCfg.MaxAngle  or 0
    IK_LERP_SPEED = ikCfg.LerpSpeed or GlobalConfig.IK.FALLBACK_LERP_SPEED
    ikPushFactor  = 0
end)

-- Run after Roblox's Camera/Character pass so our LocalTransparencyModifier reset
-- overrides the engine's first-person auto-hide on Camera descendants.
RunService:BindToRenderStep("ViewmodelUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
    timeSinceLastShot = timeSinceLastShot + dt
    local cfg = Framework.WeaponConfig
    if isShooting and currentFireMode == "Auto" then
        tryFire()
    end

    if timeSinceLastShot > GlobalConfig.Recoil.RECOVERY_DELAY and (recoilPitchAccum ~= 0 or recoilYawAccum ~= 0) then
        local recoverySpeed = cfg and cfg.Recoil.Recovery or GlobalConfig.Recoil.FALLBACK_RECOVERY
        local pitchRec = recoilPitchAccum * (1 - math.exp(-recoverySpeed * dt))
        local yawRec   = recoilYawAccum   * (1 - math.exp(-recoverySpeed * dt))
        CameraHandler.RecoilPitch = CameraHandler.RecoilPitch + pitchRec
        CameraHandler.RecoilYaw   = CameraHandler.RecoilYaw   - yawRec
        recoilPitchAccum = recoilPitchAccum - pitchRec
        recoilYawAccum   = recoilYawAccum   - yawRec
        if timeSinceLastShot > GlobalConfig.Recoil.PATTERN_RESET_IDLE then
            shotCount = 0
        end
    end

    local camRot = Camera.CFrame - Camera.CFrame.Position

    if not lagRot then lagRot = camRot end
    lagRot = lagRot:Lerp(camRot, 1 - math.exp(-SWAY_SPEED * dt))

    local swayOffset = camRot:Inverse() * lagRot
    local rx, ry, _  = swayOffset:ToEulerAnglesYXZ()
    local swayCF     = CFrame.Angles(rx * PITCH_SCALE, 0, -ry * ROLL_SCALE)

    local char        = Players.LocalPlayer.Character
    local hrp         = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid    = char and char:FindFirstChildOfClass("Humanoid")
    local grounded    = hrp and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
    local walkSpd     = humanoid and math.max(humanoid.WalkSpeed, 1) or 16
    local camLocalVel = Vector3.zero
    if grounded then
        camLocalVel = Camera.CFrame:VectorToObjectSpace(hrp.AssemblyLinearVelocity)
    end

    local horizMag   = (camLocalVel * Vector3.new(1, 0, 1)).Magnitude
    local targetFact = grounded and math.clamp(horizMag / walkSpd, 0, 1) or 0
    smoothMoveFact = smoothMoveFact + (targetFact - smoothMoveFact) * (1 - math.exp(-BOB_FADE * dt))

    bobClock = bobClock + dt * BOB_FREQ * smoothMoveFact
    local bobX = math.sin(bobClock)     * BOB_AMPLITUDE * smoothMoveFact
    local bobY = math.sin(bobClock * 2) * BOB_AMPLITUDE * smoothMoveFact
    local bobCF = CFrame.new(bobX, bobY, 0)

    local targetBack = grounded and math.clamp(camLocalVel.Z / walkSpd, 0, 1) or 0
    smoothBackTilt = smoothBackTilt + (targetBack - smoothBackTilt) * (1 - math.exp(-TILT_FADE * dt))
    local tiltCF = CFrame.Angles(-smoothBackTilt * TILT_AMOUNT, 0, 0)

    local vertVel    = hrp and hrp.AssemblyLinearVelocity.Y or 0
    local fallTarget = grounded and 0 or math.clamp(-vertVel / GlobalConfig.ViewmodelSprings.FALL_TERMINAL_DIVISOR, 0, 1) * FALL_TILT
    local fallAcc    = -FALL_STIFFNESS * (fallSpringPos - fallTarget) - FALL_DAMPING * fallSpringVel
    fallSpringVel    = fallSpringVel + fallAcc * dt
    fallSpringPos    = fallSpringPos + fallSpringVel * dt

    if prevGrounded == false and grounded then
        local impactMag = math.clamp(-airVertVel / GlobalConfig.ViewmodelSprings.LAND_TERMINAL_DIVISOR, 0, 1)
        landSpringVel   = landSpringVel + impactMag * LAND_KICK
    end
    if not grounded then airVertVel = vertVel end
    local landAcc = -LAND_STIFFNESS * landSpringPos - LAND_DAMPING * landSpringVel
    landSpringVel = landSpringVel + landAcc * dt
    landSpringPos = landSpringPos + landSpringVel * dt
    prevGrounded  = grounded

    local fallCF = CFrame.Angles(fallSpringPos + landSpringPos, 0, 0)

    local adsTarget = isAiming and 1 or 0
    local adsSpeed  = Framework.WeaponConfig and (1 / math.max(Framework.WeaponConfig.AimSpeed, 0.01)) or GlobalConfig.ADS.FALLBACK_SPEED
    adsAlpha = adsAlpha + (adsTarget - adsAlpha) * (1 - math.exp(-adsSpeed * dt))
    Camera.FieldOfView = baseFOV - adsAlpha * GlobalConfig.ADS.FOV_REDUCTION

    local ikTarget = 0
    if IK_ENABLED and IK_CHECK_DIST > 0 then
        local ikChar = Players.LocalPlayer.Character
        ikParams.FilterDescendantsInstances = ikChar and { Camera, ikChar } or { Camera }
        local result = workspace:Raycast(
            Camera.CFrame.Position,
            Camera.CFrame.LookVector * IK_CHECK_DIST,
            ikParams
        )
        if result then
            ikTarget = 1 - math.clamp(result.Distance / IK_CHECK_DIST, 0, 1)
        end
    end
    ikPushFactor = ikPushFactor + (ikTarget - ikPushFactor) * (1 - math.exp(-IK_LERP_SPEED * dt))
    local pushCF = CFrame.new(0, 0, ikPushFactor * IK_MAX_PUSH)
                 * CFrame.Angles(-ikPushFactor * IK_MAX_ANGLE, 0, 0)

    for _, v in pairs(Camera:GetChildren()) do
        if v:IsA("Model") and v.PrimaryPart then
            local rotCF
            if CameraHandler.IsAltLook and CameraHandler.LockedBodyYaw then
                local pitch, _, roll = Camera.CFrame:ToEulerAnglesYXZ()
                rotCF = CFrame.fromEulerAnglesYXZ(pitch, CameraHandler.LockedBodyYaw, roll)
            else
                rotCF = Camera.CFrame - Camera.CFrame.Position
            end
            local hipfireCF = (CFrame.new(Camera.CFrame.Position) * rotCF) * pushCF * GlobalConfig.VIEWMODEL_OFFSET * swayCF * bobCF * tiltCF * fallCF

            local finalCF = hipfireCF
            if Framework.AimPart and adsAlpha > 0 then
                -- offset of AimPart from the model pivot (read from last frame — 1-frame stale, imperceptible)
                local aimOffsetFromPivot = v:GetPivot():Inverse() * Framework.AimPart.CFrame
                local adsCF = Camera.CFrame * pushCF * aimOffsetFromPivot:Inverse()
                finalCF = hipfireCF:Lerp(adsCF, adsAlpha)
            end

            v:PivotTo(finalCF)
        end
    end
end)

-- ─── Death / Respawn ──────────────────────────────────────────────────────────

local function onCharacterDied()
    isShooting  = false
    isBursting  = false
    isAiming    = false
    isReloading = false
    reloadToken += 1

    AnimationPlayer:Stop()
    if Framework.Viewmodel then
        Framework.Viewmodel:Destroy()
        Framework.Viewmodel = nil
    end
    Framework.WeaponConfig  = nil
    Framework.WeaponModel   = nil
    Framework.AimPart       = nil
    Framework.MuzzlePart    = nil
    Framework.MuzzleEffects = nil

    recoilPitchAccum   = 0
    recoilYawAccum     = 0
    Camera.FieldOfView = baseFOV

    ArmTransparency.Set(0)
    GUIHandler.AMMO_GUI.AmmoFrame.Visible = false
end

local function connectCharacterDied(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    humanoid.Died:Connect(onCharacterDied)
end

if LocalPlayer.Character then
    connectCharacterDied(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(connectCharacterDied)
