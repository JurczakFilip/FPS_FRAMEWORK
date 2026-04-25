local AnimationPlayer = {}

function AnimationPlayer.SetCharacter(PT, character)
    PT.Animator       = character:WaitForChild("Humanoid"):WaitForChild("Animator")
    PT.AnimationTrack = nil
    PT.AnimChainToken = 0
end

function AnimationPlayer.Play(PT, animType: string)
    if not PT.Animator or not PT.WeaponConfig then return end
    local animId = PT.WeaponConfig.Animations.World[animType]
    if not animId or animId == 0 then return end

    PT.AnimChainToken = (PT.AnimChainToken or 0) + 1

    if PT.AnimationTrack then
        PT.AnimationTrack:Stop()
        PT.AnimationTrack = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    PT.AnimationTrack = PT.Animator:LoadAnimation(anim)
    anim:Destroy()
    PT.AnimationTrack:Play()
end

-- Plays animType then chains nextAnimType when it finishes naturally.
-- Any subsequent Play or PlayThen cancels the pending chain.
function AnimationPlayer.PlayThen(PT, animType: string, nextAnimType: string)
    AnimationPlayer.Play(PT, animType)
    local track = PT.AnimationTrack
    if not track then return end
    track.Looped = false
    PT.AnimChainToken = (PT.AnimChainToken or 0) + 1
    local token = PT.AnimChainToken
    track.Stopped:Once(function()
        if PT.AnimChainToken == token then
            AnimationPlayer.Play(PT, nextAnimType)
        end
    end)
end

function AnimationPlayer.Stop(PT)
    PT.AnimChainToken = (PT.AnimChainToken or 0) + 1
    if PT.AnimationTrack then
        PT.AnimationTrack:Stop()
        PT.AnimationTrack = nil
    end
end

return AnimationPlayer
