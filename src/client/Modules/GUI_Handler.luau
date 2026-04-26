local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ScreenGui = Players.LocalPlayer.PlayerGui

local BAR_TWEEN_INFO    = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RELOAD_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
    
    local FireModeLabel                = Instance.fromExisting(WeaponLabel)
    FireModeLabel.Parent               = AmmoFrame
    FireModeLabel.Name                 = "FireMode_Label"
    FireModeLabel.AnchorPoint          = Vector2.new(1,0)
    FireModeLabel.Position             = UDim2.new(0.95,0,0,5)
    FireModeLabel.Size                 = UDim2.new(0.4, 0,0, 18)
    FireModeLabel.TextXAlignment       = Enum.TextXAlignment.Right
    FireModeLabel.Text                 = "Semi" -- Semi, Auto, Burst

    local AmmoLabel                    = Instance.fromExisting(WeaponLabel)
    AmmoLabel.Parent                   = AmmoFrame
    AmmoLabel.Name                     = "Ammo_Label"
    AmmoLabel.AnchorPoint              = Vector2.new(.5,0)
    AmmoLabel.Position                 = UDim2.new(.5,0,0,20)
    AmmoLabel.Size                     = UDim2.new(1, 0,0,30)
    AmmoLabel.TextSize                 = 30
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

    return AmmoFrame, WeaponLabel, AmmoBar, AmmoLabel, FireModeLabel
end

function Gui:_tweenBar(current: number, maxMag: number)
    local fill = (maxMag > 0) and math.clamp(current / maxMag, 0, 1) or 0
    if self._barTween then self._barTween:Cancel() end
    self._barTween = TweenService:Create(
        self.AMMO_GUI.AmmoBar,
        BAR_TWEEN_INFO,
        { Size = UDim2.new(fill, 0, 0, 2) }
    )
    self._barTween:Play()
end

function Gui:_cancelTextTween()
    if self._textTween then self._textTween:Cancel() self._textTween = nil end
    if self._textConn  then self._textConn:Disconnect() self._textConn = nil end
    if self._textProxy then self._textProxy:Destroy() self._textProxy = nil end
end

function Gui:UpdateAmmo(current: number, reserve: number, maxMag: number)
    self:_cancelTextTween()
    self.AMMO_GUI.AmmoLabel.Text = string.format("%d / %d", current, reserve)
    self:_tweenBar(current, maxMag)
    self._lastCurrent = current
    self._lastReserve = reserve
end

function Gui:TweenReload(current: number, reserve: number, maxMag: number)
    local fromCurrent = self._lastCurrent or 0
    local fromReserve = self._lastReserve or 0

    self:_cancelTextTween()
    self:_tweenBar(current, maxMag)

    local proxy = Instance.new("NumberValue")
    proxy.Value = 0
    self._textProxy = proxy

    local label = self.AMMO_GUI.AmmoLabel
    self._textConn = proxy:GetPropertyChangedSignal("Value"):Connect(function()
        local a   = proxy.Value
        local cur = math.floor(fromCurrent + (current - fromCurrent) * a + 0.5)
        local res = math.floor(fromReserve + (reserve - fromReserve) * a + 0.5)
        label.Text = string.format("%d / %d", cur, res)
    end)

    local tween = TweenService:Create(proxy, RELOAD_TWEEN_INFO, { Value = 1 })
    self._textTween = tween
    tween.Completed:Connect(function()
        if self._textProxy == proxy then
            self:_cancelTextTween()
            label.Text = string.format("%d / %d", current, reserve)
        end
    end)
    tween:Play()

    self._lastCurrent = current
    self._lastReserve = reserve
end

function Gui:SetFireMode(mode: string)
    self.AMMO_GUI.FireModeLabel.Text = mode
end

--Initialisation.
function Gui.Init()
    local self = setmetatable({}, Gui)
    local AmmoFrame, WeaponLabel, AmmoBar, AmmoLabel, FireModeLabel = Gui:SetupAmmo()

    self.AMMO_GUI = {
        AmmoFrame     = AmmoFrame,
        WeaponLabel   = WeaponLabel,
        AmmoBar       = AmmoBar,
        AmmoLabel     = AmmoLabel,
        FireModeLabel = FireModeLabel,
    }

    return self
end



return Gui