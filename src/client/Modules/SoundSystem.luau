local Debris           = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local SoundSystem = {}
SoundSystem.__index = SoundSystem

function SoundSystem.Init(soundFolder: Folder, camera: Camera, weaponEffects: Folder)
    local self = setmetatable({}, SoundSystem)
    self._soundFolder = soundFolder
    self._camera      = camera
    self._templates   = {}

    local soundFx     = weaponEffects:WaitForChild("Sound", 5)
    self._whizFolder  = soundFx and soundFx:WaitForChild("Whiz", 5)
    if not self._whizFolder then
        warn("[IRNV] WeaponEffects.Sound.Whiz folder missing — whiz sounds disabled")
    end

    self:_preloadGlobal()
    return self
end

function SoundSystem:_preloadGlobal()
    local function add(key, id)
        if not id or id == 0 then return end
        local sound = Instance.new("Sound")
        sound.Name    = key
        sound.SoundId = "rbxassetid://" .. id
        sound.Parent  = self._soundFolder
        self._templates[key] = sound
    end
    add("Global_FireModeSwitch", GlobalConfig.Sounds.FIRE_MODE_SWITCH)
    add("Global_EmptyMag",       GlobalConfig.Sounds.EMPTY_MAG)
end

function SoundSystem:PreloadWeapon(cfg)
    for key, sound in pairs(self._templates) do
        if not key:match("^Global_") then
            sound:Destroy()
            self._templates[key] = nil
        end
    end
    for soundType, soundId in pairs(cfg.Effects.Sound) do
        if soundId and soundId ~= 0 then
            local sound = Instance.new("Sound")
            sound.Name    = soundType
            sound.SoundId = "rbxassetid://" .. soundId
            sound.Parent  = self._soundFolder
            self._templates[soundType] = sound
        end
    end
end

function SoundSystem:Play(key: string)
    local template = self._templates[key]
    if not template then return end
    local sound = template:Clone()
    sound.Parent = self._camera
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
end

function SoundSystem:Play3DAt(pos: Vector3, soundId: number?)
    if not soundId or soundId == 0 then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    self:_emitSpatial(pos, sound)
end

function SoundSystem:_emitSpatial(pos: Vector3, sound: Sound)
    local part = Instance.new("Part")
    part.Anchored     = true
    part.CanCollide   = false
    part.CanQuery     = false
    part.CanTouch     = false
    part.Transparency = 1
    part.Size         = Vector3.new(0.1, 0.1, 0.1)
    part.CFrame       = CFrame.new(pos)
    part.Parent       = workspace
    sound.Parent = part
    sound:Play()
    sound.Ended:Once(function() part:Destroy() end)
    Debris:AddItem(part, GlobalConfig.SoundSystem.SPATIAL_DEBRIS_LIFETIME)
end

function SoundSystem:AttachWhiz(host: BasePart, category: string?)
    if not category or not self._whizFolder then return end
    local pool = self._whizFolder:FindFirstChild(category)
    if not pool then return end
    local candidates = {}
    for _, child in ipairs(pool:GetChildren()) do
        if child:IsA("Sound") then table.insert(candidates, child) end
    end
    if #candidates == 0 then return end
    local sound = candidates[math.random(1, #candidates)]:Clone()
    sound.Parent = host
    sound:Play()
end

return SoundSystem
