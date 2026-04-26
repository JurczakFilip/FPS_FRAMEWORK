local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules           = script.Parent:WaitForChild("Modules")
local Players           = game:GetService("Players")

require(Modules:WaitForChild("CameraHandler")).Setup()
local Test_Inventory  = require(Modules:WaitForChild("Inventory"))
local AnimationPlayer = require(Modules:WaitForChild("AnimationPlayer"))
local BulletSystem    = require(Modules:WaitForChild("BulletSystem"))

local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local Remotes      = IRNVRep:WaitForChild("Remotes")
local TracerRemote = Remotes:WaitForChild("TracerVisual")

local Framework = {
    Test_Inventory = Test_Inventory,
    PT             = {},
}

-- ─── Player Tracker ───────────────────────────────────────────────────────────

local PT = {}
PT.__index = PT

function PT.Add(player)
    local self = setmetatable({}, PT)
    self.Player         = player
    self.Inventory      = Framework.Test_Inventory
    self.CurrentWeapon  = nil
    self.WeaponConfig   = nil
    self.WeaponModel    = nil
    self.Animator       = nil
    self.AnimationTrack = nil
    self.AnimChainToken = 0
    self.IsAiming       = false
    self.LastFireTime   = -math.huge
    self.LastReloadTime = -math.huge
    self.ShotCount      = 0
    self.CurrentAmmo    = 0
    self.ReserveAmmo    = 0
    table.insert(Framework.PT, self)
    return self
end

function PT:Search(player)
    for _, entry in ipairs(Framework.PT) do
        if entry.Player == player then
            return entry
        end
    end
    return nil
end

function PT:Remove(player)
    for i, entry in ipairs(Framework.PT) do
        if entry.Player == player then
            table.remove(Framework.PT, i)
            return
        end
    end
end

-- ─── Weapon Loading ───────────────────────────────────────────────────────────

local function LoadSlot(tracked)
    AnimationPlayer.Stop(tracked)
    if tracked.WeaponModel then
        tracked.WeaponModel:Destroy()
        tracked.WeaponModel = nil
    end
    tracked.WeaponConfig = nil

    local WeaponModel_Folder  = IRNVRep:WaitForChild("WeaponModels")
    local WeaponConfig_Folder = IRNVRep:WaitForChild("WeaponConfig")

    if WeaponModel_Folder:FindFirstChild(tracked.CurrentWeapon.WeaponName) then
        tracked.WeaponModel      = WeaponModel_Folder:FindFirstChild(tracked.CurrentWeapon.WeaponName):Clone()
        tracked.WeaponModel.Name = "[SERVER]_" .. tracked.CurrentWeapon.WeaponName
    else
        warn("[SERVER] Couldn't locate WeaponModel: " .. tracked.CurrentWeapon.WeaponName)
        return
    end

    if WeaponConfig_Folder:FindFirstChild(tracked.CurrentWeapon.WeaponName) then
        tracked.WeaponConfig = require(WeaponConfig_Folder:FindFirstChild(tracked.CurrentWeapon.WeaponName))
    else
        warn("[SERVER] Couldn't locate WeaponConfig: " .. tracked.CurrentWeapon.WeaponName)
        return
    end

    local char        = tracked.Player.Character
    local GripMotor6D = Instance.new("Motor6D")
    GripMotor6D.Name  = "[WORLD] GripMotor6D"

    tracked.WeaponModel.PrimaryPart.Anchored = false
    GripMotor6D.Part0  = char.RightHand
    GripMotor6D.Part1  = tracked.WeaponModel.PrimaryPart
    GripMotor6D.C0     = tracked.WeaponConfig.WorldGripOffset.C0
    GripMotor6D.C1     = tracked.WeaponConfig.WorldGripOffset.C1
    GripMotor6D.Parent = char.RightHand

    tracked.WeaponModel.Parent = char.RightHand

    AnimationPlayer.SetCharacter(tracked, char)
    AnimationPlayer.Play(tracked, "Idle")
end

-- ─── PT_ACTION ────────────────────────────────────────────────────────────────
-- Action 1: AimOut → Idle (hipfire state)
-- Action 2: AimIn  → Aiming (scoped state)

local PT_ACTION_HANDLERS = {
    [1] = function(tracked)
        tracked.IsAiming = false
        AnimationPlayer.PlayThen(tracked, "AimOut", "Idle")
    end,
    [2] = function(tracked)
        tracked.IsAiming = true
        AnimationPlayer.PlayThen(tracked, "AimIn", "Aiming")
    end,
}

Remotes:WaitForChild("PT_ACTION").OnServerEvent:Connect(function(player, action)
    local tracked = PT:Search(player)
    if not tracked then return end
    local handler = PT_ACTION_HANDLERS[action]
    if handler then handler(tracked) end
end)

-- ─── Reload ───────────────────────────────────────────────────────────────────

Remotes:WaitForChild("Reload").OnServerEvent:Connect(function(player)
    local tracked = PT:Search(player)
    if not tracked or not tracked.WeaponConfig then return end
    local cfg = tracked.WeaponConfig
    if tracked.ReserveAmmo <= 0 then return end
    if tracked.CurrentAmmo >= cfg.MaxMag then return end

    local now = tick()
    if now - tracked.LastReloadTime < cfg.ReloadTime * 0.9 then return end
    tracked.LastReloadTime = now

    tracked.ReloadToken = (tracked.ReloadToken or 0) + 1
    local token = tracked.ReloadToken

    local nextAnim = tracked.IsAiming and "Aiming" or "Idle"
    AnimationPlayer.PlayThen(tracked, "Reload", nextAnim)

    task.delay(cfg.ReloadTime, function()
        if tracked.ReloadToken ~= token then return end
        local needed = cfg.MaxMag - tracked.CurrentAmmo
        local given  = math.min(needed, tracked.ReserveAmmo)
        tracked.CurrentAmmo = tracked.CurrentAmmo + given
        tracked.ReserveAmmo = tracked.ReserveAmmo - given
    end)
end)

-- ─── Shoot ────────────────────────────────────────────────────────────────────

Remotes:WaitForChild("Shoot").OnServerEvent:Connect(function(player, direction)
    if typeof(direction) ~= "Vector3" then return end
    direction = direction.Unit
    if direction ~= direction then return end  -- NaN guard

    local tracked = PT:Search(player)
    if not tracked or not tracked.WeaponConfig then return end
    if tracked.CurrentAmmo <= 0 then return end

    -- Validate character exists before touching any state
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- Server-side RPM gate (10% tolerance for network jitter)
    local cfg         = tracked.WeaponConfig
    local rpm         = (cfg.RPM.X + cfg.RPM.Y) / 2
    local minInterval = 60 / rpm
    local now         = tick()
    if now - tracked.LastFireTime < minInterval * 0.9 then return end
    tracked.LastFireTime = now
    tracked.ShotCount    = tracked.ShotCount + 1
    tracked.CurrentAmmo -= 1

    local nextAnim = tracked.IsAiming and "Aiming" or "Idle"
    AnimationPlayer.PlayThen(tracked, "Shoot", nextAnim)

    local _, actualDir, bulletSpeed = BulletSystem.Fire(tracked, head.Position, direction)

    -- Broadcast tracer to all OTHER clients so they see the bullet
    local muzzlePart  = tracked.WeaponModel and tracked.WeaponModel:FindFirstChild("MuzzlePart", true)
    local tracerOrigin = muzzlePart and muzzlePart.CFrame.Position or head.Position

    local whizCategory = cfg.Effects and cfg.Effects.WhizCategory
    local shootSoundId = cfg.Effects and cfg.Effects.Sound and cfg.Effects.Sound.Shoot
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            TracerRemote:FireClient(p, tracerOrigin, actualDir, bulletSpeed, char, whizCategory, shootSoundId)
        end
    end
end)

-- ─── Player lifecycle ─────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local tracked        = PT.Add(player)
        tracked.CurrentWeapon = tracked.Inventory[1]
        LoadSlot(tracked)
        if tracked.WeaponConfig then
            tracked.CurrentAmmo = tracked.WeaponConfig.MaxMag
            tracked.ReserveAmmo = tracked.WeaponConfig.ReserveAmmo or 0
        end
        Remotes:WaitForChild("LoadInventory"):FireClient(player, Framework.Test_Inventory)
        Remotes:WaitForChild("LoadWeapon"):FireClient(player, tracked.CurrentWeapon)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PT:Remove(player)
end)
