-- FlappyTurtle for WoW 1.12 (Turtle WoW)
-- Debug: Print start of load
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFFlappyTurtle: Attempting to load...|r")

-- --- Lua 5.0 Optimizations & Compatibility --- --
local tinsert = table.insert
local tremove = table.remove
-- Robust getn check: use table.getn if exists, else global getn
local tgetn = table.getn or getn 
local mrandom = math.random
local mfloor = math.floor

-- Configuration
local WIDTH = 400
local HEIGHT = 300
local BIRD_SIZE = 24
local PIPE_WIDTH = 45 
local CAP_HEIGHT = 22 
local CAP_OVERHANG = 6 
local GRAVITY = -1500
local JUMP_FORCE = 350
local PIPE_SPEED = 140

-- Variation Config
local MIN_GAP = 100      -- Tightest gap
local MAX_GAP = 160      -- Widest gap
local MIN_SPAWN = 1.3    -- Quickest spawn (pipes closer)
local MAX_SPAWN = 2.3    -- Slowest spawn (pipes further)

-- State Variables
local running = false
local birdY = HEIGHT / 2
local birdVelocity = 0
local pipes = {} 
local pipeFrames = {} 
local timeSinceLastPipe = 0
local nextSpawnTime = 1.8 -- Time until next pipe
local score = 0
local gameover = false

-- Note: FlappyTurtleHighScore is saved in SavedVariables

-- --- Main Frame Setup --- --
local frame = CreateFrame("Frame", "FlappyTurtleFrame", UIParent)
frame:SetWidth(WIDTH + 40)
frame:SetHeight(HEIGHT + 40)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) 
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:SetFrameStrata("DIALOG") 
frame:Hide() 

-- --- Clipping Fix for 1.12 --- --
local gameArea = CreateFrame("ScrollFrame", "FlappyGameScroll", frame)
gameArea:SetWidth(WIDTH)
gameArea:SetHeight(HEIGHT)
gameArea:SetPoint("CENTER", 0, 0)

local gameContent = CreateFrame("Frame", "FlappyGameContent", gameArea)
gameContent:SetWidth(WIDTH)
gameContent:SetHeight(HEIGHT)
gameArea:SetScrollChild(gameContent)

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("Flappy Turtle")

-- Score Display
local scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
scoreText:SetPoint("TOP", 0, -40)
scoreText:SetText("0")

-- Instructions/Game Over Text
local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
infoText:SetPoint("CENTER", 0, 0)
infoText:SetText("Click to Start")

-- --- Bird Setup --- --
local bird = CreateFrame("Frame", nil, gameContent)
bird:SetWidth(BIRD_SIZE)
bird:SetHeight(BIRD_SIZE)
local birdTex = bird:CreateTexture(nil, "ARTWORK")
birdTex:SetAllPoints()
birdTex:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Turtle")
bird:SetPoint("BOTTOMLEFT", 50, HEIGHT / 2) 

-- --- Pipe Management --- --
local function GetPipeFrame(index)
    if not pipeFrames[index] then
        local p = CreateFrame("Frame", nil, gameContent)
        p:SetWidth(PIPE_WIDTH)
        
        -- Top Pipe Body
        p.topTube = p:CreateTexture(nil, "ARTWORK")
        p.topTube:SetTexture(0, 0.75, 0, 1) 
        
        -- Top Pipe Cap 
        p.topCap = p:CreateTexture(nil, "OVERLAY")
        p.topCap:SetTexture(0, 0.75, 0, 1) 
        
        -- Bottom Pipe Body
        p.bottomTube = p:CreateTexture(nil, "ARTWORK")
        p.bottomTube:SetTexture(0, 0.75, 0, 1)
        
        -- Bottom Pipe Cap 
        p.bottomCap = p:CreateTexture(nil, "OVERLAY")
        p.bottomCap:SetTexture(0, 0.75, 0, 1)
        
        pipeFrames[index] = p
    end
    return pipeFrames[index]
end

local function HideAllPipes()
    local count = tgetn(pipeFrames)
    for i=1, count do
        pipeFrames[i]:Hide()
    end
end

-- --- Game Logic Functions --- --

local function ResetGame()
    if not FlappyTurtleHighScore then FlappyTurtleHighScore = 0 end

    birdY = HEIGHT / 2
    birdVelocity = 0
    pipes = {}
    nextSpawnTime = 1.0 -- Force first pipe soon
    timeSinceLastPipe = 0 
    score = 0
    scoreText:SetText(score)
    gameover = false
    HideAllPipes()
    infoText:SetText("")
    
    bird:SetPoint("BOTTOMLEFT", 50, birdY)
end

local function GameOver()
    running = false
    gameover = true
    
    if not FlappyTurtleHighScore then FlappyTurtleHighScore = 0 end
    if score > FlappyTurtleHighScore then
        FlappyTurtleHighScore = score
    end
    
    infoText:SetText("Game Over!\nScore: " .. score .. "\nHigh Score: " .. FlappyTurtleHighScore .. "\n\nClick to Restart")
end

local function SpawnPipe()
    -- 1. Randomize Gap Size for this pipe
    local thisGap = mrandom(MIN_GAP, MAX_GAP)
    
    -- 2. Determine Gap Y Position
    local margin = 50 + (thisGap / 2)
    local maxVal = HEIGHT - margin
    if maxVal <= margin then maxVal = margin + 1 end
    
    local gapY = mrandom(margin, maxVal)
    
    -- Store GapSize in the pipe object
    tinsert(pipes, { x = WIDTH, gapY = gapY, gapSize = thisGap })
end

local function UpdateGame(elapsed)
    if not elapsed then return end
    if not running then return end

    -- 1. Physics
    birdVelocity = birdVelocity + (GRAVITY * elapsed)
    birdY = birdY + (birdVelocity * elapsed)

    if birdY < 0 or birdY > (HEIGHT - BIRD_SIZE) then
        GameOver()
        return
    end

    bird:SetPoint("BOTTOMLEFT", 50, birdY)

    -- 2. Pipe Spawning (Variable Rates)
    timeSinceLastPipe = timeSinceLastPipe + elapsed
    if timeSinceLastPipe > nextSpawnTime then
        SpawnPipe()
        timeSinceLastPipe = 0
        -- Randomize next spawn time (float math)
        nextSpawnTime = MIN_SPAWN + (mrandom() * (MAX_SPAWN - MIN_SPAWN))
    end

    -- 3. Pipe Movement & Collision
    local birdLeft = 50
    local birdRight = 50 + BIRD_SIZE
    local birdBottom = birdY
    local birdTop = birdY + BIRD_SIZE

    local i = 1
    local pipeCount = tgetn(pipes) 
    
    while i <= pipeCount do
        local p = pipes[i]
        p.x = p.x - (PIPE_SPEED * elapsed)

        if p.x < -PIPE_WIDTH - 10 then 
            tremove(pipes, i) 
            pipeCount = pipeCount - 1
            score = score + 1
            scoreText:SetText(score)
        else
            local pf = GetPipeFrame(i)
            pf:Show()
            pf:SetPoint("BOTTOMLEFT", p.x, 0)
            pf:SetHeight(HEIGHT)
            
            -- Use the specific gapSize for this pipe
            local gapTop = p.gapY + (p.gapSize / 2)
            local gapBottom = p.gapY - (p.gapSize / 2)
            
            -- --- RENDER PIPES (Mario Style) ---

            -- TOP PIPE
            pf.topTube:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 0)
            pf.topTube:SetPoint("BOTTOMRIGHT", pf, "TOPRIGHT", 0, -(HEIGHT - gapTop - CAP_HEIGHT))
            
            -- Cap
            pf.topCap:SetPoint("TOPLEFT", pf.topTube, "BOTTOMLEFT", -CAP_OVERHANG, 0)
            pf.topCap:SetPoint("BOTTOMRIGHT", pf.topTube, "BOTTOMRIGHT", CAP_OVERHANG, -CAP_HEIGHT)

            -- BOTTOM PIPE
            pf.bottomTube:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT", 0, 0)
            pf.bottomTube:SetPoint("TOPRIGHT", pf, "BOTTOMRIGHT", 0, gapBottom - CAP_HEIGHT)

            -- Cap
            pf.bottomCap:SetPoint("BOTTOMLEFT", pf.bottomTube, "TOPLEFT", -CAP_OVERHANG, 0)
            pf.bottomCap:SetPoint("TOPRIGHT", pf.bottomTube, "TOPRIGHT", CAP_OVERHANG, CAP_HEIGHT)

            -- --- COLLISION CHECK ---
            local pipeLeft = p.x
            local pipeRight = p.x + PIPE_WIDTH
            
            if birdRight > pipeLeft and birdLeft < pipeRight then
                if birdBottom < gapBottom or birdTop > gapTop then
                    GameOver()
                end
            end

            i = i + 1
        end
    end
    
    local totalFrames = tgetn(pipeFrames)
    for k = pipeCount + 1, totalFrames do
        pipeFrames[k]:Hide()
    end
end

-- --- Input Handling --- --
local function OnClick()
    if not running then
        if gameover then
            ResetGame()
            running = true
            birdVelocity = JUMP_FORCE
        else
            ResetGame()
            running = true
            birdVelocity = JUMP_FORCE
        end
    else
        birdVelocity = JUMP_FORCE
    end
end

local clickButton = CreateFrame("Button", nil, frame)
clickButton:SetAllPoints(frame)
clickButton:RegisterForClicks("LeftButtonDown")
clickButton:SetScript("OnClick", OnClick)

frame:SetScript("OnUpdate", function()
    if arg1 then UpdateGame(arg1) end
end)

SLASH_FLAPPY1 = "/flappy"
SlashCmdList["FLAPPY"] = function(msg)
    if FlappyTurtleFrame:IsVisible() then
        FlappyTurtleFrame:Hide()
        running = false
    else
        FlappyTurtleFrame:Show()
        ResetGame()
        infoText:SetText("Click to Start")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00FlappyTurtle: Loaded successfully! Type /flappy to play.|r")