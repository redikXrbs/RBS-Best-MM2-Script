-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║                    🔪 MURDER MYSTERY 2 | RBS ULTIMATE HUB 🔪                   ║
-- ║                        Версия 7.0 | ЧИСТАЯ МЕХАНИКА                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- КОНФИГУРАЦИЯ
-- ===========================
local Config = {
    TweenSpeed = 65,              -- Скорость полёта
    CenterOffset = -8,            -- Точка под картой
    CollectionDelay = 0.05,       -- Задержка между монетами
    BagLimit = 40,                -- Лимит монет в сумке
}

-- ===========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ===========================
local state = {
    AutoFarm = false,
    GodMode = false,
    NoClip = false,
}

local centerPosition = nil
local currentTween = nil
local farmLoop = nil
local godModeConnection = nil
local noclipConnection = nil

-- ===========================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ===========================
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

-- ===========================
-- ⭐ ABSOLUTE NOCLIP (без гравитации)
-- ===========================
local function applyNoclip()
    local char = GetCharacter()
    if not char then return end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
        end
    end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        humanoid.PlatformStand = true
        humanoid.HipHeight = 0
        humanoid.AutoRotate = false
    end
end

local function startNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
    end
    noclipConnection = RunService.Stepped:Connect(applyNoclip)
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    local humanoid = GetCharacter():FindFirstChild("Humanoid")
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        humanoid.PlatformStand = false
    end
end

-- ===========================
-- ⭐ GOD MODE
-- ===========================
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

-- ===========================
-- ОБНОВЛЕНИЕ ЦЕНТРА КАРТЫ
-- ===========================
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

-- ===========================
-- ПОИСК МОНЕТ (ближайшая)
-- ===========================
local function FindNearestCoin()
    local rootPos = GetRootPart().Position
    local nearest = nil
    local nearestDist = math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash")
            
            if not isCoin and obj.BrickColor then
                local color = obj.BrickColor.Name:lower()
                isCoin = color == "bright yellow" or color == "gold" or color == "new yeller"
            end
            
            if isCoin then
                local dist = (rootPos - obj.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = obj
                end
            end
        end
    end
    
    return nearest
end

-- ===========================
-- КОЛИЧЕСТВО МОНЕТ В СУМКЕ
-- ===========================
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
    return GetCurrentCoins() >= Config.BagLimit
end

-- ===========================
-- ПЛАВНЫЙ ПОЛЁТ (TWEEN)
-- ===========================
local function FlyToPosition(targetPos)
    local root = GetRootPart()
    if not root then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local dist = (root.Position - targetPos).Magnitude
    local duration = math.max(0.1, dist / Config.TweenSpeed)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    return tween
end

-- ===========================
-- СБОР МОНЕТЫ
-- ===========================
local function CollectCoin(coin)
    if not coin or not coin.Parent then return false end
    
    local success = false
    pcall(function()
        FlyToPosition(coin.Position)
        wait(0.03)
        
        local click = coin:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
            success = true
        end
        
        local prompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.03)
            prompt:InputHoldEnd()
            success = true
        end
    end)
    return success
end

-- ===========================
-- ⭐ АВТОФАРМ (ГЛАВНЫЙ ЦИКЛ)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.AutoFarm = true
    
    startNoclip()
    UpdateCenterPosition()
    
    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.AutoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end
        
        -- 1. Проверка сумки
        if IsBagFull() then
            print("[RBS] Сумка полна, фарм остановлен")
            StopAutoFarm()
            if centerPosition then
                FlyToPosition(centerPosition)
            end
            return
        end
        
        -- 2. Поиск монеты
        local targetCoin = FindNearestCoin()
        
        if targetCoin then
            CollectCoin(targetCoin)
            wait(Config.CollectionDelay)
        else
            -- Нет монет → летим под центр карты
            if centerPosition then
                local root = GetRootPart()
                if root and (root.Position - centerPosition).Magnitude > 10 then
                    FlyToPosition(centerPosition)
                end
            end
            wait(0.2)
        end
    end)
    
    print("[RBS] Auto Farm запущен")
    UpdateUI()
end

local function StopAutoFarm()
    if not state.AutoFarm then return end
    state.AutoFarm = false
    
    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    if not state.NoClip then
        stopNoclip()
    end
    
    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ
-- ===========================
local screenGui = nil
local mainFrame = nil

local function CreateMenu()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RBS_MM2_Hub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 260, 0, 170)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(255, 80, 80)
    mainFrame.Parent = screenGui
    
    -- Заголовок
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔪 RBS - MM2 ULTIMATE HUB"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Кнопки
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 230, 0, 35)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 13
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame
    
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 230, 0, 35)
    godModeBtn.Position = UDim2.new(0, 15, 0, 90)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 13
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame
    
    local noclipBtn = Instance.new("TextButton")
    noclipBtn.Size = UDim2.new(0, 230, 0, 35)
    noclipBtn.Position = UDim2.new(0, 15, 0, 135)
    noclipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    noclipBtn.Text = "🔴 NOCLIP: OFF"
    noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noclipBtn.TextSize = 13
    noclipBtn.Font = Enum.Font.GothamBold
    noclipBtn.Parent = mainFrame
    
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
    
    noclipBtn.MouseButton1Click:Connect(function()
        if state.NoClip then
            state.NoClip = false
            if not state.AutoFarm then
                stopNoclip()
            end
            noclipBtn.Text = "🔴 NOCLIP: OFF"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.NoClip = true
            startNoclip()
            noclipBtn.Text = "🟢 NOCLIP: ON"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
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
            end
        end
    end
end

-- ===========================
-- ЗАЩИТА ПРИ РЕСПАВНЕ
-- ===========================
LocalPlayer.CharacterAdded:Connect(function()
    wait(0.8)
    if state.AutoFarm then
        startNoclip()
    end
    if state.GodMode then
        setGodMode(true)
    end
    if state.NoClip then
        startNoclip()
    end
    UpdateCenterPosition()
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔══════════════════════════════════════════════════════════════════╗
║           🔪 MURDER MYSTERY 2 | RBS ULTIMATE HUB 🔪              ║
╠══════════════════════════════════════════════════════════════════╣
║  Управление через GUI меню (левый верхний угол)                 ║
║                                                                 ║
║  ✨ AUTO FARM  - Авто-сбор монет с плавным полётом              ║
║  ✨ GOD MODE   - Полное бессмертие                              ║
║  ✨ NOCLIP     - Проход сквозь стены и пол                      ║
║                                                                 ║
║  Механика фарма:                                                ║
║    • Ближайшая монета → сбор → следующая                       ║
║    • Нет монет → полёт под центр карты                          ║
║    • Сумка полна (40) → остановка фарма                        ║
╚══════════════════════════════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
UpdateUI()
