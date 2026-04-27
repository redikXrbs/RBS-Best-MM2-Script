-- [[ RBS - MM2 ULTIMATE FARM v3.0 ]]
-- Функции: Auto Farm с умным полетом, God Mode, GUI с индикацией

-- ===========================
-- ИНИЦИАЛИЗАЦИЯ
-- ===========================
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

-- Позиция под центром карты (динамически обновляется)
local centerPosition = nil
local isCollecting = false
local currentTween = nil

-- ===========================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ===========================

-- Проверка: идет ли раунд и является ли игрок участником (не в лобби)
local function IsRoundActive()
    -- Проверка наличия убийцы/шерифа в игре (признак активного раунда)
    local players = game.Players:GetPlayers()
    local hasMurderer = false
    local hasSheriff = false
    
    for _, player in ipairs(players) do
        local character = player.Character
        if character then
            local backpack = player.Backpack
            -- Проверка по оружию в руках или в инвентаре
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
    
    -- Если есть убийца или шериф - раунд идет
    local roundActive = hasMurderer or hasSheriff
    
    -- Дополнительная проверка: игрок не в лобби (проверка по спавну)
    local character = LocalPlayer.Character
    local isInLobby = false
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            -- Если игрок на спавне с координатами около (0, 500, 0) - это лобби в MM2
            if math.abs(rootPart.Position.Y) > 400 then
                isInLobby = true
            end
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

-- Обновление центральной позиции (под картой)
local function UpdateCenterPosition()
    -- Поиск центра карты по карте (Workspace)
    local map = workspace:FindFirstChild("Map")
    if map then
        local primaryPart = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primaryPart then
            centerPosition = primaryPart.Position + Vector3.new(0, -10, 0) -- под центр карты
            return
        end
    end
    
    -- Fallback: поиск по всем частям
    local totalPos = Vector3.new(0, 0, 0)
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 100 then
            totalPos = totalPos + obj.Position
            count = count + 1
        end
    end
    
    if count > 0 then
        centerPosition = (totalPos / count) + Vector3.new(0, -10, 0)
    else
        centerPosition = Vector3.new(0, 0, 0) + Vector3.new(0, -10, 0)
    end
end

-- Поиск всех монет на карте
local function FindAllCoins()
    local coins = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold")
            
            if not isCoin and obj.BrickColor then
                isCoin = obj.BrickColor.Name == "Bright yellow" or obj.BrickColor.Name == "Gold"
            end
            
            if isCoin then
                table.insert(coins, {
                    object = obj,
                    position = obj.Position,
                    distance = (GetRootPart().Position - obj.Position).Magnitude
                })
            end
        end
    end
    
    -- Сортировка по расстоянию
    table.sort(coins, function(a, b)
        return a.distance < b.distance
    end)
    
    return coins
end

-- Tween движение к позиции
local function TweenToPosition(targetPosition, callback)
    local rootPart = GetRootPart()
    if not rootPart then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local distance = (rootPart.Position - targetPosition).Magnitude
    local speed = 35 -- скорость полета
    local duration = math.max(0.2, distance / speed)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    
    if callback then
        currentTween.Completed:Connect(callback)
    end
    
    currentTween:Play()
    return currentTween
end

-- Сбор монеты
local function CollectCoin(coin)
    pcall(function()
        TweenToPosition(coin.position)
        wait(0.05)
        
        local clickDetector = coin.object:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            fireclickdetector(clickDetector)
        end
        
        local proximityPrompt = coin.object:FindFirstChildWhichIsA("ProximityPrompt")
        if proximityPrompt then
            proximityPrompt:InputHoldBegin()
            wait(0.05)
            proximityPrompt:InputHoldEnd()
        end
    end)
end

-- Включение/выключение коллизии
local function SetCollision(enabled)
    local character = GetCharacter()
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = enabled
            part.CanQuery = enabled
        end
    end
end

-- Режим бога
local function SetGodMode(enabled)
    local character = GetCharacter()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if enabled then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        humanoid.BreakJointsOnDeath = false
        
        -- Защита от урона
        local conn = humanoid:GetAttribute("GodModeConnection")
        if conn then conn:Disconnect() end
        
        local newConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
        humanoid:SetAttribute("GodModeConnection", newConn)
        
        -- Отключение коллизий частей тела
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanQuery = false
            end
        end
    else
        humanoid.MaxHealth = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        humanoid.BreakJointsOnDeath = true
        
        local conn = humanoid:GetAttribute("GodModeConnection")
        if conn then conn:Disconnect() end
        humanoid:SetAttribute("GodModeConnection", nil)
        
        -- Восстановление коллизий (только для частей тела)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
                part.CanQuery = true
            end
        end
    end
end

-- ===========================
-- ОСНОВНАЯ ЛОГИКА AUTO FARM
-- ===========================

local farmLoop = nil
local returnToCenterTask = nil

local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true
    
    -- Отключаем коллизию
    SetCollision(false)
    
    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.autoFarm then 
            farmLoop:Disconnect()
            farmLoop = nil
            return 
        end
        
        -- Проверка: идет ли раунд и является ли игрок участником
        if not IsRoundActive() then
            -- Если в лобби или раунд не идет, ничего не делаем
            wait(1)
            return
        end
        
        -- Включение режима бога если он не активен
        if state.godMode then
            SetGodMode(true)
        end
        
        -- Обновляем позицию центра карты
        UpdateCenterPosition()
        
        -- Поиск монет
        local coins = FindAllCoins()
        
        if #coins > 0 then
            -- Если есть монеты - собираем их по порядку
            isCollecting = true
            
            for _, coin in ipairs(coins) do
                if not state.autoFarm then break end
                if coin.object and coin.object.Parent then
                    CollectCoin(coin)
                    wait(0.1)
                end
            end
            
            isCollecting = false
            
            -- После сбора всех монет, если все еще активен - возврат в центр
            if state.autoFarm and IsRoundActive() and #FindAllCoins() == 0 then
                if centerPosition then
                    TweenToPosition(centerPosition)
                end
            end
        else
            -- Если монет нет и не в процессе сбора - летим в центр карты
            if not isCollecting and centerPosition then
                local rootPart = GetRootPart()
                if rootPart and (rootPart.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
            wait(0.2)
        end
    end)
    
    print("[RBS] Auto Farm запущен")
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
    
    -- Восстанавливаем коллизию
    SetCollision(true)
    
    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ
-- ===========================

local screenGui = nil
local mainFrame = nil

local function CreateMenu()
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
    
    -- Заголовок с перетаскиванием
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "RBS - MM2 ULTIMATE"
    title.TextColor3 = Color3.fromRGB(255, 120, 120)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Кнопка Auto Farm с индикацией состояния
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 220, 0, 40)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 14
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame
    
    -- Кнопка God Mode с индикацией состояния
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 220, 0, 40)
    godModeBtn.Position = UDim2.new(0, 15, 0, 95)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 14
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame
    
    -- Обработчики кнопок
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

-- Обновление UI (синхронизация)
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
    wait(0.5)
    
    -- Восстановление коллизии
    SetCollision(not state.autoFarm)
    
    -- Восстановление God Mode если включен
    if state.godMode then
        SetGodMode(true)
    end
    
    -- Обновление центра карты
    UpdateCenterPosition()
    
    print("[RBS] Character respawn detected, states restored")
end)

-- ===========================
-- ЗАПУСК
-- ===========================

print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE FARM v3.0       ║
╠═══════════════════════════════════════════╣
║  Auto Farm:                               ║
║    - Отключает коллизию                   ║
║    - Полет под центр карты                ║
║    - Сбор монет по приоритету             ║
║    - Работает ТОЛЬКО в активном раунде    ║
║                                           ║
║  God Mode:                                ║
║    - Бесконечное здоровье                 ║
║    - Неуязвимость                         ║
╚═══════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
print("[RBS] Меню создано. Нажмите на кнопки для активации функций")
