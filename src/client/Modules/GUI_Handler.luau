local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService") 
local ScreenGui = Players.LocalPlayer.PlayerGui

-------------------Setup
local Gui = {}
Gui.__index = Gui

local FrameworkGUI = Instance.new("ScreenGui", ScreenGui)
FrameworkGUI.Name  = "[IRNV_FPS] V1 (GUI)"
FrameworkGUI.IgnoreGuiInset = true

-------------------Ammo Gui
function Gui:SetupAmmo()
    local AmmoFrame = Instance.new("Frame", FrameworkGUI)
    AmmoFrame.Name  = "Ammo_Frame"

    AmmoFrame.Size                   = UDim2.new(0, 150, 0, 60)
    AmmoFrame.Position               = UDim2.new(1,0,1,0)
    AmmoFrame.AnchorPoint            = Vector2.new(1,1)
    AmmoFrame.BackgroundColor3       = Color3.new(0,0,0)
    AmmoFrame.BackgroundTransparency = 0.35
    AmmoFrame.Visible                = false

    local WeaponLabel                  = Instance.new("TextLabel", AmmoFrame)
    WeaponLabel.BackgroundTransparency = 1
    WeaponLabel.Size                   = UDim2.new(.95,0,0,18)
    WeaponLabel.Position               = UDim2.new(0.05,0,0,5)
    WeaponLabel.Text                   = "WeaponLabel"
    WeaponLabel.TextColor3             = Color3.new(255,255,255)
    WeaponLabel.TextStrokeTransparency = 0
    WeaponLabel.Font                   = Enum.Font.Oswald
    WeaponLabel.TextXAlignment         = Enum.TextXAlignment.Left
    WeaponLabel.TextSize               = 18
    WeaponLabel.Name                   = "WeaponLabel"
    
    local AmmoLabel                    = Instance.fromExisting(WeaponLabel)
    AmmoLabel.Parent                   = AmmoFrame
    AmmoLabel.Name                     = "Ammo_Label"
    AmmoLabel.AnchorPoint              = Vector2.new(.5,0)
    AmmoLabel.Position                 = UDim2.new(.5,0,0,25)
    AmmoLabel.Size                     = UDim2.new(1, 0,0,25)
    AmmoLabel.TextSize                 = 25
    AmmoLabel.TextXAlignment           = Enum.TextXAlignment.Center
    AmmoLabel.Text                     = "30/60"

    local AmmoBar_BG                   = Instance.new("Frame", AmmoFrame)
    AmmoBar_BG.Size                    = UDim2.new(1,0,0,2)
    AmmoBar_BG.AnchorPoint             = Vector2.new(0,.5)
    AmmoBar_BG.Position                = UDim2.new(0, 0, 0, 57)
    AmmoBar_BG.BackgroundColor3        = Color3.fromRGB(45,45,45)
    AmmoBar_BG.Name                    = "AmmoBar_BG"
    
    local AmmoBar                      = Instance.fromExisting(AmmoBar_BG)
    AmmoBar.Parent                     = AmmoFrame
    AmmoBar.BackgroundColor3           = Color3.new(1,1,1)
    AmmoBar.Name                       = "AmmoBar"

    return AmmoFrame, WeaponLabel, AmmoBar
end

--Initialisation.
function Gui.Init()
    local self = setmetatable({}, Gui)
    local AmmoFrame, WeaponLabel, AmmoBar = Gui:SetupAmmo()

    self.AMMO_GUI = {
        AmmoFrame   = AmmoFrame,
        WeaponLabel = WeaponLabel,
        AmmoBar     = AmmoBar
    }

    return self
end



return Gui