local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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
    Inventory   = nil,
    WeaponConfig = nil,
    Viewmodel    = nil,
    WeaponModel  = nil,
    AimPart      = nil,
    MuzzlePart   = nil,
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
    _animator    = nil,
    _track       = nil,
    _chainToken  = 0,
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
    self._chainToken += 1 -- cancel any pending PlayThen chain
    if self._track then self._track:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    self._track = self._animator:LoadAnimation(anim)
    anim:Destroy()
    self._track:Play()
    DebugPrint("AnimationPlayer: playing '"..AnimationType.."'")
end

-- Plays animType, then plays nextAnimType once it finishes naturally.
-- Cancelled automatically if any other animation is requested first.
function AnimationPlayer:PlayThen(animType: string, nextAnimType: string)
    self:Play(animType)
    local track = self._track
    if not track then return end
    track.Looped = false
    self._chainToken += 1
    local token = self._chainToken
    track.Stopped:Once(function()
        if self._chainToken == token then
            self:Play(nextAnimType)
        end
    end)
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

    Framework.AimPart   = Framework.WeaponModel:FindFirstChild("AimPart",   true)
    Framework.MuzzlePart = Framework.WeaponModel:FindFirstChild("MuzzlePart", true)
    DebugPrint(Framework.AimPart    and "AimPart found."    or "No AimPart — ADS disabled.")
    DebugPrint(Framework.MuzzlePart and "MuzzlePart found." or "No MuzzlePart — tracer starts from camera.")

    AnimationPlayer:SetViewmodel(Framework.Viewmodel)
    AnimationPlayer:Play("Idle")
    initFireMode()

    -- Delete  World view Weapon Model
    local Character = Players.LocalPlayer.Character
    local WeaponWorldModel = Character.RightHand:FindFirstChild("[SERVER]_"..Weapon.WeaponName)
    WeaponWorldModel:Destroy()

    --PLAY ALL ANIMS TO REMOVE LOADING TIME LATER ON
    task.wait(.125)
    AnimationPlayer:PlayThen("AimIn", "Aiming")
    task.wait(.125)
    AnimationPlayer:PlayThen("AimOut", "Idle")
end

local IRNVRemotes     = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes")
local ShootRemote     = IRNVRemotes:WaitForChild("Shoot")
local PT_ACTIONRemote = IRNVRemotes:WaitForChild("PT_ACTION")
local TracerRemote    = IRNVRemotes:WaitForChild("TracerVisual")
local BulletTemplate  = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Bullet")
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
            return
        end
    end
end

local function playSound(soundId: number)
    if not soundId or soundId == 0 then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Parent  = Camera
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
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
            playSound(GlobalConfig.FireModeSwitchSound)
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

    local totalTime = times[#times]

    local bullet        = BulletTemplate:Clone()
    bullet.CFrame       = CFrame.lookAt(waypoints[1], waypoints[2])
    bullet.Parent       = workspace

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
            bullet.CFrame = CFrame.lookAt(interpPos, interpPos + lookDir)
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
    playSound(cfg.Effects.Sound.Reload)
    AnimationPlayer:PlayThen("Reload", isAiming and "Aiming" or "Idle")
    ReloadRemote:FireServer()

    task.delay(cfg.ReloadTime, function()
        if reloadToken ~= token then return end
        local needed = cfg.MaxMag - currentAmmo
        local given  = math.min(needed, reserveAmmo)
        currentAmmo  = currentAmmo + given
        reserveAmmo  = reserveAmmo - given
        isReloading  = false
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

    local dir       = Camera.CFrame.LookVector
    local char      = Players.LocalPlayer.Character
    local muzzlePos = Framework.MuzzlePart and Framework.MuzzlePart.CFrame.Position
        or Camera.CFrame.Position

    -- Filter: own character + Camera (which holds the viewmodel & weapon model)
    local filter = { Camera }
    if char then table.insert(filter, char) end
    runBulletVisual(muzzlePos, dir, (cfg.MuzzleVelocity.X + cfg.MuzzleVelocity.Y) / 2, filter)

    playSound(cfg.Effects.Sound.Shoot)
    ShootRemote:FireServer(dir)
    AnimationPlayer:PlayThen("Shoot", isAiming and "Aiming" or "Idle")
end

local function tryFire()
    local cfg = Framework.WeaponConfig
    if not cfg or isBursting or isReloading then return end
    if currentAmmo <= 0 then
        local now = tick()
        if now - lastEmptyMagSoundTime >= 0.5 then
            playSound(GlobalConfig.EmptyMagSound)
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
        isAiming = true
        playSound(Framework.WeaponConfig and Framework.WeaponConfig.Effects.Sound.AimIn)
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
        isAiming = false
        playSound(Framework.WeaponConfig and Framework.WeaponConfig.Effects.Sound.AimOut)
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

    for _, v in pairs(Camera:GetChildren()) do
        if v:IsA("Model") and v.PrimaryPart then
            local hipfireCF = Camera.CFrame * GlobalConfig.VIEWMODEL_OFFSET * swayCF * bobCF * tiltCF * fallCF

            local finalCF = hipfireCF
            if Framework.AimPart and adsAlpha > 0 then
                -- offset of AimPart from the model pivot (read from last frame — 1-frame stale, imperceptible)
                local aimOffsetFromPivot = v:GetPivot():Inverse() * Framework.AimPart.CFrame
                local adsCF = Camera.CFrame * aimOffsetFromPivot:Inverse()
                finalCF = hipfireCF:Lerp(adsCF, adsAlpha)
            end

            v:PivotTo(finalCF)
        end
    end
end)