-- Enhanced Minesweeper in Luau for Roblox by Capy (LocalScript in StarterPlayer > StarterPlayerGui)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Game settings
local GRID_WIDTH = 12
local GRID_HEIGHT = 12
local NUM_MINES = 25
local TILE_SIZE = 35
local PADDING = 2

-- Colors
local TILE_CLOSED = Color3.fromRGB(192, 192, 192)
local TILE_OPENED = Color3.fromRGB(220, 220, 220)
local TILE_FLAG = Color3.fromRGB(0, 0, 255)
local TILE_MINE = Color3.fromRGB(255, 0, 0)
local TILE_HUGE_CLEAR = Color3.fromRGB(255, 255, 0) -- Yellow for huge clearance
local NUMBER_COLORS = {
    [1] = Color3.fromRGB(0, 0, 255),
    [2] = Color3.fromRGB(0, 128, 0),
    [3] = Color3.fromRGB(255, 0, 0),
    [4] = Color3.fromRGB(0, 0, 139),
    [5] = Color3.fromRGB(139, 0, 0),
    [6] = Color3.fromRGB(0, 139, 139),
    [7] = Color3.fromRGB(0, 0, 0),
    [8] = Color3.fromRGB(128, 128, 128)
}

-- State
local board = {}
local revealed = {}
local flagged = {}
local gameOver = false
local firstClick = true
local minesLeft = NUM_MINES
local isDragging = false
local dragStart = nil
local startPos = nil

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Minesweeper"
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, GRID_WIDTH * (TILE_SIZE + PADDING) + 20, 0, GRID_HEIGHT * (TILE_SIZE + PADDING) + 80)
mainFrame.Position = UDim2.new(0.5, -mainFrame.Size.X.Offset/2, 0.5, -mainFrame.Size.Y.Offset/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Make window draggable
local dragFrame = Instance.new("Frame")
dragFrame.Size = UDim2.new(1, 0, 0, 35)
dragFrame.Position = UDim2.new(0, 0, 0, 0)
dragFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
dragFrame.BorderSizePixel = 0
dragFrame.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 5, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🧨 Minesweeper (" .. GRID_WIDTH .. "x" .. GRID_HEIGHT .. ", " .. NUM_MINES .. " mines) 🧨"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = dragFrame

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 2.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.Parent = dragFrame

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Drag functionality
local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

dragFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)

dragFrame.InputChanged:Connect(function(input)
    if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateInput(input)
    end
end)

-- Mines counter and restart
local controlFrame = Instance.new("Frame")
controlFrame.Size = UDim2.new(1, -20, 0, 35)
controlFrame.Position = UDim2.new(0, 10, 0, 40)
controlFrame.BackgroundTransparency = 1
controlFrame.Parent = mainFrame

local minesLabel = Instance.new("TextLabel")
minesLabel.Size = UDim2.new(0.5, 0, 1, 0)
minesLabel.Position = UDim2.new(0, 0, 0, 0)
minesLabel.BackgroundTransparency = 1
minesLabel.Text = "Mines: " .. NUM_MINES
minesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
minesLabel.TextScaled = true
minesLabel.Font = Enum.Font.SourceSans
minesLabel.TextXAlignment = Enum.TextXAlignment.Left
minesLabel.Parent = controlFrame

local restartBtn = Instance.new("TextButton")
restartBtn.Size = UDim2.new(0.45, 0, 1, 0)
restartBtn.Position = UDim2.new(0.55, 0, 0, 0)
restartBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
restartBtn.Text = "🔄 Restart"
restartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
restartBtn.TextScaled = true
restartBtn.Font = Enum.Font.SourceSansBold
restartBtn.Parent = controlFrame

restartBtn.MouseButton1Click:Connect(function()
    initGame()
end)

-- Board frame
local boardFrame = Instance.new("Frame")
boardFrame.Size = UDim2.new(1, -20, 1, -85)
boardFrame.Position = UDim2.new(0, 10, 0, 80)
boardFrame.BackgroundTransparency = 1
boardFrame.Parent = mainFrame

-- Helper functions
local function getIndex(x, y)
    return y * GRID_WIDTH + x + 1
end

local function getNeighbors(x, y)
    local dirs = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
    local neighbors = {}
    for _, dir in ipairs(dirs) do
        local nx, ny = x + dir[1], y + dir[2]
        if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT then
            table.insert(neighbors, {nx, ny})
        end
    end
    return neighbors
end

-- HUGE clearance feature - reveals large empty area
local function hugeClearance(x, y)
    local cleared = {}
    local queue = {{x, y}}
    local maxDistance = 4 -- How far to expand
    
    while #queue > 0 do
        local pos = table.remove(queue, 1)
        local cx, cy = pos[1], pos[2]
        local idx = getIndex(cx, cy)
        
        if not revealed[idx] and not flagged[idx] and board[idx] >= 0 then
            revealed[idx] = true
            cleared[idx] = true
            
            -- Animate huge clearance
            local tile = tiles[idx]
            if tile then
                tile.BackgroundColor3 = TILE_HUGE_CLEAR
                tile.TextTransparency = 1
                
                -- Tween to normal opened color
                TweenService:Create(tile, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = TILE_OPENED
                }):Play()
            end
            
            -- Expand if close enough to center and tile is empty/low number
            if board[idx] <= 1 then
                local dist = math.max(math.abs(cx - x), math.abs(cy - y))
                if dist < maxDistance then
                    local neigh = getNeighbors(cx, cy)
                    for _, npos in ipairs(neigh) do
                        local nidx = getIndex(npos[1], npos[2])
                        if not revealed[nidx] and not flagged[nidx] and board[nidx] >= 0 then
                            table.insert(queue, npos)
                        end
                    end
                end
            end
        end
    end
    
    -- Reveal numbers around the cleared area
    for idx in pairs(cleared) do
        local tx = (idx - 1) % GRID_WIDTH
        local ty = math.floor((idx - 1) / GRID_WIDTH)
        local neigh = getNeighbors(tx, ty)
        for _, npos in ipairs(neigh) do
            local nidx = getIndex(npos[1], npos[2])
            if board[nidx] > 0 and not revealed[nidx] and not flagged[nidx] then
                revealed[nidx] = true
                local tile = tiles[nidx]
                if tile then
                    tile.BackgroundColor3 = TILE_OPENED
                    tile.Text = tostring(board[nidx])
                    tile.TextColor3 = NUMBER_COLORS[board[nidx]]
                    tile.AutoButtonColor = false
                end
            end
        end
    end
end

-- Flood fill for normal reveals
local function floodFill(x, y)
    local stack = {{x, y}}
    while #stack > 0 do
        local pos = table.remove(stack)
        local cx, cy = pos[1], pos[2]
        local idx = getIndex(cx, cy)
        if not revealed[idx] and board[idx] == 0 then
            revealed[idx] = true
            local tile = tiles[idx]
            if tile then
                tile.BackgroundColor3 = TILE_OPENED
                tile.TextTransparency = 1
                tile.AutoButtonColor = false
            end
            local neigh = getNeighbors(cx, cy)
            for _, npos in ipairs(neigh) do
                local nidx = getIndex(npos[1], npos[2])
                if not revealed[nidx] and board[nidx] == 0 then
                    table.insert(stack, npos)
                end
            end
        end
    end
end

-- Create tiles
local tiles = {}
function createBoard()
    for _, child in ipairs(boardFrame:GetChildren()) do
        child:Destroy()
    end
    tiles = {}
    for y = 0, GRID_HEIGHT - 1 do
        for x = 0, GRID_WIDTH - 1 do
            local idx = getIndex(x, y)
            local tile = Instance.new("TextButton")
            tile.Name = tostring(idx)
            tile.Size = UDim2.new(0, TILE_SIZE, 0, TILE_SIZE)
            tile.Position = UDim2.new(0, x * (TILE_SIZE + PADDING), 0, y * (TILE_SIZE + PADDING))
            tile.BackgroundColor3 = TILE_CLOSED
            tile.Text = ""
            tile.TextColor3 = Color3.fromRGB(0, 0, 0)
            tile.TextScaled = true
            tile.Font = Enum.Font.SourceSansBold
            tile.BorderSizePixel = 1
            tile.BorderColor3 = Color3.fromRGB(150, 150, 150)
            tile.Parent = boardFrame
            tiles[idx] = tile

            tile.MouseButton1Click:Connect(function()
                if gameOver then return end
                local bx = (idx - 1) % GRID_WIDTH
                local by = math.floor((idx - 1) / GRID_WIDTH)
                onReveal(bx, by)
            end)

            tile.MouseButton2Click:Connect(function()
                if gameOver then return end
                local bx = (idx - 1) % GRID_WIDTH
                local by = math.floor((idx - 1) / GRID_WIDTH)
                onFlag(bx, by)
            end)
        end
    end
end

-- Place mines (avoid first click)
function placeMines(excludeX, excludeY)
    local mines = {}
    while #mines < NUM_MINES do
        local x = math.random(0, GRID_WIDTH - 1)
        local y = math.random(0, GRID_HEIGHT - 1)
        local idx = getIndex(x, y)
        if (x ~= excludeX or y ~= excludeY) and not table.find(mines, idx) then
            table.insert(mines, idx)
            board[idx] = -1
        end
    end
end

-- Calculate numbers
function calcNumbers()
    for i = 1, #board do
        if board[i] ~= -1 then
            local x = (i - 1) % GRID_WIDTH
            local y = math.floor((i - 1) / GRID_WIDTH)
            local neigh = getNeighbors(x, y)
            local count = 0
            for _, pos in ipairs(neigh) do
                local nidx = getIndex(pos[1], pos[2])
                if board[nidx] == -1 then
                    count += 1
                end
            end
            board[i] = count
        end
    end
end

-- Reveal tile
function onReveal(x, y)
    local idx = getIndex(x, y)
    if flagged[idx] then return end
    
    if firstClick then
        firstClick = false
        board = table.create(GRID_WIDTH * GRID_HEIGHT, 0)
        placeMines(x, y)
        calcNumbers()
    end
    
    if board[idx] == -1 then
        -- Game Over
        gameOver = true
        for i = 1, #board do
            local tile = tiles[i]
            if board[i] == -1 then
                tile.BackgroundColor3 = TILE_MINE
                tile.Text = "💣"
            elseif board[i] > 0 then
                tile.BackgroundColor3 = TILE_OPENED
                tile.Text = tostring(board[i])
                tile.TextColor3 = NUMBER_COLORS[board[i]]
            end
            tile.AutoButtonColor = false
        end
        minesLabel.Text = "💥 GAME OVER! 💥"
        return
    end
    
    revealed[idx] = true
    local tile = tiles[idx]
    tile.BackgroundColor3 = TILE_OPENED
    tile.AutoButtonColor = false
    
    -- 37.5% chance for big clearance
    if math.random() < 0.375 and board[idx] == 0 then
        hugeClearance(x, y)
    else
        -- Normal reveal
        if board[idx] == 0 then
            floodFill(x, y)
        elseif board[idx] > 0 then
            tile.Text = tostring(board[idx])
            tile.TextColor3 = NUMBER_COLORS[board[idx]]
        end
    end
    
    checkWin()
end

-- Flag tile
function onFlag(x, y)
    local idx = getIndex(x, y)
    local tile = tiles[idx]
    if revealed[idx] then return end
    
    flagged[idx] = not flagged[idx]
    if flagged[idx] then
        tile.BackgroundColor3 = TILE_FLAG
        tile.Text = "🚩"
        minesLeft -= 1
    else
        tile.BackgroundColor3 = TILE_CLOSED
        tile.Text = ""
        minesLeft += 1
    end
    minesLabel.Text = "Mines: " .. minesLeft
end

-- Check win
function checkWin()
    local unrevealedSafe = 0
    for i = 1, #board do
        if not revealed[i] and board[i] ~= -1 then
            unrevealedSafe += 1
        end
    end
    if unrevealedSafe == 0 then
        gameOver = true
        minesLabel.Text = "🎉 YOU WIN! 🎉"
    end
end

-- Init game
function initGame()
    board = table.create(GRID_WIDTH * GRID_HEIGHT, 0)
    revealed = table.create(GRID_WIDTH * GRID_HEIGHT, false)
    flagged = table.create(GRID_WIDTH * GRID_HEIGHT, false)
    gameOver = false
    firstClick = true
    minesLeft = NUM_MINES
    minesLabel.Text = "Mines: " .. NUM_MINES
    createBoard()
end

initGame()
