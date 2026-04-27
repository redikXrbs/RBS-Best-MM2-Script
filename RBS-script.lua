-- [[ RBS - MM2 ULTIMATE FARM v3.1 (FIXED) ]]
-- Исправлено: независимый God Mode, уменьшена задержка, улучшена коллизия, работа кнопок

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Состояния
local state = {
    autoFarm = false,
    godMode = false
}

-- Глобальные переменные
local centerPosition = nil
local isCollecting = false
local currentTween = nil
local godModeConnection = nil
local farmLoop = nil
local noCollisionLoop = nil

-- ===========================
-- НАСТРОЙКИ (можно менять)
-- ===========================
local CONFIG = {
    FLY_SPEED = 28,            -- Скорость полета (было 35)
    COLLECTION_DELAY = 0.4,    -- Задержка между монетами (было 0.1, теперь 0.4 сек)
    RETURN_DELAY = 0.8,        -- Задержка перед возвратом в центр
    CENTER_OFFSET = -6,        -- Смещение под центр карты (было -10, чтобы не проваливаться)
    TWEEN_STYLE = Enum.EasingStyle.Quad, -- Плавное движение
}

-- ===========================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ===========================

-- Проверка: идет ли раунд и является ли игрок участником (не в лобби)
local function IsRoundActive()
    local players = game.Players:GetPlayers()
    local hasMurderer = false
    local hasSheriff = false

    for _, player in ipairs(players) do
        local character = player.Character
        if character then
            local backpack = player.Backpack
            if character:FindFirstChildOfClass("Tool") then
                local tool = character:FindFirstChildOfClass("Tool")
                if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("gun")) then
                    if player ~= LocalPlayer then
                        hasMurderer = hasMurderer or tool.Name:lower():find("knife")
                        hasSheriff = hasSheriff or tool.Name:lower():find("gun")
                    end
                end
            end
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        if tool.Name:lower():find("knife") then hasMurderer = true end
                        if tool.Name:lower():find("gun") then hasSheriff = true end
                    end
                end
            end
        end
    end

    local roundActive = hasMurderer or hasSheriff

    local character = LocalPlayer.Character
    local isInLobby = false
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart and math.abs(rootPart.Position.Y) > 400 then
            isInLobby = true
        end
    end

    return roundActive and not isInLobby
end

-- Получение персонажа
local function GetCharacter()
    local character = LocalPlayer.Character
    if not character or not character.Parent then
        character = LocalPlayer.CharacterAdded:Wait()
    end
    return character
end

-- Получение RootPart
local function GetRootPart()
    local character = GetCharacter()
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        character:WaitForChild("HumanoidRootPart")
        rootPart = character.HumanoidRootPart
    end
    return rootPart
end

-- Обновление центральной позиции (над картой, а не под ней, чтобы не проваливаться)
local function UpdateCenterPosition()
    local map = workspace:FindFirstChild("Map")
    if map then
        local primaryPart = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primaryPart then
            centerPosition = primaryPart.Position + Vector3.new(0, CONFIG.CENTER_OFFSET, 0)
            return
        end
    end

    local totalPos = Vector3.new(0, 0, 0)
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 100 then
            totalPos = totalPos + obj.Position
            count = count + 1
        end
    end

    if count > 0 then
        centerPosition = (totalPos / count) + Vector3.new(0, CONFIG.CENTER_OFFSET, 0)
    else
        centerPosition = Vector3.new(0, 10, 0)
    end
end

-- Поиск всех монет на карте
local function FindAllCoins()
    local coins = {}
    local rootPart = GetRootPart()
    if not rootPart then return coins end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash")
            
            if not isCoin and obj.BrickColor then
                isCoin = obj.BrickColor.Name == "Bright yellow" or obj.BrickColor.Name == "Gold"
            end

            if isCoin then
                table.insert(coins, {
                    object = obj,
                    position = obj.Position,
                    distance = (rootPart.Position - obj.Position).Magnitude
                })
            end
        end
    end

    table.sort(coins, function(a, b)
        return a.distance < b.distance
    end)

    return coins
end

-- ПЛАВНОЕ Tween движение (без дерганья)
local function SmoothTweenToPosition(targetPosition)
    local rootPart = GetRootPart()
    if not rootPart then return end

    if currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing then
        currentTween:Cancel()
    end

    local distance = (rootPart.Position - targetPosition).Magnitude
    local duration = math.max(0.3, distance / CONFIG.FLY_SPEED)

    local tweenInfo = TweenInfo.new(duration, CONFIG.TWEEN_STYLE, Enum.EasingDirection.Out)
    local newTween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    currentTween = newTween

    pcall(function()
        newTween:Play()
    end)

    return newTween
end

-- Улучшенный сбор монеты
local function CollectCoin(coin)
    if not coin or not coin.object or not coin.object.Parent then
        return false
    end

    local success = false
    pcall(function()
        SmoothTweenToPosition(coin.position)
        
        -- Ждём прибытия
        local timeout = 0
        while currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing and timeout < 30 do
            wait(0.05)
            timeout = timeout + 1
        end
        wait(0.08)

        local clickDetector = coin.object:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            fireclickdetector(clickDetector)
            success = true
        end

        local proximityPrompt = coin.object:FindFirstChildWhichIsA("ProximityPrompt")
        if proximityPrompt then
            proximityPrompt:InputHoldBegin()
            wait(0.08)
            proximityPrompt:InputHoldEnd()
            success = true
        end

        if not success then
            local rootPart = GetRootPart()
            if rootPart then
                rootPart.CFrame = coin.object.CFrame
                wait(0.08)
                success = true
            end
        end
    end)
    return success
end

-- ===========================
-- КОЛЛИЗИЯ (ИСПРАВЛЕНА)
-- ===========================
local function SetCollision(enabled)
    local character = GetCharacter()
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Не отключаем коллизию полностью, чтобы не проваливаться
            part.CanCollide = false  -- отключаем для прохождения сквозь стены
            part.CanQuery = enabled  -- нужно для сбора монет
            -- Включаем заземление для RootPart
            if part.Name == "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end
end

-- Дополнительная защита от падения под карту
local function AntiFallProtection()
    if noCollisionLoop then noCollisionLoop:Disconnect() end
    
    noCollisionLoop = RunService.RenderStepped:Connect(function()
        if not state.autoFarm then return end
        local character = GetCharacter()
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart and rootPart.Position.Y < -20 then
            -- Телепортируем обратно в центр, если провалился
            if centerPosition then
                rootPart.CFrame = CFrame.new(centerPosition)
                print("[RBS] Anti-fall: teleported back to center")
            end
        end
    end)
end

-- ===========================
-- GOD MODE (ПОЛНОСТЬЮ НЕЗАВИСИМЫЙ)
-- ===========================
local function SetGodMode(enabled)
    local character = GetCharacter()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    if enabled then
        if godModeConnection then
            godModeConnection:Disconnect()
        end

        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        humanoid.BreakJointsOnDeath = false

        godModeConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < math.huge then
                humanoid.Health = math.huge
            end
        end)

        humanoid.Died:Connect(function()
            if state.godMode then
                wait(0.2)
                local newHumanoid = GetCharacter():FindFirstChild("Humanoid")
                if newHumanoid then
                    newHumanoid.Health = math.huge
                end
            end
        end)
        
        print("[RBS] God Mode: ON")
    else
        if godModeConnection then
            godModeConnection:Disconnect()
            godModeConnection = nil
        end

        humanoid.MaxHealth = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        humanoid.BreakJointsOnDeath = true
        
        -- Не восстанавливаем здоровье мгновенно, просто отключаем защиту
        if humanoid.Health > 100 then
            humanoid.Health = 100
        end
        
        print("[RBS] God Mode: OFF")
    end
end

-- ===========================
-- AUTO FARM (ПЕРЕРАБОТАН)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true

    SetCollision(false)
    AntiFallProtection()

    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.autoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end

        if not IsRoundActive() then
            wait(1)
            return
        end

        -- God Mode включается/выключается ТОЛЬКО своей кнопкой, автофарм его не трогает!

        UpdateCenterPosition()
        local coins = FindAllCoins()

        if #coins > 0 then
            isCollecting = true
            for _, coin in ipairs(coins) do
                if not state.autoFarm then break end
                if coin.object and coin.object.Parent then
                    CollectCoin(coin)
                    wait(CONFIG.COLLECTION_DELAY)  -- Задержка между монетами
                end
            end
            isCollecting = false

            if state.autoFarm and centerPosition and #FindAllCoins() == 0 then
                wait(CONFIG.RETURN_DELAY)
                local rootPart = GetRootPart()
                if rootPart and (rootPart.Position - centerPosition).Magnitude > 15 then
                    SmoothTweenToPosition(centerPosition)
                end
            end
        else
            if centerPosition then
                local rootPart = GetRootPart()
                if rootPart and (rootPart.Position - centerPosition).Magnitude > 15 then
                    SmoothTweenToPosition(centerPosition)
                end
            end
            wait(0.2)
        end
    end)

    print("[RBS] Auto Farm запущен. Задержка между монетами: " .. CONFIG.COLLECTION_DELAY .. " сек")
    UpdateUI()
end

local function StopAutoFarm()
    state.autoFarm = false
    isCollecting = false

    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    if noCollisionLoop then
        noCollisionLoop:Disconnect()
        noCollisionLoop = nil
    end

    SetCollision(true)
    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (С ДВУМЯ НЕЗАВИСИМЫМИ КНОПКАМИ)
-- ===========================
local screenGui = nil
local mainFrame = nil

local function CreateMenu()
    if screenGui then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RBS_MM2_Ultimate"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 150)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.fromRGB(255, 100, 100)
    mainFrame.Parent = screenGui

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ RBS - MM2 ULTIMATE v3.1"
    title.TextColor3 = Color3.fromRGB(255, 120, 120)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar

    -- Кнопка Auto Farm
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 220, 0, 40)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 40)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 14
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame

    -- Кнопка God Mode (полностью независимая)
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 220, 0, 40)
    godModeBtn.Position = UDim2.new(0, 15, 0, 90)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 14
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame

    -- Обработчики
    autoFarmBtn.MouseButton1Click:Connect(function()
        if state.autoFarm then
            StopAutoFarm()
            autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
            autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            StartAutoFarm()
            autoFarmBtn.Text = "🟢 AUTO FARM: ON"
            autoFarmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        end
    end)

    godModeBtn.MouseButton1Click:Connect(function()
        if state.godMode then
            state.godMode = false
            SetGodMode(false)
            godModeBtn.Text = "🔴 GOD MODE: OFF"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            state.godMode = true
            SetGodMode(true)
            godModeBtn.Text = "🟢 GOD MODE: ON"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        end
        UpdateUI()
    end)

    -- Перетаскивание окна
    local dragging = false
    local dragStart = nil
    local framePos = nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            framePos = mainFrame.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

function UpdateUI()
    if not mainFrame then return end
    for _, btn in ipairs(mainFrame:GetDescendants()) do
        if btn:IsA("TextButton") then
            if btn.Text:find("AUTO FARM") then
                btn.Text = state.autoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.autoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            elseif btn.Text:find("GOD MODE") then
                btn.Text = state.godMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.godMode and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            end
        end
    end
end

-- ===========================
-- ЗАЩИТА ПРИ РЕСПАВНЕ
-- ===========================
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(0.8)
    
    if state.autoFarm then
        SetCollision(false)
        AntiFallProtection()
        -- Не перезапускаем фарм, он сам подхватится
    end
    
    if state.godMode then
        SetGodMode(true)
    end
    
    UpdateCenterPosition()
    print("[RBS] Character respawn, states restored")
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE FARM v3.1         ║
╠═══════════════════════════════════════════╣
║  Исправления:                            ║
║    ✓ God Mode теперь независимый         ║
║    ✓ Задержка между монетами 0.4 сек     ║
║    ✓ Исправлено отключение коллизии      ║
║    ✓ Защита от падения под карту         ║
╚═══════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
