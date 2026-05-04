local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local function dbg(msg)
    if GlobalConfig.Debug then print("[IRNV_DEBUG]: " .. msg) end
end

local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

function AnimationPlayer.new(animFolder: Folder)
    return setmetatable({
        _animFolder = animFolder,
        _animator   = nil,
        _tracks     = {},
        _track      = nil,
        _chainToken = 0,
        _chainConn  = nil,
    }, AnimationPlayer)
end

function AnimationPlayer:Preload(viewmodel, weaponConfig)
    self._animator = viewmodel.Humanoid.Animator
    self._tracks   = {}
    self._track    = nil
    self._animFolder:ClearAllChildren()
    for animType, animId in pairs(weaponConfig.Animations.FPS) do
        if animId and animId ~= 0 then
            local anim = Instance.new("Animation")
            anim.Name        = animType
            anim.AnimationId = "rbxassetid://" .. animId
            anim.Parent      = self._animFolder
            self._tracks[animType] = self._animator:LoadAnimation(anim)
        end
    end
end

function AnimationPlayer:Play(animType: string)
    local track = self._tracks[animType]
    if not track then
        dbg("AnimationPlayer: no preloaded track for '" .. animType .. "'")
        return
    end
    self._chainToken += 1
    if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
    if self._track and self._track ~= track then self._track:Stop() end
    track:Stop()
    self._track = track
    track:Play()
    dbg("AnimationPlayer: playing '" .. animType .. "'")
end

function AnimationPlayer:PlayThen(animType: string, nextAnimType: string)
    self:Play(animType)
    local track = self._track
    if not track then return end
    track.Looped = false
    self._chainToken += 1
    local token = self._chainToken
    self._chainConn = track.Stopped:Connect(function()
        if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
        if self._chainToken == token then
            self:Play(nextAnimType)
        end
    end)
end

function AnimationPlayer:PlayChain(animTypes: {string})
    if #animTypes == 0 then return end
    self:Play(animTypes[1])
    if #animTypes == 1 then return end
    local track = self._track
    if not track then return end
    track.Looped = false
    self._chainToken += 1
    local token = self._chainToken
    local rest = {}
    for i = 2, #animTypes do rest[i - 1] = animTypes[i] end
    self._chainConn = track.Stopped:Connect(function()
        if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
        if self._chainToken == token then
            self:PlayChain(rest)
        end
    end)
end

function AnimationPlayer:Stop()
    self._chainToken += 1
    if self._chainConn then self._chainConn:Disconnect() self._chainConn = nil end
    if self._track then
        self._track:Stop()
        self._track = nil
    end
end

return AnimationPlayer
