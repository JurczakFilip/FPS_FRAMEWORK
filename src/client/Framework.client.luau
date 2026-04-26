local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local PRELOAD_FOLDER  = Instance.new("Folder")
PRELOAD_FOLDER.Name   = "[IRNV_FPS] Preload"
PRELOAD_FOLDER.Parent = LocalPlayer

local ANIM_FOLDER   = Instance.new("Folder")
ANIM_FOLDER.Name    = "Animations"
ANIM_FOLDER.Parent  = PRELOAD_FOLDER

local SOUND_FOLDER  = Instance.new("Folder")
SOUND_FOLDER.Name   = "Sounds"
SOUND_FOLDER.Parent = PRELOAD_FOLDER

local GlobalConfig = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))

local Camera  = workspace.CurrentCamera
local baseFOV = Camera.FieldOfView

local Modules = {
    CameraHandler = require(script.Parent.Modules.CameraHandler),
    GUI_Handler   = require(script.Parent.Modules.GUI_Handler)
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler = Modules.CameraHandler.Setup()
local GUIHandler    = Modules.GUI_Handler.Init()

local Framework = {
    Inventory     = nil,
    WeaponConfig  = nil,
    Viewmodel     = nil,
    WeaponModel   = nil,
    AimPart       = nil,
    MuzzlePart    = nil,
    MuzzleEffects = nil,
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
    _animator   = nil,
    _tracks     = {},
    _track      = nil,
    _chainToken = 0,
    _chainConn  = nil,
}

function AnimationPlayer:Preload(viewmodel, weaponConfig)
    self._animator = viewmodel.Humanoid.Animator
    self._tracks   = {}
    self._track    = nil
    ANIM_FOLDER:ClearAllChildren()
    for animType, animId in pairs(weaponConfig.Animations.FPS) do
        if animId and animId ~= 0 then
            local anim = Instance.new("Animation")
            anim.Name        = animType
            anim.AnimationId = "rbxassetid://" .. animId
            anim.Parent      = ANIM_FOLDER
            self._tracks[animType] = self._animator:LoadAnimation(anim)
        end
    end
end

function AnimationPlayer:Play(animType: string)
    local track = self._tracks[animType]
    if not track then
        DebugPrint("AnimationPlayer: no preloaded track for '" .. animType .. "'")
        return
    end
    self._chainToken += 1
    if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
    if self._track and self._track ~= track then self._track:Stop() end
    track:Stop()
    self._track = track
    track:Play()
    DebugPrint("AnimationPlayer: playing '" .. animType .. "'")
end

function AnimationPlayer:PlayThen(animType: string, nextAnimType: string)
    self:Play(animType)
    local track = self._track
    if not track then return end
    track.Looped = false
    self._chainToken += 1
    local token = self._chainToken
    self._chainConn = track.Stopped:Connect(function()
        if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
        if self._chainToken == token then
            self:Play(nextAnimType)
        end
    end)
end

function AnimationPlayer:Stop()
    self._chainToken += 1
    if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
    if self._track then
        self._track:Stop()
        self._track = nil
    end
end

local MuzzleEffectsFolder = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponEffects"):WaitForChild("Visual"):WaitForChild("Muzzle")
local MUZZLE_FLASH_DURATION = 0.05

local function isToggleableEffect(inst: Instance): boolean
    return inst:IsA("ParticleEmitter") or inst:IsA("Light") or inst:IsA("Beam") or inst:IsA("Trail")
end

local function cloneMuzzleEffectsInto(muzzlePart: BasePart?, visualName: string?)
    if not muzzlePart or not visualName then return {} end
    local template = MuzzleEffectsFolder:FindFirstChild(visualName)
    if not template then
        DebugPrint("No muzzle effects template for visual: " .. tostring(visualName))
        return {}
    end
    local effects = {}
    for _, fx in ipairs(template:GetChildren()) do
        local clone = fx:Clone()
        clone.Parent = muzzlePart
        if isToggleableEffect(clone) then
            clone.Enabled = false
        end
        table.insert(effects, clone)
    end
    return effects
end

local function flashMuzzleEffects(effects)
    if not effects or #effects == 0 then return end
    for _, fx in ipairs(effects) do
        if isToggleableEffect(fx) then fx.Enabled = true end
    end
    task.delay(MUZZLE_FLASH_DURATION, function()
        for _, fx in ipairs(effects) do
            if fx.Parent and isToggleableEffect(fx) then
                fx.Enabled = false
            end
        end
    end)
end

-- World-model muzzle effects for OTHER players (lazy-cloned on first observed shot).
local _worldMuzzleCache = {}

local function getOrCreateWorldMuzzleEffects(shooterChar: Model)
    local rightHand = shooterChar and shooterChar:FindFirstChild("RightHand")
    if not rightHand then return nil end

    local worldModel
    for _, child in ipairs(rightHand:GetChildren()) do
        if child.Name:sub(1, 9) == "[SERVER]_" then
            worldModel = child
            break
        end
    end
    if not worldModel then return nil end

    local muzzle = worldModel:FindFirstChild("MuzzlePart", true)
    if not muzzle then return nil end

    local cached = _worldMuzzleCache[muzzle]
    if cached then return cached end

    local weaponName = worldModel.Name:sub(10) -- strip "[SERVER]_"
    local cfgFolder  = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponConfig")
    local cfgModule  = cfgFolder:FindFirstChild(weaponName)
    if not cfgModule then return nil end

    local ok, cfg = pcall(require, cfgModule)
    if not ok or type(cfg) ~= "table" then return nil end

    local visualName = cfg.Effects and cfg.Effects.Visual
    if not visualName then return nil end

    local effects = cloneMuzzleEffectsInto(muzzle, visualName)
    _worldMuzzleCache[muzzle] = effects
    muzzle.Destroying:Connect(function()
        _worldMuzzleCache[muzzle] = nil
    end)
    return effects
end

function LoadSlot(Weapon)
    --Clear Previous Use
    if Framework.Viewmodel then

        AnimationPlayer:Stop()
        Framework.Viewmodel:Destroy()
        Framework.Viewmodel = nil

    elseif Framework.WeaponConfig then
    
        Framework.WeaponConfig = nil

    elseif Framework.WeaponModel then

        Framework.WeaponModel:Destroy()
        Framework.WeaponModel = nil
    
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
        Framework.WeaponModel = Weaponmodel_Folder:FindFirstChild(Weapon.WeaponName):Clone()
        DebugPrint("Located WeaponModel and cloned!")

        if not Framework.WeaponModel.PrimaryPart then
            DebugPrint("Failed to located Weapon Model PrimaryPart.")
        end
    else
        DebugPrint("Failed to located Weapon Model!")
    end

    DebugPrint("Toggling World Arm Transparency to 1. (ClientSide)")
    ToggleArmTransparency(1)

    DebugPrint("Creating GripMotor6D...")
    local GripMotor6D = Instance.new("Motor6D")
    GripMotor6D.Name = "[CLIENT] GripMotor6D"

    Framework.WeaponModel.PrimaryPart.Anchored = false

    GripMotor6D.Part0  = Framework.Viewmodel.RightArm
    GripMotor6D.Part1  = Framework.WeaponModel.PrimaryPart
    GripMotor6D.C0     = Framework.WeaponConfig.GripOffset.C0
    GripMotor6D.C1     = Framework.WeaponConfig.GripOffset.C1
    GripMotor6D.Parent = Framework.Viewmodel.RightArm

    Framework.WeaponModel.Parent = Framework.Viewmodel
    DebugPrint("Weapon attached via GripMotor6D.")

    Framework.AimPart    = Framework.WeaponModel:FindFirstChild("AimPart",    true)
    Framework.MuzzlePart = Framework.WeaponModel:FindFirstChild("MuzzlePart", true)
    DebugPrint(Framework.AimPart    and "AimPart found."    or "No AimPart — ADS disabled.")
    DebugPrint(Framework.MuzzlePart and "MuzzlePart found." or "No MuzzlePart — tracer starts from camera.")

    local visualName = Framework.WeaponConfig.Effects and Framework.WeaponConfig.Effects.Visual
    Framework.MuzzleEffects = cloneMuzzleEffectsInto(Framework.MuzzlePart, visualName)

    AnimationPlayer:Preload(Framework.Viewmodel, Framework.WeaponConfig)
    preloadWeaponSounds(Framework.WeaponConfig)
    AnimationPlayer:Play("Idle")
    initFireMode()

    -- Delete World view Weapon Model
    local Character = Players.LocalPlayer.Character
    local WeaponWorldModel = Character.RightHand:FindFirstChild("[SERVER]_"..Weapon.WeaponName)
    WeaponWorldModel:Destroy()

    -- Load GUI
    GUIHandler.AMMO_GUI.WeaponLabel.Text  = Weapon.WeaponName
    GUIHandler.AMMO_GUI.AmmoFrame.Visible = true
end

local IRNVRemotes     = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes")
local ShootRemote     = IRNVRemotes:WaitForChild("Shoot")
local PT_ACTIONRemote = IRNVRemotes:WaitForChild("PT_ACTION")
local TracerRemote    = IRNVRemotes:WaitForChild("TracerVisual")
local TracersFolder   = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponEffects"):WaitForChild("Visual"):WaitForChild("Tracers")
local ReloadRemote    = IRNVRemotes:WaitForChild("Reload")

local isAiming          = false
local adsAlpha          = 0
local isShooting        = false
local isBursting        = false
local timeSinceLastShot = math.huge
local shotCount         = 0
local recoilPitchAccum    = 0
local recoilYawAccum      = 0
local lastEmptyMagSoundTime = -math.huge

local currentAmmo  = 0
local reserveAmmo  = 0
local isReloading  = false
local reloadToken  = 0

local FIRE_MODE_ORDER = { "Semi", "Auto", "Burst" }
local currentFireMode = "Semi"

function initFireMode()
    if not Framework.WeaponConfig then return end
    for _, mode in ipairs(FIRE_MODE_ORDER) do
        if Framework.WeaponConfig.FireModes[mode] then
            currentFireMode = mode
            GUIHandler:SetFireMode(mode)
            return
        end
    end
end

local _soundTemplates = {}

local function preloadGlobalSounds()
    local function add(key, id)
        if not id or id == 0 then return end
        local sound = Instance.new("Sound")
        sound.Name    = key
        sound.SoundId = "rbxassetid://" .. id
        sound.Parent  = SOUND_FOLDER
        _soundTemplates[key] = sound
    end
    add("Global_FireModeSwitch", GlobalConfig.FireModeSwitchSound)
    add("Global_EmptyMag",       GlobalConfig.EmptyMagSound)
end

function preloadWeaponSounds(cfg)
    for key, sound in pairs(_soundTemplates) do
        if not key:match("^Global_") then
            sound:Destroy()
            _soundTemplates[key] = nil
        end
    end
    for soundType, soundId in pairs(cfg.Effects.Sound) do
        if soundId and soundId ~= 0 then
            local sound = Instance.new("Sound")
            sound.Name    = soundType
            sound.SoundId = "rbxassetid://" .. soundId
            sound.Parent  = SOUND_FOLDER
            _soundTemplates[soundType] = sound
        end
    end
end

local function playSound(key: string)
    local template = _soundTemplates[key]
    if not template then return end
    local sound  = template:Clone()
    sound.Parent = Camera
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
end

preloadGlobalSounds()

local function cycleFireMode()
    if not Framework.WeaponConfig then return end
    local idx = table.find(FIRE_MODE_ORDER, currentFireMode) or 1
    for i = 1, #FIRE_MODE_ORDER do
        local nextIdx  = (idx + i - 1) % #FIRE_MODE_ORDER + 1
        local nextMode = FIRE_MODE_ORDER[nextIdx]
        if Framework.WeaponConfig.FireModes[nextMode] then
            currentFireMode = nextMode
            DebugPrint("Fire mode: " .. currentFireMode)
            playSound("Global_FireModeSwitch")
            GUIHandler:SetFireMode(nextMode)
            return
        end
    end
end

-- Simulates a bullet visually: animated moving Part following the actual curved
-- (gravity-affected) trajectory. Client-local, never replicates to server.
local BULLET_GRAVITY = Vector3.new(0, -workspace.Gravity, 0)
local TRACER_STEP    = 0.05  -- seconds per step, matches BulletSystem

local function runBulletVisual(origin: Vector3, direction: Vector3, speed: number, filterList: {Instance})
    -- Pre-simulate the full path into time-stamped waypoints
    local waypoints = { origin }
    local times     = { 0 }
    local pos       = origin
    local vel       = direction.Unit * speed
    local maxRange  = (Framework.WeaponConfig and Framework.WeaponConfig.MaxRange) or 1500
    local traveled  = 0
    local t         = 0

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = filterList
    params.FilterType = Enum.RaycastFilterType.Exclude

    for _ = 1, 200 do
        local newVel = vel + BULLET_GRAVITY * TRACER_STEP
        local newPos = pos + vel * TRACER_STEP
        t = t + TRACER_STEP
        local result = workspace:Raycast(pos, newPos - pos, params)
        if result then
            table.insert(waypoints, result.Position)
            table.insert(times, t)
            break
        end
        traveled = traveled + (newPos - pos).Magnitude
        pos = newPos
        vel = newVel
        table.insert(waypoints, pos)
        table.insert(times, t)
        if traveled >= maxRange then break end
    end

    if #waypoints < 2 then return end

    local visualName  = Framework.WeaponConfig and Framework.WeaponConfig.Effects and Framework.WeaponConfig.Effects.Visual
    local tracerModel = visualName and TracersFolder:FindFirstChild(visualName)
    if not tracerModel then
        DebugPrint("runBulletVisual: no tracer found for '" .. tostring(visualName) .. "'")
        return
    end

    local totalTime = times[#times]

    local bullet  = tracerModel:Clone()
    local isModel = bullet:IsA("Model")
    local function setBulletCFrame(cf)
        if isModel then bullet:PivotTo(cf) else bullet.CFrame = cf end
    end

    setBulletCFrame(CFrame.lookAt(waypoints[1], waypoints[2]))
    bullet.Parent = workspace

    local startTime  = tick()
    local lastSegIdx = 1
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= totalTime then
            conn:Disconnect()
            if bullet.Parent then bullet:Destroy() end
            return
        end

        -- Advance segment index forward (never backwards — O(1) amortised)
        while lastSegIdx < #times - 1 and times[lastSegIdx + 1] <= elapsed do
            lastSegIdx += 1
        end

        local segA = waypoints[lastSegIdx]
        local segB = waypoints[math.min(lastSegIdx + 1, #waypoints)]
        local tA   = times[lastSegIdx]
        local tB   = times[math.min(lastSegIdx + 1, #times)]
        local segT = (tB > tA) and (elapsed - tA) / (tB - tA) or 0

        local interpPos = segA:Lerp(segB, math.clamp(segT, 0, 1))
        local lookDir   = segB - segA
        if lookDir.Magnitude > 0.001 then
            setBulletCFrame(CFrame.lookAt(interpPos, interpPos + lookDir))
        end
    end)

    task.delay(totalTime + 0.5, function()
        conn:Disconnect()
        if bullet.Parent then bullet:Destroy() end
    end)
end

-- Other players' bullets: exclude the shooter's character so the bullet
-- doesn't immediately hit their own head at the origin point
TracerRemote.OnClientEvent:Connect(function(origin: Vector3, direction: Vector3, speed: number, shooterChar)
    local filter = shooterChar and { shooterChar } or {}
    runBulletVisual(origin, direction, speed, filter)
    flashMuzzleEffects(getOrCreateWorldMuzzleEffects(shooterChar))
end)

local function reload()
    local cfg = Framework.WeaponConfig
    if not cfg then return end
    if isReloading then return end
    if reserveAmmo <= 0 then return end
    if currentAmmo >= cfg.MaxMag then return end

    isReloading  = true
    reloadToken += 1
    local token  = reloadToken
    playSound("Reload")
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
    if not cfg then return end
    if currentAmmo <= 0 then return end

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
    currentAmmo -= 1
    GUIHandler:UpdateAmmo(currentAmmo, reserveAmmo, cfg.MaxMag)
    flashMuzzleEffects(Framework.MuzzleEffects)

    local dir       = Camera.CFrame.LookVector
    local char      = Players.LocalPlayer.Character
    local muzzlePos = Framework.MuzzlePart and Framework.MuzzlePart.CFrame.Position
        or Camera.CFrame.Position

    -- Filter: own character + Camera (which holds the viewmodel & weapon model)
    local filter = { Camera }
    if char then table.insert(filter, char) end
    runBulletVisual(muzzlePos, dir, (cfg.MuzzleVelocity.X + cfg.MuzzleVelocity.Y) / 2, filter)

    playSound("Shoot")
    ShootRemote:FireServer(dir)
    AnimationPlayer:PlayThen("Shoot", isAiming and "Aiming" or "Idle")
end

local function tryFire()
    local cfg = Framework.WeaponConfig
    if not cfg or isBursting or isReloading then return end
    if currentAmmo <= 0 then
        local now = tick()
        if now - lastEmptyMagSoundTime >= 0.5 then
            playSound("Global_EmptyMag")
            lastEmptyMagSoundTime = now
        end
        return
    end

    local minInterval = 60 / ((cfg.RPM.X + cfg.RPM.Y) / 2)
    if timeSinceLastShot < minInterval then return end

    if currentFireMode == "Burst" then
        local burstCount = cfg.BurstCount or 3
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

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = true
        if currentFireMode == "Semi" or currentFireMode == "Burst" then
            tryFire()
        end

    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isReloading then return end
        isAiming = true
        playSound("AimIn")
        AnimationPlayer:PlayThen("AimIn", "Aiming")
        PT_ACTIONRemote:FireServer(2)

    elseif input.KeyCode == Enum.KeyCode.M then
        cycleFireMode()
    elseif input.KeyCode == Enum.KeyCode.R then
        reload()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = false

    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isReloading then return end
        isAiming = false
        playSound("AimOut")
        AnimationPlayer:PlayThen("AimOut", "Idle")
        PT_ACTIONRemote:FireServer(1)
    end
end)

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
local IK_LERP_SPEED = 12
local ikPushFactor  = 0
local ikParams      = RaycastParams.new()
ikParams.FilterType = Enum.RaycastFilterType.Exclude

-- Load Inv
ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadInventory").OnClientEvent:Connect(function(Inventory)
    Framework.Inventory = Inventory
end)

ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon").OnClientEvent:Connect(function(Weapon)
    LoadSlot(Weapon)

    TILT_AMOUNT    = Framework.WeaponConfig.TILT_AMOUNT -- barrel-up / stock-down pitch at full backward speed
    TILT_FADE      = Framework.WeaponConfig.TILT_FADE   
    BOB_FREQ       = Framework.WeaponConfig.BOB_FREQ     -- stride rate at full walkspeed (rad/sec)
    BOB_AMPLITUDE  = Framework.WeaponConfig.BOB_AMPLITUDE  -- max bob offset in studs
    BOB_FADE       = Framework.WeaponConfig.BOB_FADE
    SWAY_SPEED     = Framework.WeaponConfig.SWAY_SPEED
    ROLL_SCALE     = Framework.WeaponConfig.ROLL_SCALE
    PITCH_SCALE    = Framework.WeaponConfig.PITCH_SCALE
    FALL_TILT      = Framework.WeaponConfig.FALL_TILT
    FALL_STIFFNESS = Framework.WeaponConfig.FALL_STIFFNESS
    FALL_DAMPING   = Framework.WeaponConfig.FALL_DAMPING
    LAND_KICK      = Framework.WeaponConfig.LAND_KICK
    LAND_STIFFNESS = Framework.WeaponConfig.LAND_STIFFNESS
    LAND_DAMPING   = Framework.WeaponConfig.LAND_DAMPING

    reloadToken += 1
    currentAmmo  = Framework.WeaponConfig.MaxMag
    reserveAmmo  = Framework.WeaponConfig.ReserveAmmo or 0
    isReloading  = false
    GUIHandler:UpdateAmmo(currentAmmo, reserveAmmo, Framework.WeaponConfig.MaxMag)

    local ikCfg = Framework.WeaponConfig.IK or {}
    IK_ENABLED    = ikCfg.Enabled    == true
    IK_CHECK_DIST = ikCfg.CheckDist  or 0
    IK_MAX_PUSH   = ikCfg.MaxPush    or 0
    IK_MAX_ANGLE  = ikCfg.MaxAngle   or 0
    IK_LERP_SPEED = ikCfg.LerpSpeed  or 12
    ikPushFactor  = 0
end)

-- Run after Roblox's Camera/Character pass so our LocalTransparencyModifier reset
-- overrides the engine's first-person auto-hide on Camera descendants.
RunService:BindToRenderStep("ViewmodelUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
    -- Shooting: advance timer, auto-fire if held
    timeSinceLastShot = timeSinceLastShot + dt
    local cfg = Framework.WeaponConfig
    if isShooting and currentFireMode == "Auto" then
        tryFire()
    end

    -- Recoil recovery: starts after a brief pause, exponentially returns to 0
    if timeSinceLastShot > 0.12 and (recoilPitchAccum ~= 0 or recoilYawAccum ~= 0) then
        local recoverySpeed = cfg and cfg.Recoil.Recovery or 8
        local pitchRec = recoilPitchAccum * (1 - math.exp(-recoverySpeed * dt))
        local yawRec   = recoilYawAccum   * (1 - math.exp(-recoverySpeed * dt))
        CameraHandler.RecoilPitch = CameraHandler.RecoilPitch + pitchRec
        CameraHandler.RecoilYaw   = CameraHandler.RecoilYaw   - yawRec
        recoilPitchAccum = recoilPitchAccum - pitchRec
        recoilYawAccum   = recoilYawAccum   - yawRec
        if timeSinceLastShot > 1.5 then
            shotCount = 0  -- reset pattern after sustained idle
        end
    end

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

    -- Fall spring: drives toward target angle based on downward velocity
    local vertVel    = hrp and hrp.AssemblyLinearVelocity.Y or 0
    local fallTarget = grounded and 0 or math.clamp(-vertVel / 50, 0, 1) * FALL_TILT
    local fallAcc    = -FALL_STIFFNESS * (fallSpringPos - fallTarget) - FALL_DAMPING * fallSpringVel
    fallSpringVel    = fallSpringVel + fallAcc * dt
    fallSpringPos    = fallSpringPos + fallSpringVel * dt

    -- Landing spring: velocity kick on touchdown, spring returns to 0
    if prevGrounded == false and grounded then
        local impactMag = math.clamp(-airVertVel / 50, 0, 1)
        landSpringVel   = landSpringVel + impactMag * LAND_KICK
    end
    if not grounded then airVertVel = vertVel end
    local landAcc = -LAND_STIFFNESS * landSpringPos - LAND_DAMPING * landSpringVel
    landSpringVel = landSpringVel + landAcc * dt
    landSpringPos = landSpringPos + landSpringVel * dt
    prevGrounded  = grounded

    local fallCF = CFrame.Angles(fallSpringPos + landSpringPos, 0, 0)

    -- ADS alpha + FOV
    local adsTarget = isAiming and 1 or 0
    local adsSpeed  = Framework.WeaponConfig and (1 / math.max(Framework.WeaponConfig.AimSpeed, 0.01)) or 6
    adsAlpha = adsAlpha + (adsTarget - adsAlpha) * (1 - math.exp(-adsSpeed * dt))
    Camera.FieldOfView = baseFOV - adsAlpha * 25

    -- IK wall pushback
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
            local hipfireCF = Camera.CFrame * pushCF * GlobalConfig.VIEWMODEL_OFFSET * swayCF * bobCF * tiltCF * fallCF

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