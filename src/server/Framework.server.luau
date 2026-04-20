local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = script.Parent:WaitForChild("Modules")
local Players = game:GetService("Players")

-- Load Modules
require(Modules:WaitForChild("CameraHandler")).Setup()
local Test_Inventory = require(Modules:WaitForChild("Inventory"))
local AnimationPlayer = require(Modules:WaitForChild("AnimationPlayer"))

-- Main Code

local Framework = {
    Test_Inventory = Test_Inventory,
    
    -- PT is a player tracker, basically i want to track clientside Framework via a server side tracker.
    PT = {}
}

local PT = {}
PT.__index = PT -- Player Tracker, Track States and more

function PT.Add(Player)
    local self = setmetatable({}, PT)
    self.Player = Player
    self.Inventory = Framework.Test_Inventory
    self.CurrentWeapon = nil
    self.WeaponConfig = nil
    self.WeaponModel  = nil
    self.Animator = nil
    self.AnimationTrack = nil

    table.insert(Framework.PT, self)
    return self
end

function LoadSlot(PT)
-- Clear Previous Slot
    AnimationPlayer.Stop(PT)
    if PT.WeaponModel then
        PT.WeaponModel:Destroy()
        PT.WeaponModel = nil
    elseif PT.WeaponConfig then
        PT.WeaponConfig = nil
    end

    local WeaponModel_Folder  = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponModels")
    local WeaponConfig_Folder = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("WeaponConfig")

    if WeaponModel_Folder:FindFirstChild(PT.CurrentWeapon.WeaponName) then
        PT.WeaponModel = WeaponModel_Folder:FindFirstChild(PT.CurrentWeapon.WeaponName):Clone()
        PT.WeaponModel.Name = "[SERVER]_"..PT.CurrentWeapon.WeaponName
    else
        print("[SERVER] COULDNT LOCATE WEAPON MODEL")
    end

    if WeaponConfig_Folder:FindFirstChild(PT.CurrentWeapon.WeaponName) then
        PT.WeaponConfig = require(WeaponConfig_Folder:FindFirstChild(PT.CurrentWeapon.WeaponName))
    else
        print("[SERVER] COULDNT LOCATE WEAPON CONFIG")
    end

    local GripMotor6D = Instance.new("Motor6D")
    GripMotor6D.Name = "[WORLD] GripMotor6D"

    PT.WeaponModel.PrimaryPart.Anchored = false

    local Character = PT.Player.Character

    GripMotor6D.Part0  = Character.RightHand
    GripMotor6D.Part1  = PT.WeaponModel.PrimaryPart
    GripMotor6D.C0     = PT.WeaponConfig.WorldGripOffset.C0
    GripMotor6D.C1     = PT.WeaponConfig.WorldGripOffset.C1
    GripMotor6D.Parent = Character.RightHand

    PT.WeaponModel.Parent = Character.RightHand

    AnimationPlayer.SetCharacter(PT, Character)
    AnimationPlayer.Play(PT, "Idle")
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local Tracked_PT = PT.Add(player)
        Tracked_PT.CurrentWeapon = Tracked_PT.Inventory[1]
        LoadSlot(Tracked_PT)
        ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadInventory"):FireClient(player, Framework.Test_Inventory)
        ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)"):WaitForChild("Remotes"):WaitForChild("LoadWeapon"):FireClient(player, Tracked_PT.CurrentWeapon)
    
        print("Framework.PT: ", Framework.PT)
    end)
end)