local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IRNVRep      = ReplicatedStorage:WaitForChild("[IRNV_FPS] V1 (REP)")
local GlobalConfig = require(IRNVRep:WaitForChild("GlobalConfig"))

local TracersFolder  = IRNVRep:WaitForChild("WeaponEffects"):WaitForChild("Visual"):WaitForChild("Tracers")
local BULLET_GRAVITY = Vector3.new(0, -workspace.Gravity, 0)
local TRACER_STEP    = GlobalConfig.BulletVisual.TRACER_STEP
local LocalPlayer    = Players.LocalPlayer

local BulletVisual = {}

function BulletVisual.Init(soundSystem)
    local self = {}

    function self.Run(
        origin:      Vector3,
        direction:   Vector3,
        speed:       number,
        filterList:  {Instance},
        whizCategory: string?,
        visualName:  string?,
        maxRange:    number?
    )
        maxRange = maxRange or GlobalConfig.BulletVisual.DEFAULT_RANGE

        local waypoints = { origin }
        local times     = { 0 }
        local pos  = origin
        local vel  = direction.Unit * speed
        local traveled = 0
        local t    = 0

        local params = RaycastParams.new()
        params.FilterDescendantsInstances = filterList
        params.FilterType = Enum.RaycastFilterType.Exclude

        for _ = 1, GlobalConfig.BulletVisual.MAX_STEPS do
            local newVel = vel + BULLET_GRAVITY * TRACER_STEP
            local newPos = pos + vel * TRACER_STEP
            t = t + TRACER_STEP
            local result = workspace:Raycast(pos, newPos - pos, params)
            if result then
                table.insert(waypoints, result.Position)
                table.insert(times, t)
                break
            end
            traveled = traveled + (newPos - pos).Magnitude
            pos = newPos
            vel = newVel
            table.insert(waypoints, pos)
            table.insert(times, t)
            if traveled >= maxRange then break end
        end

        if #waypoints < 2 then return end

        -- Whiz gating: only fire for bullets that pass near the local player
        local localChar = LocalPlayer.Character
        local isOwnBullet = false
        for _, inst in ipairs(filterList) do
            if inst == localChar then isOwnBullet = true break end
        end
        local shouldWhiz = false
        if whizCategory and localChar and (not isOwnBullet or GlobalConfig.Debug) then
            local hrp = localChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                local P = hrp.Position
                for i = 1, #waypoints - 1 do
                    local A  = waypoints[i]
                    local B  = waypoints[i + 1]
                    local AB = B - A
                    local len2 = AB:Dot(AB)
                    local s  = len2 > 0 and math.clamp((P - A):Dot(AB) / len2, 0, 1) or 0
                    if (P - A:Lerp(B, s)).Magnitude <= GlobalConfig.Whiz.DISTANCE then
                        shouldWhiz = true
                        break
                    end
                end
            end
        end

        local tracerModel = visualName and TracersFolder:FindFirstChild(visualName)
        if not tracerModel and not shouldWhiz then return end

        local totalTime = times[#times]

        local bullet, isModel
        if tracerModel then
            bullet  = tracerModel:Clone()
            isModel = bullet:IsA("Model")
        else
            bullet = Instance.new("Part")
            bullet.Anchored     = true
            bullet.CanCollide   = false
            bullet.CanQuery     = false
            bullet.CanTouch     = false
            bullet.Transparency = 1
            bullet.Size         = Vector3.new(0.1, 0.1, 0.1)
            isModel = false
        end

        local function setCF(cf)
            if isModel then bullet:PivotTo(cf) else bullet.CFrame = cf end
        end

        setCF(CFrame.lookAt(waypoints[1], waypoints[2]))
        bullet.Parent = workspace

        if shouldWhiz then
            local host = isModel
                and (bullet.PrimaryPart or bullet:FindFirstChildWhichIsA("BasePart"))
                or bullet
            if host then soundSystem:AttachWhiz(host, whizCategory) end
        end

        local startTime  = tick()
        local lastSegIdx = 1
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - startTime
            if elapsed >= totalTime then
                conn:Disconnect()
                if bullet.Parent then bullet:Destroy() end
                return
            end

            while lastSegIdx < #times - 1 and times[lastSegIdx + 1] <= elapsed do
                lastSegIdx += 1
            end

            local segA = waypoints[lastSegIdx]
            local segB = waypoints[math.min(lastSegIdx + 1, #waypoints)]
            local tA   = times[lastSegIdx]
            local tB   = times[math.min(lastSegIdx + 1, #times)]
            local segT = (tB > tA) and (elapsed - tA) / (tB - tA) or 0

            local interpPos = segA:Lerp(segB, math.clamp(segT, 0, 1))
            local lookDir   = segB - segA
            if lookDir.Magnitude > 0.001 then
                setCF(CFrame.lookAt(interpPos, interpPos + lookDir))
            end
        end)

        task.delay(totalTime + GlobalConfig.BulletVisual.CLEANUP_DELAY, function()
            conn:Disconnect()
            if bullet.Parent then bullet:Destroy() end
        end)
    end

    return self
end

return BulletVisual
