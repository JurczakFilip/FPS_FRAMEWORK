local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig      = require(ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("GlobalConfig"))
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

local MOUSE_SENSITIVITY     = GlobalConfig.CameraHandler.MOUSE_SENSITIVITY
local PITCH_LIMIT           = GlobalConfig.CameraHandler.PITCH_LIMIT
local BODY_ROTATE_THRESHOLD = GlobalConfig.CameraHandler.BODY_ROTATE_THRESHOLD
local SEND_RATE             = GlobalConfig.PitchReplication.SEND_RATE

local BLUR_SCALE      = GlobalConfig.MotionBlur.SCALE
local BLUR_MAX        = GlobalConfig.MotionBlur.MAX
local BLUR_FADE_SPEED = GlobalConfig.MotionBlur.FADE_SPEED

local IRNVRep    = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local PitchRemote = IRNVRep:WaitForChild("Remotes"):WaitForChild("CameraHandler")

local CameraHandler = {}
CameraHandler.__index = CameraHandler

-- Wraps an angle to [-pi, pi] to handle yaw wrap-around correctly
local function normalizeAngle(angle)
    while angle >  math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Makes the head, face, and head-attached accessories invisible so they don't clip through the camera
local function hideHeadAndAccessories(character)
    local head = character:FindFirstChild("Head")
    if not head then return end

    -- Hide the head mesh itself
    head.Transparency = 1

    -- Hide any face decals, textures, or surface appearances on the head
    local function hideHeadDescendant(obj)
        if obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
            obj.Transparency = 1
        elseif obj:IsA("BasePart") then
            obj.Transparency = 1
        end
    end

    for _, obj in ipairs(head:GetDescendants()) do
        hideHeadDescendant(obj)
    end
    head.DescendantAdded:Connect(hideHeadDescendant)

    -- Hide head-attached accessories
    local function tryHideAccessory(obj)
        if not obj:IsA("Accessory") then return end
        local handle = obj:FindFirstChild("Handle")
        if not handle then return end
        local weld = handle:FindFirstChildOfClass("Weld")
        if weld and (weld.Part0 == head or weld.Part1 == head) then
            handle.Transparency = 1
        end
    end

    for _, obj in ipairs(character:GetChildren()) do
        tryHideAccessory(obj)
    end
    character.ChildAdded:Connect(tryHideAccessory)
end

local function waitForCharacterHead()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local head = character:WaitForChild("Head")
    return character, head
end

--Initial Setup of camera (FPS obv)
function CameraHandler.Setup()
    local self = setmetatable({}, CameraHandler)

    self.Camera = workspace.CurrentCamera
    self.Camera.CameraType = Enum.CameraType.Scriptable

    local blur = Instance.new("BlurEffect")
    blur.Size   = 0
    blur.Parent = self.Camera
    self.Blur   = blur

    UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    self.Character, self.Head = waitForCharacterHead()
    self.LastPitchSendTime    = 0
    hideHeadAndAccessories(self.Character)

    local hrp      = self.Character:WaitForChild("HumanoidRootPart")
    local humanoid = self.Character:WaitForChild("Humanoid")
    humanoid.AutoRotate = false

    -- Start camera facing the same direction the character already faces
    local _, ry, _ = hrp.CFrame:ToEulerAnglesYXZ()
    self.CameraYaw   = ry
    self.CameraPitch = 0

    self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
        if not (self.Head and self.Head.Parent) then return end

        -- Accumulate mouse delta into yaw/pitch
        local delta = UserInputService:GetMouseDelta()
        self.CameraYaw   = self.CameraYaw - math.rad(delta.X * MOUSE_SENSITIVITY)
        self.CameraPitch = math.clamp(
            self.CameraPitch - math.rad(delta.Y * MOUSE_SENSITIVITY),
            -PITCH_LIMIT, PITCH_LIMIT
        )

        -- Apply camera CFrame
        self.Camera.CFrame = CFrame.new(self.Head.Position)
            * CFrame.fromEulerAnglesYXZ(self.CameraPitch, self.CameraYaw, 0)

        -- Motion blur — scale with mouse speed, fade when idle
        local blurTarget = math.min(delta.Magnitude * BLUR_SCALE, BLUR_MAX)
        self.Blur.Size   = self.Blur.Size + (blurTarget - self.Blur.Size) * math.clamp(dt * BLUR_FADE_SPEED, 0, 1)

        -- CoD-style body rotation — run first so relativeYaw is ready to replicate
        local relativeYaw = 0
        local rootPart = self.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local _, charYaw, _ = rootPart.CFrame:ToEulerAnglesYXZ()
            relativeYaw = normalizeAngle(self.CameraYaw - charYaw)

            local newCharYaw = charYaw
            if relativeYaw > BODY_ROTATE_THRESHOLD then
                newCharYaw = self.CameraYaw - BODY_ROTATE_THRESHOLD
            elseif relativeYaw < -BODY_ROTATE_THRESHOLD then
                newCharYaw = self.CameraYaw + BODY_ROTATE_THRESHOLD
            end

            if newCharYaw ~= charYaw then
                rootPart.CFrame = CFrame.new(rootPart.Position)
                    * CFrame.fromEulerAnglesYXZ(0, newCharYaw, 0)
            end
        end

        -- Throttled look replication to server (15 Hz) — pitch + relative yaw
        local now = tick()
        if now - self.LastPitchSendTime >= SEND_RATE then
            PitchRemote:FireServer(self.CameraPitch, relativeYaw)
            self.LastPitchSendTime = now
        end
    end)

    -- Re-attach everything on respawn
    LocalPlayer.CharacterAdded:Connect(function(character)
        self.Character = character
        self.Head      = character:WaitForChild("Head")
        self.Camera.CameraType         = Enum.CameraType.Scriptable
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

        hideHeadAndAccessories(character)

        local newHrp      = character:WaitForChild("HumanoidRootPart")
        local newHumanoid = character:WaitForChild("Humanoid")
        newHumanoid.AutoRotate = false

        local _, ry2, _ = newHrp.CFrame:ToEulerAnglesYXZ()
        self.CameraYaw        = ry2
        self.CameraPitch      = 0
        self.LastPitchSendTime = 0
        PitchRemote:FireServer(0, 0)
    end)

    return self
end

--Handle Aim in here.
function CameraHandler:AimIn()

end

--Handle Aiming out of the gun (Back to hipfire i would assume.)
function CameraHandler:AimOut()

end

return CameraHandler
