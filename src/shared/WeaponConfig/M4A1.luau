local Config = {}

--// Core Stats
Config.MaxMag         = 30
Config.RPM            = Vector2.new(700, 900)     -- rounds per minute
Config.MuzzleVelocity = Vector2.new(880, 910)     -- m/s
Config.Accuracy       = Vector2.new(2, 4)         -- MOA

--// Recoil (degrees)
Config.Recoil = {
	Vertical   = Vector2.new(0.8, 1.6),  -- upward kick per shot
	Horizontal = Vector2.new(-0.5, 0.5), -- side-to-side randomness
	Recovery   = 8,                      -- how fast it recenters (higher = faster)
	Pattern = {                          -- optional spray pattern (multiplier over time)
		1.0, 1.05, 1.1, 1.15, 1.2,
		1.25, 1.3, 1.35, 1.4, 1.45
	}
}

--// Handling
Config.AimSpeed       = 0.15   -- time to ADS
Config.HipfireSpread  = 1.5    -- multiplier
Config.ADSAccuracyMul = 0.5    -- tighter spread when aiming

--// Fire control
Config.FireModes = {
	Semi  = true,
	Auto  = true,
    Burst = false
}

Config.ReloadTime = 2.1

Config.Animations = {
    FPS = {            -- Animations ran on the character via client.
        Idle    = 0,      -- Contains AssetId's of animations (Id Number only)
        AimIn   = 0,
        AimOut  = 0,
        Shoot   = 0,
        Reload  = 0,
        Inspect = 0
    },
    World = {          -- Animations ran on the character via server.
        Idle    = 0,
        AimIn   = 0,
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
    Visual = "Rifle"
}

return Config