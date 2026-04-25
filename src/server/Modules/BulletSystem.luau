local BulletSystem = {}

local GRAVITY    = Vector3.new(0, -workspace.Gravity, 0)
local STEP_SIZE  = 0.05  -- seconds per simulation step (~45 studs at 900 m/s)
local MAX_STEPS  = 200

local function applySpread(direction, moaDegrees)
    local spreadRad   = math.rad(moaDegrees / 60)
    local randomAngle = math.random() * 2 * math.pi
    local cone        = math.tan(math.random() * spreadRad)

    local right = direction:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.001 then
        right = direction:Cross(Vector3.new(1, 0, 0))
    end
    right = right.Unit
    local up = right:Cross(direction).Unit

    return (direction.Unit + (right * math.cos(randomAngle) + up * math.sin(randomAngle)) * cone).Unit
end

local function calcDamage(baseDamage, distance, dropoff)
    if distance <= dropoff.Start then return baseDamage end
    if distance >= dropoff.End   then return dropoff.Min end
    local t = (distance - dropoff.Start) / (dropoff.End - dropoff.Start)
    return baseDamage + (dropoff.Min - baseDamage) * t
end

function BulletSystem.Fire(pt, origin, direction)
    local cfg = pt.WeaponConfig

    local speed   = math.random(cfg.MuzzleVelocity.X * 10, cfg.MuzzleVelocity.Y * 10) / 10
    local baseMOA = math.random(cfg.Accuracy.X * 10, cfg.Accuracy.Y * 10) / 10
    if pt.IsAiming then
        baseMOA = baseMOA * (cfg.ADSAccuracyMul or 0.5)
    end
    -- Hipfire penalty
    if not pt.IsAiming then
        baseMOA = baseMOA * (cfg.HipfireSpread or 1.5)
    end

    local dir = applySpread(direction, baseMOA)

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { pt.Player.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local pos      = origin
    local vel      = dir * speed
    local traveled = 0
    local maxRange = cfg.MaxRange or 1500

    for _ = 1, MAX_STEPS do
        local newVel = vel + GRAVITY * STEP_SIZE
        local newPos = pos + vel * STEP_SIZE
        local delta  = newPos - pos

        local result = workspace:Raycast(pos, delta, params)
        if result then
            local dist     = (result.Position - origin).Magnitude
            local parent   = result.Instance.Parent
            local humanoid = parent:FindFirstChildOfClass("Humanoid")
                or (parent.Parent and parent.Parent:FindFirstChildOfClass("Humanoid"))

            if humanoid and humanoid.Health > 0 then
                local dmg = calcDamage(cfg.Damage, dist, cfg.DamageDropoff)
                humanoid:TakeDamage(math.round(dmg))
            end

            return result, dir, speed
        end

        traveled = traveled + delta.Magnitude
        if traveled >= maxRange then break end

        pos = newPos
        vel = newVel
    end

    return nil, dir, speed
end

return BulletSystem
