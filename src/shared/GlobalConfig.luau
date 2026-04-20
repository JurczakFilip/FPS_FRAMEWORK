local GlobalConfig = {}

GlobalConfig.Debug = true

GlobalConfig.Viewmodel = "Default"
GlobalConfig.VIEWMODEL_OFFSET = CFrame.new(0, 0, 2)

GlobalConfig.CameraHandler = {
    MOUSE_SENSITIVITY     = 0.30        , -- degrees per pixel
    PITCH_LIMIT           = math.rad(80), -- max up/down look angle
    BODY_ROTATE_THRESHOLD = math.rad(5) , -- how far camera can lead before character turns
    STRAFE_ROLL           = math.rad(2) , -- peak camera roll when strafing at full walkspeed
    STRAFE_ROLL_LERP      = 8           , -- higher = snappier roll response
}

GlobalConfig.MotionBlur = {
    SCALE      = 0.4, -- mouse pixel magnitude → blur size units
    MAX        = 14,  -- maximum BlurEffect.Size (Roblox range: 0–56)
    FADE_SPEED = 6,  -- lerp speed when slowing down
}

GlobalConfig.PitchReplication = {
    NECK_WEIGHT     = 0.3,          -- fraction of pitch applied to Neck Motor6D (vertical)
    WAIST_WEIGHT    = 0.7,          -- fraction of pitch applied to Waist Motor6D (vertical)
    NECK_YAW_WEIGHT = 1.0,          -- fraction of relative yaw applied to Neck Motor6D (horizontal)
    MAX_PITCH       = math.rad(80), -- server-side clamp (should match PITCH_LIMIT above)
    SMOOTH_SPEED    = 10,           -- lerp speed per second (higher = snappier)
    SEND_RATE       = 1 / 15,       -- client fires look angles to server at 15 Hz
}


GlobalConfig.LeanHandler = {
    RANGE_OF_MOTION = 75,    -- max strafe lean angle for hips/body (degrees)
    LERP_SPEED      = 0.005, -- interpolation speed — lower = smoother but slower to respond
    WAIST_COUNTER   = 0.5,   -- fraction of body roll absorbed by Waist (0 = R6-style neck-only, 1 = upper body fully upright)
}

return GlobalConfig