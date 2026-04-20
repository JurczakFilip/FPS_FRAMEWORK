local AnimationPlayer = {}

function AnimationPlayer.SetCharacter(PT, character)
    PT.Animator = character:WaitForChild("Humanoid"):WaitForChild("Animator")
    PT.AnimationTrack = nil
end

function AnimationPlayer.Play(PT, animType: string)
    if PT.AnimationTrack then
        PT.AnimationTrack:Stop()
        PT.AnimationTrack = nil
    end

    local animId = PT.WeaponConfig.Animations.World[animType]
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    PT.AnimationTrack = PT.Animator:LoadAnimation(anim)
    anim:Destroy()
    PT.AnimationTrack:Play()
end

function AnimationPlayer.Stop(PT)
    if PT.AnimationTrack then
        PT.AnimationTrack:Stop()
        PT.AnimationTrack = nil
    end
end

return AnimationPlayer
