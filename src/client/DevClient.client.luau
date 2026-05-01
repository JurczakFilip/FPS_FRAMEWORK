local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Iris = require(ReplicatedStorage:WaitForChild("Iris")).Init()

local IRNVRep            = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local WeaponConfigFolder = IRNVRep:WaitForChild("WeaponConfig")
local SwitchWeapon       = IRNVRep:WaitForChild("Remotes"):WaitForChild("SwitchWeapon")

Iris:Connect(function()
    Iris.Window({"[IRNV] Weapon Switcher"})
        for _, cfg in ipairs(WeaponConfigFolder:GetChildren()) do
            if cfg:IsA("ModuleScript") then
                if Iris.Button({cfg.Name}).clicked() then
                    SwitchWeapon:FireServer(cfg.Name)
                end
            end
        end
    Iris.End()
end)