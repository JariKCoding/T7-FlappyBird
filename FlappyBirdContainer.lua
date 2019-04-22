CoD.FlappyBirdContainer = InheritFrom(LUI.UIElement)

function CoD.FlappyBirdContainer.new(HudRef, InstanceRef)
    local Elem = LUI.UIElement.new()
    if PreLoadFunc then
        PreLoadFunc(HudRef, InstanceRef)
    end

    Elem:setClass(CoD.FlappyBirdContainer)
    Elem.id = "FlappyBirdContainer"
    Elem.soundSet = "HUD"
    Elem.anyChildUsesUpdateState = true

    -- Make sure we initialise the highscores
    local rightID = Engine.GetBubbleGumBuff(InstanceRef, 1, 1)
    if rightID ~= 69 then
        Engine.SetBubbleGumBuff(InstanceRef, 1, 1, 69)
        Engine.SetBubbleGumBuff(InstanceRef, 1, 2, 0)
        Engine.SetBubbleGumBuff(InstanceRef, 1, 3, 0)
        Engine.StorageWrite(InstanceRef, Enum.StorageFileType.STORAGE_ZM_LOADOUTS_OFFLINE)
    end

    local backgroundImage = LUI.UIImage.new()
    backgroundImage:setLeftRight(true, true, 0.000000, 0.000000)
    backgroundImage:setTopBottom(true, true, 0.000000, 0.000000)
    backgroundImage:setImage(RegisterImage("flappybird_background"))
    Elem:addElement(backgroundImage)

    local foregroundImage = LUI.UIImage.new()
    foregroundImage:setLeftRight(true, true, 0.000000, 0.000000)
    foregroundImage:setTopBottom(true, true, 0.000000, 0.000000)
    foregroundImage:setPriority(LUI.UIMouseCursor.priority)
    foregroundImage:setImage(RegisterImage("flappybird_foreground"))
    Elem:addElement(foregroundImage)
    
    local birdImage = LUI.UIImage.new()
    birdImage:setLeftRight(true, false, 80, 150)
    birdImage:setTopBottom(false, false, -35, 35)
    birdImage:setPriority(LUI.UIMouseCursor.priority)
    birdImage:setImage(RegisterImage("flappybird_bird"))
    Elem:addElement(birdImage)

    local scoreLabel = LUI.UIText.new(Elem, Instance)
    scoreLabel:setLeftRight(true, false, 50, 100)
    scoreLabel:setTopBottom(true, false, 30, 80)
    scoreLabel:setPriority(LUI.UIMouseCursor.priority)
    scoreLabel:setText("Score: 0")
    Elem:addElement(scoreLabel)

    local highscoreLabel = LUI.UIText.new(Elem, Instance)
    highscoreLabel:setLeftRight(false, true, -100, -50)
    highscoreLabel:setTopBottom(true, false, 30, 80)
    highscoreLabel:setPriority(LUI.UIMouseCursor.priority)
    Elem:addElement(highscoreLabel)

    local gameOverImage = LUI.UIImage.new()
    gameOverImage:setLeftRight(false, false, -200, 200)
    gameOverImage:setTopBottom(false, false, -50, 50)
    gameOverImage:setPriority(LUI.UIMouseCursor.priority)
    gameOverImage:setAlpha(0)
    gameOverImage:setImage(RegisterImage("flappybird_gameover"))
    Elem:addElement(gameOverImage)

    local pipeWidth = 70
    local pipeGap = 200
    local pipes = {}
    local pipeAddCount = 0
    local pipeAddTiming = 60

    local gameActive = false
    local hitPipe = false

    local score = 0

    local birdGravity = 1
    local birdJump = 20
    local birdVelocity = 0
    local birdY = -35
    local birdSize = 70

    -- Why the fuck did i add support for highscores until 65536
    local function getHighscore()
        return (Engine.GetBubbleGumBuff(InstanceRef, 1, 2) * 256) + Engine.GetBubbleGumBuff(InstanceRef, 1, 3)
    end

    local function setHighscore(score)
        Engine.SetBubbleGumBuff(InstanceRef, 1, 2, (score - (score % 256)) / 256)
        Engine.SetBubbleGumBuff(InstanceRef, 1, 3, score % 256)
        Engine.StorageWrite(InstanceRef, Enum.StorageFileType.STORAGE_ZM_LOADOUTS_OFFLINE)
    end
    
    highscoreLabel:setText("Highscore: " .. getHighscore())

    local function makeNewPipe(height)
        local pipeTopImage = LUI.UIImage.new()
        pipeTopImage:setLeftRight(false, true, 0, 70)
        pipeTopImage:setTopBottom(false, false, -360, height)
        pipeTopImage:setZRot(180)
        pipeTopImage:setImage(RegisterImage("flappybird_pipe"))
        Elem:addElement(pipeTopImage)

        local pipeBottomImage = LUI.UIImage.new()
        pipeBottomImage:setLeftRight(false, true, 0, 70)
        pipeBottomImage:setTopBottom(false, false, height + pipeGap, 360)
        pipeBottomImage:setImage(RegisterImage("flappybird_pipe"))
        Elem:addElement(pipeBottomImage)
        table.insert( pipes, {
            bottomElement = pipeBottomImage,
            topElement = pipeTopImage,
            x = -10,
            y = height
        } )
    end

    local function deletePipe(pipe)
        pipe.bottomElement:close()
        pipe.topElement:close()
        pipe = nil
    end

    local function restartGame()
        gameOverImage:setAlpha(0)
        for k, v in pairs(pipes) do
            if v.deleted == nil then
                deletePipe(v)
            end
        end
        birdY = -35
        birdVelocity = 0
        birdGravity = 1
        birdJump = 20
        pipes = {}
        hitPipe = false
        score = 0
        pipeAddCount = 0
        makeNewPipe(-100)
    end

    local function isBirdTouchingPipe(pipe)
        if pipe.x < -1130 and pipe.x + pipeWidth > -1210 then
            if pipe.y > birdY or pipe.y + pipeGap < birdY + birdSize then
                return true
            end
        end
        return false
    end

    local function update(HudObj, EventObj)
        -- Make sure a new frame starts after this one
        if gameActive == true then
            backgroundImage:beginAnimation("keyframe", 30, false, false, CoD.TweenType.Linear)
        else
            return
        end
        
        -- Stuff for moving the pipes
        if hitPipe == false then
            for k, v in ipairs(pipes) do
                if v.deleted == nil then
                    v.x = v.x - 4
                    v.bottomElement:setLeftRight(false, true, v.x, v.x + pipeWidth)
                    v.topElement:setLeftRight(false, true, v.x, v.x + pipeWidth)
                    if isBirdTouchingPipe(v) then
                        -- Hit pipe, starting again
                        local function playDeathSoundDelay()
                            Engine.PlaySound("uin_flappybird_die")
                        end
                        HudRef:addElement(LUI.UITimer.newElementTimer(300, true, playDeathSoundDelay))
                        Engine.PlaySound("uin_flappybird_hit")
                        hitPipe = true
                        break
                    end
                    if v.x < -1280 - pipeWidth then
                        v.deleted = true
                        deletePipe(v)
                        Engine.PlaySound("uin_flappybird_point")
                        score = score + 1
                    end
                end
            end
        end

        -- Checking for the next pipe
        pipeAddCount = pipeAddCount + 1
        if pipeAddCount == pipeAddTiming then
            pipeAddCount = 0
            makeNewPipe(math.random(-300, 80))
        end

        -- Stuff for moving the bird
        birdVelocity = birdVelocity + birdGravity
        birdY = birdY + birdVelocity
        if birdY < -360 then
            birdY = -360
            birdVelocity = 0
        end
        if birdY > 210 then
            -- Hit ground, starting again
            if hitPipe == false then
                Engine.PlaySound("uin_flappybird_hit")
            end
            if score > getHighscore() then
                setHighscore(score)
                highscoreLabel:setText("Highscore: " .. score)
            end
            gameOverImage:setAlpha(1)
            gameActive = false
            return
        end
        local function clamp(x, min, max)
            if x < min then
                return min
            end
            if x > max then
                return max
            end
            return x
        end
        -- Give the bird the right rotation and height
        birdImage:setZRot(clamp(birdVelocity * -4, -85, 85))
        birdImage:setTopBottom(false, false, birdY, birdY + birdSize)

        scoreLabel:setText("Score: " .. score)
    end

    -- Add the first pipe
    makeNewPipe(-100)
    
    -- Start the frames
    backgroundImage:registerEventHandler("transition_complete_keyframe", update)

    -- Event handler for the flying
    local function playerFlyKeyPressed(arg0, arg1, arg2, arg3)
        if gameActive == true and hitPipe == false then
            Engine.PlaySound("uin_flappybird_wing")
            birdVelocity = birdVelocity - birdJump
        elseif gameActive == false then
            restartGame()
            gameActive = true
            backgroundImage:beginAnimation("keyframe", 30, false, false, CoD.TweenType.Linear)
        end
        return true
    end
    HudRef:AddButtonCallbackFunction(HudRef, InstanceRef, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, nil, playerFlyKeyPressed)

    if PostLoadFunc then
        PostLoadFunc(HudRef, InstanceRef)
    end
    
    return Elem
end