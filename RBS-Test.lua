-- ╔════════════════════════════════════════════════════════════════════╗
-- ║           🔪 RBS ELITE FARM - TEST MODE 🔪                         ║
-- ║     Версия 1.0 | Собрано из лучших механик топовых хабов         ║
-- ╚════════════════════════════════════════════════════════════════════╝

-- [[ ИСТОЧНИКИ МЕХАНИК:
--      Eclipse Hub     - Основной цикл фарма, оптимизация
--      Onyx Hub        - Tween система, определение монет
--      Vertex Hub      - Приоритет сбора, задержки
--      OP GUI          - NoClip система, отключение гравитации
--      Tbao Hub        - Hitbox/NoClip комбинация
--      Solix Hub       - Анти-падение
--      Vynixu          - Стабильность God Mode
--      Moondiety       - Плавность полета ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- КОНФИГУРАЦИЯ
-- ===========================
local Config = {
    TweenSpeed = 65,           -- Скорость полета (высокая для плавности)
    CollectionDelay = 0.05,    -- Почти мгновенный сбор
    CenterOffset = -5,         -- Позиция под картой
    AntiFallHeight = -12,      -- Защита от падения
}

-- ===========================
-- СОСТОЯНИЯ
-- ===========================
local state = {
    AutoFarm = false,
    GodMode = false,
    NoClip = false,
    InfiniteJump = false,
}

-- Глобальные переменные
local centerPosition = nil
local currentTween = nil
local farmLoop = nil
local godModeConnection = nil
local infiniteJumpConn = nil
local antiFallConn = nil

-- ===========================
-- ОСНОВНЫЕ ФУНКЦИИ
-- ===========================

-- Получение персонажа
local function GetCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    return char
end

local function GetRootPart()
    local char = GetCharacter()
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        char:WaitForChild("HumanoidRootPart")
        root = char.HumanoidRootPart
    end
    return root
end

-- ОПРЕДЕЛЕНИЕ АКТИВНОГО РАУНДА (Eclipse Hub метод)
local function IsRoundActive()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    local name = tool.Name:lower()
                    if name:find("knife") or name:find("gun") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ОБНОВЛЕНИЕ ЦЕНТРА КАРТЫ (Onyx Hub метод)
local function UpdateCenterPosition()
    local map = workspace:FindFirstChild("Map")
    if map then
        local primary = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primary then
            centerPosition = primary.Position + Vector3.new(0, Config.CenterOffset, 0)
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
        centerPosition = (totalPos / count) + Vector3.new(0, Config.CenterOffset, 0)
    else
        centerPosition = Vector3.new(0, Config.CenterOffset, 0)
    end
end

-- ПОИСК МОНЕТ (оптимизировано из Onyx + Vertex)
local function FindAllCoins()
    local coins = {}
    local rootPos = GetRootPart().Position
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash")
            
            if not isCoin and obj.BrickColor then
                local color = obj.BrickColor.Name:lower()
                isCoin = color == "bright yellow" or color == "gold" or color == "new yeller"
            end
            
            if isCoin then
                table.insert(coins, {
                    obj = obj,
                    pos = obj.Position,
                    dist = (rootPos - obj.Position).Magnitude
                })
            end
        end
    end
    
    table.sort(coins, function(a, b) return a.dist < b.dist end)
    return coins
end

-- ⭐ TWEEN СИСТЕМА (плавный полет как у топ-скриптов)
local function TweenToPosition(targetPos)
    local root = GetRootPart()
    if not root then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local dist = (root.Position - targetPos).Magnitude
    local duration = math.max(0.08, dist / Config.TweenSpeed)  -- Минимум 0.08 сек
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    return tween
end

-- ⭐ СБОР МОНЕТЫ (мгновенный, без ожидания)
local function CollectCoin(coinObj)
    pcall(function()
        TweenToPosition(coinObj.Position)
        wait(0.02)  -- Минимальная задержка для подлёта
        
        local click = coinObj:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
            return
        end
        
        local prompt = coinObj:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.02)
            prompt:InputHoldEnd()
        end
    end)
end

-- ⭐ NOCLIP (Тbao Hub + OP GUI комбинация)
local function setNoClip(enabled)
    local char = GetCharacter()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if enabled then
                part.CanCollide = false
                part.CanQuery = false
            else
                if part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                    part.CanQuery = true
                end
            end
        end
    end
    
    -- Специальная обработка RootPart
    local hrp = GetRootPart()
    if hrp then
        hrp.CanCollide = enabled and false or true
        hrp.CanQuery = enabled and false or true
    end
end

-- ⭐ GOD MODE (Vynixu + Moondiety)
local function setGodMode(enabled)
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if enabled then
        if godModeConnection then
            godModeConnection:Disconnect()
        end
        
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum.BreakJointsOnDeath = false
        
        godModeConnection = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if hum.Health < math.huge then
                hum.Health = math.huge
            end
        end)
        
        if state.NoClip then
            setNoClip(true)
        end
    else
        if godModeConnection then
            godModeConnection:Disconnect()
            godModeConnection = nil
        end
        
        hum.MaxHealth = 100
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum.BreakJointsOnDeath = true
        if hum.Health > 100 then
            hum.Health = 100
        end
    end
end

-- ⭐ INFINITE JUMP (Eclipse Hub метод)
local function setInfiniteJump(enabled)
    local hum = GetCharacter():FindFirstChild("Humanoid")
    if not hum then return end
    
    if enabled then
        if infiniteJumpConn then
            infiniteJumpConn:Disconnect()
        end
        infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if infiniteJumpConn then
            infiniteJumpConn:Disconnect()
            infiniteJumpConn = nil
        end
    end
end

-- ⭐ ЗАЩИТА ОТ ПАДЕНИЯ (Solix Hub метод)
local function startAntiFall()
    if antiFallConn then antiFallConn:Disconnect() end
    
    antiFallConn = RunService.RenderStepped:Connect(function()
        if not state.AutoFarm then return end
        
        local char = GetCharacter()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < Config.AntiFallHeight and centerPosition then
            hrp.CFrame = CFrame.new(centerPosition)
        end
    end)
end

-- ===========================
-- AВТО ФАРМ (главный цикл)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.AutoFarm = true
    
    setNoClip(true)          -- Включаем проход сквозь стены
    startAntiFall()          -- Защита от падения
    
    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.AutoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end
        
        -- Проверка активности раунда
        if not IsRoundActive() then
            wait(1)
            return
        end
        
        -- Обновляем центр карты
        UpdateCenterPosition()
        
        -- Поиск монет
        local coins = FindAllCoins()
        
        if #coins > 0 then
            -- Сбор монет без остановок
            for _, coin in ipairs(coins) do
                if not state.AutoFarm then break end
                if coin.obj and coin.obj.Parent then
                    CollectCoin(coin.obj)
                    wait(Config.CollectionDelay)  -- Минимальная задержка
                end
            end
            
            -- Возврат в центр после сбора
            if state.AutoFarm and centerPosition then
                local root = GetRootPart()
                if root and #FindAllCoins() == 0 and (root.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
        else
            -- Нет монет - летим в центр
            if centerPosition then
                local root = GetRootPart()
                if root and (root.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
            wait(0.15)
        end
    end)
    
    print("[RBS ELITE] Auto Farm запущен")
    UpdateUI()
end

local function StopAutoFarm()
    state.AutoFarm = false
    
    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    if antiFallConn then
        antiFallConn:Disconnect()
        antiFallConn = nil
    end
    
    if not state.GodMode and not state.NoClip then
        setNoClip(false)
    end
    
    print("[RBS ELITE] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (только для тестов)
-- ===========================
local screenGui = nil
local mainFrame = nil

local function CreateMenu()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RBS_Elite_Test"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 230)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(255, 80, 80)
    mainFrame.Parent = screenGui
    
    -- Заголовок
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔪 RBS ELITE FARM - TEST MODE"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Кнопки
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 250, 0, 35)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 50)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 13
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame
    
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 250, 0, 35)
    godModeBtn.Position = UDim2.new(0, 15, 0, 95)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 13
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame
    
    local noClipBtn = Instance.new("TextButton")
    noClipBtn.Size = UDim2.new(0, 250, 0, 35)
    noClipBtn.Position = UDim2.new(0, 15, 0, 140)
    noClipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    noClipBtn.Text = "🔴 NOCLIP: OFF"
    noClipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noClipBtn.TextSize = 13
    noClipBtn.Font = Enum.Font.GothamBold
    noClipBtn.Parent = mainFrame
    
    local infiniteJumpBtn = Instance.new("TextButton")
    infiniteJumpBtn.Size = UDim2.new(0, 250, 0, 35)
    infiniteJumpBtn.Position = UDim2.new(0, 15, 0, 185)
    infiniteJumpBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    infiniteJumpBtn.Text = "🔴 INFINITE JUMP: OFF"
    infiniteJumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    infiniteJumpBtn.TextSize = 13
    infiniteJumpBtn.Font = Enum.Font.GothamBold
    infiniteJumpBtn.Parent = mainFrame
    
    -- Обработчики
    autoFarmBtn.MouseButton1Click:Connect(function()
        if state.AutoFarm then
            StopAutoFarm()
            autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
            autoFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            StartAutoFarm()
            autoFarmBtn.Text = "🟢 AUTO FARM: ON"
            autoFarmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        end
    end)
    
    godModeBtn.MouseButton1Click:Connect(function()
        if state.GodMode then
            state.GodMode = false
            setGodMode(false)
            godModeBtn.Text = "🔴 GOD MODE: OFF"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.GodMode = true
            setGodMode(true)
            godModeBtn.Text = "🟢 GOD MODE: ON"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
        end
    end)
    
    noClipBtn.MouseButton1Click:Connect(function()
        if state.NoClip then
            state.NoClip = false
            setNoClip(false)
            noClipBtn.Text = "🔴 NOCLIP: OFF"
            noClipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.NoClip = true
            setNoClip(true)
            noClipBtn.Text = "🟢 NOCLIP: ON"
            noClipBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
        end
    end)
    
    infiniteJumpBtn.MouseButton1Click:Connect(function()
        if state.InfiniteJump then
            state.InfiniteJump = false
            setInfiniteJump(false)
            infiniteJumpBtn.Text = "🔴 INFINITE JUMP: OFF"
            infiniteJumpBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.InfiniteJump = true
            setInfiniteJump(true)
            infiniteJumpBtn.Text = "🟢 INFINITE JUMP: ON"
            infiniteJumpBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
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
    
    titleBar.InputEnded:Connect(function()
        dragging = false
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
                btn.Text = state.AutoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.AutoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(70, 70, 90)
            elseif string.find(btn.Text, "GOD MODE") then
                btn.Text = state.GodMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.GodMode and Color3.fromRGB(100, 60, 100) or Color3.fromRGB(70, 70, 90)
            elseif string.find(btn.Text, "NOCLIP") then
                btn.Text = state.NoClip and "🟢 NOCLIP: ON" or "🔴 NOCLIP: OFF"
                btn.BackgroundColor3 = state.NoClip and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(70, 70, 90)
            elseif string.find(btn.Text, "INFINITE JUMP") then
                btn.Text = state.InfiniteJump and "🟢 INFINITE JUMP: ON" or "🔴 INFINITE JUMP: OFF"
                btn.BackgroundColor3 = state.InfiniteJump and Color3.fromRGB(100, 80, 60) or Color3.fromRGB(70, 70, 90)
            end
        end
    end
end

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function()
    wait(0.8)
    if state.AutoFarm then
        setNoClip(true)
    end
    if state.GodMode then
        setGodMode(true)
    end
    if state.NoClip then
        setNoClip(true)
    end
    if state.InfiniteJump then
        setInfiniteJump(true)
    end
    UpdateCenterPosition()
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔════════════════════════════════════════════════════════════════════╗
║              🔪 RBS ELITE FARM - TEST MODE 🔪                      ║
╠════════════════════════════════════════════════════════════════════╣
║  Собрано из лучших механик: Eclipse Hub | Onyx Hub | Vertex Hub    ║
║                           OP GUI | Tbao Hub | Vynixu               ║
╠════════════════════════════════════════════════════════════════════╣
║  ⚡ Особенности:                                                   ║
║     • Плавный полет Tween (Linear + Out)                          ║
║     • Мгновенный сбор монет (минимальная задержка)                ║
║     • Полное отключение коллизии (NoClip)                         ║
║     • Независимый God Mode                                        ║
║     • Infinite Jump                                               ║
║     • Защита от падения под карту                                 ║
╚════════════════════════════════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
UpdateUI()
