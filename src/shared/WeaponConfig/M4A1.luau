local Config = {}

--// Core Stats
Config.MaxMag         = 30
Config.RPM            = Vector2.new(500, 700)     -- rounds per minute
Config.MuzzleVelocity = Vector2.new(300, 410)     -- m/s
Config.Accuracy       = Vector2.new(2, 4)         -- MOA

Config.GripOffset = {
    C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(-90)),
    C1 = CFrame.new(0,0,0) * CFrame.Angles(0,0,0)
}

Config.WorldGripOffset = {
    C0 = CFrame.new(0, 0.35, 0) * CFrame.Angles(0, math.rad(-90), math.rad(90)),
    C1 = CFrame.new(0,0,0) * CFrame.Angles(0,0,0)
}

--// Recoil (degrees)
Config.Recoil = {
	Vertical   = Vector2.new(0.4, 0.8),  -- upward kick per shot
	Horizontal = Vector2.new(-0.25, 0.25), -- side-to-side randomness
	Recovery   = 8,                      -- how fast it recenters (higher = faster)
	Pattern = {                          -- optional spray pattern (multiplier over time)
		1.0, 1.015, 1.025, 1.035, 1.045,
		1.055, 1.065, 1.075, 1.085, 1.095
	}
}

--// Damage
Config.Damage = 34              -- base damage per bullet
Config.DamageDropoff = {
    Start = 150,                -- full damage within 150 studs
    End   = 600,                -- minimum damage at 600+ studs
    Min   = 14,
}
Config.MaxRange = 1500          -- studs, beyond this bullet simulation stops

--// Handling
Config.AimSpeed       = 0.15   -- time to ADS
Config.HipfireSpread  = 1.5    -- multiplier
Config.ADSAccuracyMul = 0.5    -- tighter spread when aiming

--// Fire control
Config.FireModes = {
	Semi  = true,
	Auto  = true,
    Burst = true
}
Config.BurstCount = 3

Config.ReloadTime  = 3.15
Config.ReserveAmmo = 90

Config.Animations = {
    FPS = {            -- Animations ran on the character via client.
        Idle    = 121193159237778,      -- Contains AssetId's of animations (Id Number only)
        AimIn   = 106846390009231,
        Aiming  = 112912922561794,
        AimOut  = 112795947362619,
        Shoot   = 132131280687454,
        Reload  = 094202694130328,
        Inspect = 0
    },
    World = {          -- Animations ran on the character via server.
        Idle    = 124253007628181,
        AimIn   = 110445400072510,
        Aiming  = 97646715533765,
        AimOut  = 139419030605737,
        Shoot   = 75062063089356,
        Reload  = 0,
        Inspect = 0
    }
}

Config.Effects = {
    Sound = {
        Idle    = 0,
        AimIn   = 132696939822714,
        AimOut  = 83044547248696,
        Shoot   = 103445789531250,
        Reload  = 100094814288653,
        Inspect = 0
    },
    Visual = "Rifle"
}

Config.SWAY_SPEED  = 14
Config.ROLL_SCALE  = 0.3
Config.PITCH_SCALE = 0.15

Config.BOB_FREQ       = 9     -- stride rate at full walkspeed (rad/sec)
Config.BOB_AMPLITUDE  = 0.08  -- max bob offset in studs
Config.BOB_FADE       = 8     -- how fast bob fades in/out on start/stop

Config.TILT_AMOUNT    = math.rad(5) -- barrel-up / stock-down pitch at full backward speed
Config.TILT_FADE      = 6            -- lerp speed for tilt in/out

Config.FALL_TILT      = math.rad(16) -- muzzle dip at terminal fall velocity
Config.FALL_STIFFNESS = 120          -- spring stiffness (higher = snappier return)
Config.FALL_DAMPING   = 10          -- damping (< 2*sqrt(stiffness) = slight float)

Config.LAND_KICK      = math.rad(40) -- velocity kick on landing (rad/s, not an angle)
Config.LAND_STIFFNESS = 50          -- spring stiffness
Config.LAND_DAMPING   = 20          -- underdamped for a subtle bounce (critical ≈ 23)

--// Wall-pushback IK
Config.IK = {
    Enabled   = true,
    CheckDist = 4,           -- studs forward from camera to probe
    MaxPush   = 1.8,           -- studs to retract weapon at full push
    MaxAngle  = math.rad(25),  -- upward muzzle tilt at full push
    LerpSpeed = 18,            -- how fast push factor approaches target
}


return Config