-- [[ RBS - MM2 ULTIMATE FARM v4.0 (ZERO STUTTER) ]]
-- Полный рефакторинг: Плавный полёт, полное игнорирование коллизий, система сбора без остановок
-- Фикс: Постоянное состояние "падения" без дерганья, мануальный Noclip, ограничение по монетам

-- ===========================
-- ИНИЦИАЛИЗАЦИЯ И СЕРВИСЫ
-- ===========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Состояния
local state = {
    autoFarm = false,
    noclip = false,      -- Ручное управление ноклипом
    godMode = false,
    isFlying = false      -- Флаг полёта
}

-- Глобальные переменные
local centerPosition = nil
local currentTween = nil
local farmLoop = nil
local noclipConnection = nil
local godModeConnection = nil
local coinsCache = {}          -- Кэш монет для оптимизации
local bagLimit = 40            -- Лимит монет за раунд (обычный игрок)

-- Настройки полёта
local CONFIG = {
    FLY_SPEED = 70,            -- Высокая скорость для эффекта "скольжения"
    GROUND_OFFSET = -8,        -- Полёт под картой (-8 для сбора)
    TWEEN_STYLE = Enum.EasingStyle.Linear,  -- Линейное движение (без тормозов)
    BAG_CHECK_INTERVAL = 0.5,  -- Проверка сумки каждые 0.5 сек
}

-- ===========================
-- ЯДРО МЕХАНИКИ (НУЛЕВОЕ ДЁРГАНЬЕ)
-- ===========================

-- 1. ОТКЛЮЧЕНИЕ ГРАВИТАЦИИ (Игрок всегда в состоянии "падения", но не падает)
local function SetFlightMode(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        if enabled then
            -- Включаем режим полёта: отключаем гравитацию
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            
            -- Даём возможность "парить"
            humanoid.PlatformStand = true
            state.isFlying = true
        else
            -- Возвращаем гравитацию
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
            humanoid.PlatformStand = false
            state.isFlying = false
        end
    end
end

-- 2. ПРОДВИНУТЫЙ НОКЛИП (Фикс дерганья)
local function setNoclip(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    
    -- Основной физический трюк для отключения коллизий
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if enabled then
                -- Отключаем коллизию и убираем массу для полного игнорирования стен
                part.CanCollide = false
                part.CanQuery = false
                if part:IsA("MeshPart") or part:IsA("Part") then
                    part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
                end
            else
                -- Возвращаем коллизию (но только для обычного режима)
                if part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                    part.CanQuery = true
                end
                part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
            end
        end
    end
    
    -- Доп. обработка HumanoidRootPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        if enabled then
            hrp.CanCollide = false
            hrp.CanQuery = false
        else
            hrp.CanCollide = true
            hrp.CanQuery = true
        end
    end
end

-- 3. ОБНОВЛЕНИЕ ПОЗИЦИИ ПОД КАРТОЙ (Динамический центр)
local function UpdateCenterPosition()
    local map = workspace:FindFirstChild("Map")
    if map then
        local primaryPart = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primaryPart then
            centerPosition = primaryPart.Position + Vector3.new(0, CONFIG.GROUND_OFFSET, 0)
            return
        end
    end
    
    -- Альтернативный поиск
    local totalPos = Vector3.new(0, 0, 0)
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 100 then
            totalPos = totalPos + obj.Position
            count = count + 1
        end
    end
    
    if count > 0 then
        centerPosition = (totalPos / count) + Vector3.new(0, CONFIG.GROUND_OFFSET, 0)
    else
        centerPosition = Vector3.new(0, CONFIG.GROUND_OFFSET, 0)
    end
end

-- 4. ПОЛУЧЕНИЕ МОНЕТ (С ИСПОЛЬЗОВАНИЕМ КЭША)
local function RefreshCoinsCache()
    local newCoins = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash")
            
            if not isCoin and obj.BrickColor then
                isCoin = obj.BrickColor.Name == "Bright yellow" or obj.BrickColor.Name == "Gold"
            end
            
            if isCoin then
                table.insert(newCoins, obj)
            end
        end
    end
    coinsCache = newCoins
    return coinsCache
end

-- 5. ПРОВЕРКА СУМКИ (Ограничение 40-50 монет)
local function GetCurrentCoins()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins")
        if coins then
            return coins.Value
        end
    end
    return 0
end

local function IsBagFull()
    local currentCoins = GetCurrentCoins()
    -- В финале раунда сумка считается полной (40 для обычных, 50 для элитных)
    return currentCoins >= bagLimit
end

-- 6. СБОР МОНЕТЫ (Мгновенный, без ожидания)
local function CollectCoin(coin)
    if not coin or not coin.Parent then return false end
    
    local success = false
    pcall(function()
        -- Мгновенный триггер сбора через FireClickDetector
        local clickDetector = coin:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            fireclickdetector(clickDetector)
            success = true
        end
        
        local proximityPrompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if proximityPrompt then
            proximityPrompt:InputHoldBegin()
            wait(0.02)
            proximityPrompt:InputHoldEnd()
            success = true
        end
        
        -- Если ничего не сработало — форсируем телепортацию тела на позицию монеты
        if not success then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local oldPos = hrp.Position
                hrp.CFrame = coin.CFrame
                wait(0.02)
                hrp.CFrame = CFrame.new(oldPos)
                success = true
            end
        end
    end)
    return success
end

-- 7. ПОЛЁТ ЧЕРЕЗ TWEEN (Без остановок, через EasingStyle.Linear)
local function FlyToPosition(targetPosition)
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local distance = (rootPart.Position - targetPosition).Magnitude
    local duration = math.max(0.1, distance / CONFIG.FLY_SPEED)
    
    local tweenInfo = TweenInfo.new(duration, CONFIG.TWEEN_STYLE, Enum.EasingDirection.Out)
    local newTween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    currentTween = newTween
    
    newTween:Play()
    return newTween
end

-- 8. GOD MODE (Независимый)
local function SetGodMode(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if enabled then
        if godModeConnection then godModeConnection:Disconnect() end
        
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        humanoid.BreakJointsOnDeath = false
        
        godModeConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < math.huge then
                humanoid.Health = math.huge
            end
        end)
        
        -- Отключаем коллизию для God Mode
        setNoclip(true)
    else
        if godModeConnection then
            godModeConnection:Disconnect()
            godModeConnection = nil
        end
        
        humanoid.MaxHealth = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        humanoid.BreakJointsOnDeath = true
        
        if humanoid.Health > 100 then
            humanoid.Health = 100
        end
        
        -- Возвращаем коллизию обратно, если Auto Farm не активен
        if not state.autoFarm then
            setNoclip(false)
        end
    end
end

-- 9. ПРОВЕРКА АКТИВНОСТИ РАУНДА (Упрощённая)
local function IsRoundActive()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character then
                local tool = character:FindFirstChildOfClass("Tool")
                if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("gun")) then
                    return true
                end
            end
        end
    end
    return false
end

-- ===========================
-- АВТО ФАРМ (РЕФАКТОРИНГ)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true
    
    -- Включаем ноклип и полёт
    setNoclip(true)
    SetFlightMode(true)
    
    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.autoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end
        
        -- Проверка раунда
        if not IsRoundActive() then
            wait(1)
            return
        end
        
        -- Получаем актуальный центр карты
        UpdateCenterPosition()
        
        -- Обновляем кэш монет
        local coins = RefreshCoinsCache()
        
        -- Проверяем сумку
        if IsBagFull() then
            -- Если сумка полная — летим под центр и стоим
            local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart and centerPosition and (rootPart.Position - centerPosition).Magnitude > 10 then
                FlyToPosition(centerPosition)
            end
            wait(0.5)
            return
        end
        
        -- Если есть монеты
        if #coins > 0 then
            for _, coin in ipairs(coins) do
                if not state.autoFarm then break end
                if coin and coin.Parent then
                    -- Летим к монете
                    FlyToPosition(coin.Position)
                    -- Даём самый минимум времени на подлёт (чтобы успеть триггернуть)
                    wait(0.02)
                    -- Собираем
                    CollectCoin(coin)
                    -- Не ждём, сразу переходим к следующей итерации
                end
            end
        else
            -- Нет монет — летим в центр
            local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart and centerPosition and (rootPart.Position - centerPosition).Magnitude > 15 then
                FlyToPosition(centerPosition)
            end
            wait(0.1)
        end
    end)
    
    print("[RBS] Auto Farm запущен (Zero Stutter Mode)")
    UpdateUI()
end

local function StopAutoFarm()
    state.autoFarm = false
    
    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    -- Отключаем ноклип и полёт только если God Mode не активен
    if not state.godMode then
        setNoclip(false)
    end
    SetFlightMode(false)
    
    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (С отдельной кнопкой Noclip)
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
    mainFrame.Size = UDim2.new(0, 260, 0, 200)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(255, 100, 100)
    mainFrame.Parent = screenGui
    
    -- Заголовок
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "✈️ RBS - ULTRA SMOOTH v4.0"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Кнопка Auto Farm
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 230, 0, 35)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 13
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame
    
    -- Кнопка God Mode
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 230, 0, 35)
    godModeBtn.Position = UDim2.new(0, 15, 0, 85)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 13
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame
    
    -- Кнопка Noclip (ручное управление)
    local noclipBtn = Instance.new("TextButton")
    noclipBtn.Size = UDim2.new(0, 230, 0, 35)
    noclipBtn.Position = UDim2.new(0, 15, 0, 125)
    noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    noclipBtn.Text = "🧱 NOCLIP: OFF"
    noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noclipBtn.TextSize = 13
    noclipBtn.Font = Enum.Font.GothamBold
    noclipBtn.Parent = mainFrame
    
    -- Индикатор монет
    local coinLabel = Instance.new("TextLabel")
    coinLabel.Size = UDim2.new(0, 230, 0, 20)
    coinLabel.Position = UDim2.new(0, 15, 0, 165)
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "💰 Монет в сумке: 0 / " .. bagLimit
    coinLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    coinLabel.TextSize = 11
    coinLabel.Font = Enum.Font.Gotham
    coinLabel.Parent = mainFrame
    
    -- Обновление счётчика монет
    local function UpdateCoinCounter()
        local current = GetCurrentCoins()
        coinLabel.Text = "💰 Монет в сумке: " .. current .. " / " .. bagLimit
        if current >= bagLimit then
            coinLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            coinLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
    end
    
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
    end)
    
    noclipBtn.MouseButton1Click:Connect(function()
        if state.noclip then
            state.noclip = false
            setNoclip(false)
            noclipBtn.Text = "🧱 NOCLIP: OFF"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            state.noclip = true
            setNoclip(true)
            SetFlightMode(true)
            noclipBtn.Text = "🟢 NOCLIP: ON"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        end
    end)
    
    -- Обновление счётчика каждые 0.3 сек
    spawn(function()
        while screenGui and screenGui.Parent do
            UpdateCoinCounter()
            wait(0.3)
        end
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
            if string.find(btn.Text, "AUTO FARM") then
                btn.Text = state.autoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.autoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            elseif string.find(btn.Text, "GOD MODE") then
                btn.Text = state.godMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.godMode and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            elseif string.find(btn.Text, "NOCLIP") then
                btn.Text = state.noclip and "🟢 NOCLIP: ON" or "🧱 NOCLIP: OFF"
                btn.BackgroundColor3 = state.noclip and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            end
        end
    end
end

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(0.5)
    if state.autoFarm then
        setNoclip(true)
        SetFlightMode(true)
    end
    if state.godMode then
        SetGodMode(true)
    end
    if state.noclip then
        setNoclip(true)
        SetFlightMode(true)
    end
    UpdateCenterPosition()
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════════╗
║     RBS - ULTRA SMOOTH FARM v4.0             ║
╠═══════════════════════════════════════════════╣
║  ✓ Нулевое дерганье (Linear Tween)           ║
║  ✓ Мгновенный сбор монет (FireClickDetector) ║
║  ✓ Полёт сквозь стены (Noclip + FlightMode)  ║
║  ✓ Ограничение 40/50 монет в сумке           ║
║  ✓ Отдельная кнопка Noclip для тестов        ║
╚═══════════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
