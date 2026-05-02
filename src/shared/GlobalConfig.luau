local GlobalConfig = {}

-- ─── Debug & Misc ─────────────────────────────────────────────────────────────
GlobalConfig.Debug            = false
GlobalConfig.Viewmodel        = "Desert"
GlobalConfig.VIEWMODEL_OFFSET = CFrame.new(0, 0, 1)

-- ReplicatedStorage shared folder name (used by every module to find remotes/configs)
GlobalConfig.RepFolderName = "[IRNV_FPS] V1 (REP)"

-- ─── Camera ───────────────────────────────────────────────────────────────────
GlobalConfig.CameraHandler = {
    MOUSE_SENSITIVITY      = 0.30        , -- degrees per pixel
    PITCH_LIMIT            = math.rad(80), -- max up/down look angle
    BODY_ROTATE_THRESHOLD  = math.rad(5) , -- how far camera can lead before character turns
    STRAFE_ROLL            = math.rad(2) , -- peak camera roll when strafing at full walkspeed
    STRAFE_ROLL_LERP       = 8           , -- higher = snappier roll response
    HEAD_SMOOTH_RATE       = 60          , -- exp lerp rate for SmoothHeadPos (higher = snappier)
    HEAD_EXTRAPOLATION_CAP = 1 / 30      , -- max seconds to extrapolate forward from last physics step
}

-- ─── Alt Look (Rust-style free look) ─────────────────────────────────────────
GlobalConfig.AltLook = {
    KEY          = Enum.KeyCode.LeftAlt,
    YAW_LIMIT    = math.rad(120),
    RETURN_SPEED = 12,
}

-- ─── Motion Blur ──────────────────────────────────────────────────────────────
GlobalConfig.MotionBlur = {
    SCALE      = 0.4, -- mouse pixel magnitude → blur size units
    MAX        = 14,  -- maximum BlurEffect.Size (Roblox range: 0–56)
    FADE_SPEED = 6,   -- lerp speed when slowing down
}

-- ─── Pitch Replication (server joint write) ──────────────────────────────────
GlobalConfig.PitchReplication = {
    NECK_WEIGHT     = 0.3,
    WAIST_WEIGHT    = 0.7,
    NECK_YAW_WEIGHT = 1.0,
    MAX_PITCH       = math.rad(80),
    SMOOTH_SPEED    = 10,
    SEND_RATE       = 1 / 15, -- 15 Hz
}

-- ─── Landing Jolt ─────────────────────────────────────────────────────────────
GlobalConfig.LandingJolt = {
    KICK                      = math.rad(25), -- peak downward pitch kick at terminal fall speed
    STIFFNESS                 = 160,
    DAMPING                   = 18,
    TERMINAL_VELOCITY_DIVISOR = 50, -- |airVertVel| / this → normalised impact (0..1)
}

-- ─── Crouch ───────────────────────────────────────────────────────────────────
GlobalConfig.Crouch = {
    KEY        = Enum.KeyCode.LeftControl,
    TOGGLE     = false,
    WALK_SPEED = 8,
    Animations = {
        Idle = 131522243174622,
        Walk = 102213736910183,
    },
}

-- ─── Lean ─────────────────────────────────────────────────────────────────────
GlobalConfig.LeanHandler = {
    RANGE_OF_MOTION = 75,    -- max strafe lean angle (degrees)
    LERP_SPEED      = 0.005, -- lower = smoother, slower to respond
    WAIST_COUNTER   = 0.5,   -- fraction of body roll absorbed by Waist
}

-- ─── Recoil ───────────────────────────────────────────────────────────────────
GlobalConfig.Recoil = {
    RECOVERY_DELAY     = 0.12, -- seconds after last shot before recovery starts
    PATTERN_RESET_IDLE = 1.5,  -- seconds of no firing before shotCount resets
    FALLBACK_RECOVERY  = 8,    -- per-second exp rate when WeaponConfig.Recoil.Recovery missing
}

-- ─── Fire ─────────────────────────────────────────────────────────────────────
GlobalConfig.Fire = {
    EMPTY_MAG_DEBOUNCE  = 0.5, -- minimum seconds between empty-mag click sounds
    DEFAULT_BURST_COUNT = 3,   -- fallback when WeaponConfig.BurstCount missing
    FIRE_MODE_ORDER     = { "Semi", "Auto", "Burst" },
}

-- ─── ADS ──────────────────────────────────────────────────────────────────────
GlobalConfig.ADS = {
    FALLBACK_SPEED = 6,  -- exp speed when WeaponConfig.AimSpeed missing
    FOV_REDUCTION  = 25, -- degrees subtracted from baseFOV at full ADS
}

-- ─── IK ───────────────────────────────────────────────────────────────────────
GlobalConfig.IK = {
    FALLBACK_LERP_SPEED = 12,
}

-- ─── Viewmodel Springs (fall + landing) ──────────────────────────────────────
GlobalConfig.ViewmodelSprings = {
    FALL_TERMINAL_DIVISOR = 50, -- vertVel / this → fall tilt input (0..1)
    LAND_TERMINAL_DIVISOR = 50, -- airVertVel / this → landing kick magnitude (0..1)
}

-- ─── Muzzle Flash ─────────────────────────────────────────────────────────────
GlobalConfig.MuzzleFlash = {
    DURATION = 0.05, -- seconds particles/lights/beams/trails stay enabled per shot
}

-- ─── Bullet Visual ────────────────────────────────────────────────────────────
GlobalConfig.BulletVisual = {
    TRACER_STEP   = 0.05, -- physics-step size for predicted trajectory (matches server BulletSystem)
    MAX_STEPS     = 200,  -- iteration cap for trajectory pre-simulation
    DEFAULT_RANGE = 1500, -- fallback when WeaponConfig.MaxRange missing
    CLEANUP_DELAY = 0.5,  -- seconds after totalTime before forcing bullet destroy
}

-- ─── Sound System ─────────────────────────────────────────────────────────────
GlobalConfig.SoundSystem = {
    SPATIAL_DEBRIS_LIFETIME = 10, -- safety net lifetime for spatial sound host parts
}

-- ─── Whiz ─────────────────────────────────────────────────────────────────────
GlobalConfig.Whiz = {
    DISTANCE = 6, -- max studs from local HRP to bullet path that triggers a whiz
}

-- ─── Arm Transparency ─────────────────────────────────────────────────────────
GlobalConfig.ArmParts = {
    "LeftLowerArm", "LeftUpperArm",
    "RightLowerArm", "RightUpperArm",
    "LeftHand", "RightHand",
}

-- ─── Global Sounds ────────────────────────────────────────────────────────────
GlobalConfig.Sounds = {
    FIRE_MODE_SWITCH = 72425104284712,
    EMPTY_MAG        = 132417837934974,
}

return GlobalConfig
