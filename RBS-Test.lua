-- ⚡ MM2 ULTRA FARM | RBS V8 (GUI Version) ⚡

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Настройки
local CONFIG = {
    FlyHeight = -8,         -- Высота полета под картой
    CollectDelay = 0.05,    -- Задержка между сборами
}

-- Состояния
local state = {
    AutoFarm = false,
    GodMode = false,
}

local noclipConnection = nil
local farmLoop = nil
local godModeConnection = nil
local currentTween = nil

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
-- GOD MODE
-- ===========================
local function SetGodMode(enabled)
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if enabled then
        if godModeConnection then godModeConnection:Disconnect() end
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
        if godModeConnection then godModeConnection:Disconnect() end
        godModeConnection = nil
        hum.MaxHealth = 100
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum.BreakJointsOnDeath = true
        if hum.Health > 100 then
            hum.Health = 100
        end
    end
end

-- ===========================
-- NOCLIP + ПОЛЁТ (без гравитации)
-- ===========================
local function SetNoclipFly(enabled)
    local char = GetCharacter()
    local hrp = GetRootPart()
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    if enabled then
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        hum.PlatformStand = true
        hum.AutoRotate = false
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanQuery = false
            end
        end
        
        hrp.Anchored = true
        hrp.Position = Vector3.new(hrp.Position.X, CONFIG.FlyHeight, hrp.Position.Z)
    else
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        hum.PlatformStand = false
        hum.AutoRotate = true
        
        hrp.Anchored = false
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
                part.CanQuery = true
            end
        end
    end
end

-- ===========================
-- ПОИСК МОНЕТ
-- ===========================
local function GetNearestCoin()
    local rootPart = GetRootPart()
    if not rootPart then return nil end
    
    local nearest = nil
    local minDist = math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= GetCharacter() then
            local name = obj.Name:lower()
            if name:find("coin") or name:find("money") or name:find("gold") or 
               name:find("cash") or name:find("beach") or name:find("ball") then
                local dist = (rootPart.Position - obj.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

-- ===========================
-- СБОР МОНЕТЫ (через Tween для плавности)
-- ===========================
local function CollectCoin(coin)
    if not coin or not coin.Parent then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local rootPart = GetRootPart()
    if not rootPart then return end
    
    local distance = (rootPart.Position - coin.Position).Magnitude
    local duration = math.max(0.1, distance / 60)
    
    local tween = TweenService:Create(rootPart, 
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = CFrame.new(coin.Position)})
    
    currentTween = tween
    tween:Play()
    
    tween.Completed:Connect(function()
        local click = coin:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
        end
        local prompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
        currentTween = nil
    end)
end

-- ===========================
-- АВТОФАРМ (ЦИКЛ)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.AutoFarm = true
    
    SetNoclipFly(true)
    
    farmLoop = RunService.Stepped:Connect(function()
        if not state.AutoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end
        
        local coin = GetNearestCoin()
        if coin then
            CollectCoin(coin)
            task.wait(CONFIG.CollectDelay)
        else
            task.wait(0.2)
        end
    end)
    
    print("[RBS] Auto Farm запущен")
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
    
    if not state.GodMode then
        SetNoclipFly(false)
    end
    
    print("[RBS] Auto Farm остановлен")
end

-- ===========================
-- GUI МЕНЮ
-- ===========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RBS_FarmGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 180)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 80, 80)
mainFrame.Parent = screenGui

-- Заголовок с возможностью перетаскивания
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ RBS - ULTRA FARM"
title.TextColor3 = Color3.fromRGB(255, 100, 100)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = titleBar

-- Кнопка Auto Farm
local autoFarmBtn = Instance.new("TextButton")
autoFarmBtn.Size = UDim2.new(0, 230, 0, 40)
autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
autoFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoFarmBtn.TextSize = 14
autoFarmBtn.Font = Enum.Font.GothamBold
autoFarmBtn.Parent = mainFrame

-- Кнопка God Mode
local godModeBtn = Instance.new("TextButton")
godModeBtn.Size = UDim2.new(0, 230, 0, 40)
godModeBtn.Position = UDim2.new(0, 15, 0, 95)
godModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
godModeBtn.Text = "🔴 GOD MODE: OFF"
godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
godModeBtn.TextSize = 14
godModeBtn.Font = Enum.Font.GothamBold
godModeBtn.Parent = mainFrame

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 230, 0, 20)
statusLabel.Position = UDim2.new(0, 15, 0, 145)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "💤 Ожидание"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Обработчики кнопок
autoFarmBtn.MouseButton1Click:Connect(function()
    if state.AutoFarm then
        StopAutoFarm()
        autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        statusLabel.Text = "💤 Фарм остановлен"
        statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        StartAutoFarm()
        autoFarmBtn.Text = "🟢 AUTO FARM: ON"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        statusLabel.Text = "✨ Фарм активен! Летаю за монетами"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end)

godModeBtn.MouseButton1Click:Connect(function()
    if state.GodMode then
        state.GodMode = false
        SetGodMode(false)
        godModeBtn.Text = "🔴 GOD MODE: OFF"
        godModeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    else
        state.GodMode = true
        SetGodMode(true)
        godModeBtn.Text = "🟢 GOD MODE: ON"
        godModeBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
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

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if state.AutoFarm then
        SetNoclipFly(true)
    end
    if state.GodMode then
        SetGodMode(true)
    end
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     ⚡ RBS - ULTRA FARM (GUI) ⚡          ║
╠═══════════════════════════════════════════╣
║  Управление через меню в левом верхнем   ║
║  углу экрана.                            ║
║                                          ║
║  ✅ AUTO FARM - Автосбор монет           ║
║  ✅ GOD MODE  - Бессмертие               ║
║  ✅ NoClip + полёт под картой            ║
╚═══════════════════════════════════════════╝
]])
