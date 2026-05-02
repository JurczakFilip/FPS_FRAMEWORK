local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local MuzzleFolder = IRNVRep:WaitForChild("WeaponEffects"):WaitForChild("Visual"):WaitForChild("Muzzle")
local DURATION     = GlobalConfig.MuzzleFlash.DURATION

local _cache = {}

local function isToggleable(inst: Instance): boolean
    return inst:IsA("ParticleEmitter") or inst:IsA("Light") or inst:IsA("Beam") or inst:IsA("Trail")
end

local MuzzleEffects = {}

function MuzzleEffects.Clone(muzzlePart: BasePart?, visualName: string?)
    if not muzzlePart or not visualName then return {} end
    local template = MuzzleFolder:FindFirstChild(visualName)
    if not template then return {} end
    local effects = {}
    for _, fx in ipairs(template:GetChildren()) do
        local clone = fx:Clone()
        clone.Parent = muzzlePart
        if isToggleable(clone) then clone.Enabled = false end
        table.insert(effects, clone)
    end
    return effects
end

function MuzzleEffects.Flash(effects)
    if not effects or #effects == 0 then return end
    for _, fx in ipairs(effects) do
        if isToggleable(fx) then fx.Enabled = true end
    end
    task.delay(DURATION, function()
        for _, fx in ipairs(effects) do
            if fx.Parent and isToggleable(fx) then fx.Enabled = false end
        end
    end)
end

function MuzzleEffects.GetOrCreateForChar(shooterChar: Model)
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

    local cached = _cache[muzzle]
    if cached then return cached end

    local weaponName = worldModel.Name:sub(10) -- strip "[SERVER]_"
    local cfgModule  = IRNVRep:WaitForChild("WeaponConfig"):FindFirstChild(weaponName)
    if not cfgModule then return nil end

    local ok, cfg = pcall(require, cfgModule)
    if not ok or type(cfg) ~= "table" then return nil end

    local visualName = cfg.Effects and cfg.Effects.Visual
    if not visualName then return nil end

    local effects = MuzzleEffects.Clone(muzzle, visualName)
    _cache[muzzle] = effects
    muzzle.Destroying:Connect(function() _cache[muzzle] = nil end)
    return effects
end

return MuzzleEffects
