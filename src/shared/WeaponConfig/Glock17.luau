local Config = {}

--// Core Stats
Config.MaxMag         = 17                        -- standard 17-round magazine
Config.RPM            = Vector2.new(280, 400)     -- semi-auto; limited by human trigger pull (~5 rds/s ceiling)
Config.MuzzleVelocity = Vector2.new(360, 380)     -- m/s (9×19mm, 114 mm barrel, ~370 m/s nominal)
Config.Accuracy       = Vector2.new(4, 7)         -- MOA (open sights, shorter sight radius than rifle)

Config.GripOffset = {
    C0 = CFrame.new(0.25, 1.9, 0) * CFrame.fromEulerAnglesYXZ(math.rad(90), math.rad(90), math.rad(0)),
    C1 = CFrame.new(0, 0, 0)      * CFrame.fromEulerAnglesYXZ(math.rad(0), math.rad(0), math.rad(0))
}

Config.WorldGripOffset = {
    C0 = CFrame.new(0, 0.35, 0) * CFrame.fromEulerAnglesYXZ(math.rad(0), math.rad(-90), math.rad(90)),
    C1 = CFrame.new(0, 0, 0)    * CFrame.fromEulerAnglesYXZ(math.rad(0), math.rad(0), math.rad(0))
}

--// Recoil (degrees)
Config.Recoil = {
    Vertical   = Vector2.new(0.8, 1.4),   -- sharper muzzle flip than rifle (shorter barrel, lighter frame)
    Horizontal = Vector2.new(-0.4, 0.4),
    Recovery   = 12,                      -- fast reset (low reciprocating mass)
    Pattern    = {
        1.0, 1.02, 1.04, 1.06, 1.08,
        1.10, 1.12, 1.14, 1.16, 1.18
    }
}

--// Damage
Config.Damage = 28                        -- 9mm, less energy than 5.56 (~500 J vs ~1760 J)
Config.DamageDropoff = {
    Start = 40,                           -- full damage within ~40 studs
    End   = 200,                          -- minimum damage at 200+ studs
    Min   = 12,
}
Config.MaxRange = 600                     -- pistol effective range

--// Handling
Config.AimSpeed       = 0.10             -- fast to present (compact, lightweight)
Config.HipfireSpread  = 2.0              -- less stable platform than a shouldered rifle
Config.ADSAccuracyMul = 0.5

--// Fire control
Config.FireModes = {
    Semi  = true,
    Auto  = false,
    Burst = false
}

Config.ReloadTime  = 1.8                 -- ~1.8 s for a trained mag swap
Config.ReserveAmmo = 51                  -- 3 spare mags × 17

Config.Animations = {
    FPS = {
        Idle    = 133091743109299,
        AimIn   = 136593028700494,
        Aiming  = 100294795562855,
        AimOut  = 128533045570075,
        Shoot   = 97376638455776,
        Reload  = 0,
        Inspect = 0
    },
    World = {
        Idle    = 0,
        AimIn   = 0,
        Aiming  = 0,
        AimOut  = 0,
        Shoot   = 0,
        Reload  = 0,
        Inspect = 0
    }
}

Config.Effects = {
    Sound = {
        Idle    = 0,
        AimIn   = 0,
        AimOut  = 0,
        Shoot   = 0,
        Reload  = 0,
        Inspect = 0
    },
    Visual       = "Rifle",
    WhizCategory = "Rifle"
}

Config.SWAY_SPEED  = 16
Config.ROLL_SCALE  = 0.35
Config.PITCH_SCALE = 0.20

Config.BOB_FREQ      = 10
Config.BOB_AMPLITUDE = 0.07
Config.BOB_FADE      = 9

Config.TILT_AMOUNT = math.rad(4)
Config.TILT_FADE   = 7

Config.FALL_TILT      = math.rad(14)
Config.FALL_STIFFNESS = 130
Config.FALL_DAMPING   = 11

Config.LAND_KICK      = math.rad(35)
Config.LAND_STIFFNESS = 55
Config.LAND_DAMPING   = 22

--// Wall-pushback IK
Config.IK = {
    Enabled   = true,
    CheckDist = 3,
    MaxPush   = 1.2,
    MaxAngle  = math.rad(20),
    LerpSpeed = 20,
}

return Config
