local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local DEFAULT_WALK_SPEED = 16

local CrouchHandler = {}
CrouchHandler.__index = CrouchHandler

function CrouchHandler.Setup(character: Model)
    local self    = setmetatable({}, CrouchHandler)
    local humanoid = character:WaitForChild("Humanoid")
    local animator = humanoid:WaitForChild("Animator")

    self._humanoid   = humanoid
    self._isCrouching = false
    self._runConn    = nil

    local function loadTrack(animId: number)
        if not animId or animId == 0 then return nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. animId
        local track = animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Action
        anim:Destroy()
        return track
    end

    self._idleTrack = loadTrack(GlobalConfig.Crouch.Animations.Idle)
    self._walkTrack = loadTrack(GlobalConfig.Crouch.Animations.Walk)

    return self
end

function CrouchHandler:SetCrouch(active: boolean)
    if active == self._isCrouching then return end
    self._isCrouching = active

    if active then
        self._humanoid.WalkSpeed = GlobalConfig.Crouch.WALK_SPEED

        if self._runConn then self._runConn:Disconnect() end
        self._runConn = self._humanoid.Running:Connect(function(speed)
            if not self._isCrouching then return end
            if speed > 0.1 then
                if self._idleTrack then self._idleTrack:Stop() end
                if self._walkTrack then self._walkTrack:Play() end
            else
                if self._walkTrack then self._walkTrack:Stop() end
                if self._idleTrack then self._idleTrack:Play() end
            end
        end)

        if self._idleTrack then self._idleTrack:Play() end
    else
        self._humanoid.WalkSpeed = DEFAULT_WALK_SPEED

        if self._runConn then
            self._runConn:Disconnect()
            self._runConn = nil
        end
        if self._idleTrack then self._idleTrack:Stop() end
        if self._walkTrack then self._walkTrack:Stop() end
    end
end

function CrouchHandler:Destroy()
    if self._runConn then self._runConn:Disconnect() end
end

return CrouchHandler
