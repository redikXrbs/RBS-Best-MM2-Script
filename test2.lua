-- ⚡ MM2 AUTOFARM — GUI TEST VERSION ⚡

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- НАСТРОЙКИ
-- ===========================
local CONFIG = {
    TWEEN_SPEED = 65,
    COLLECT_DELAY = 0.05,
    FLY_HEIGHT = -8,
}

-- ===========================
-- СОСТОЯНИЯ
-- ===========================
local state = {
    autoFarm = false,
    noClip = false,
}

-- ===========================
-- ПЕРЕМЕННЫЕ
-- ===========================
local currentTween = nil
local farmLoop = nil
local lastCoinCheck = 0
local coinCache = {}

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
-- NOCLIP + ПОЛЁТ
-- ===========================
local function SetNoclipFly(enabled)
    local char = GetCharacter()
    local hrp = GetRootPart()
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return

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
        hrp.Position = Vector3.new(hrp.Position.X, CONFIG.FLY_HEIGHT, hrp.Position.Z)
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
-- ПОИСК БЛИЖАЙШЕЙ МОНЕТЫ (с кэшем)
-- ===========================
local function GetNearestCoin()
    local now = tick()
    if now - lastCoinCheck < 0.1 and coinCache[1] then
        return coinCache[1]
    end

    local rootPart = GetRootPart()
    if not rootPart then return nil end

    local nearest = nil
    local minDist = math.huge
    local newCache = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= GetCharacter() then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash")

            if isCoin then
                local dist = (rootPart.Position - obj.Position).Magnitude
                table.insert(newCache, {obj = obj, dist = dist})
                if dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end

    table.sort(newCache, function(a, b) return a.dist < b.dist end)
    coinCache = newCache
    lastCoinCheck = now
    return nearest
end

-- ===========================
-- TWEEN К ПОЗИЦИИ
-- ===========================
local function FlyToPosition(targetPos)
    local root = GetRootPart()
    if not root then return end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    local dist = (root.Position - targetPos).Magnitude
    local duration = math.max(0.08, dist / CONFIG.TWEEN_SPEED)

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

    pcall(function()
        FlyToPosition(coin.Position)
        wait(0.03)

        local click = coin:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
        end

        local prompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.03)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- ===========================
-- АВТОФАРМ (ГЛАВНЫЙ ЦИКЛ)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true

    SetNoclipFly(true)

    farmLoop = RunService.Stepped:Connect(function()
        if not state.autoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end

        local coin = GetNearestCoin()
        if coin then
            CollectCoin(coin)
            wait(CONFIG.COLLECT_DELAY)
        else
            wait(0.15)
        end
    end)

    print("[AUTO FARM] Запущен")
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

    if not state.noClip then
        SetNoclipFly(false)
    end

    print("[AUTO FARM] Остановлен")
end

-- ===========================
-- GUI МЕНЮ (ОДНА ГЛАВНАЯ КНОПКА)
-- ===========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TestFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 180)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 100, 100)
mainFrame.Parent = screenGui

-- Заголовок (для перетаскивания)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ TEST AUTOFARM"
title.TextColor3 = Color3.fromRGB(255, 120, 120)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = titleBar

-- Главная кнопка AUTO FARM
local autoFarmBtn = Instance.new("TextButton")
autoFarmBtn.Size = UDim2.new(0, 210, 0, 45)
autoFarmBtn.Position = UDim2.new(0, 15, 0, 50)
autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoFarmBtn.TextSize = 15
autoFarmBtn.Font = Enum.Font.GothamBold
autoFarmBtn.Parent = mainFrame

-- Кнопка NoClip (опционально, для тестов)
local noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(0, 210, 0, 35)
noclipBtn.Position = UDim2.new(0, 15, 0, 105)
noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
noclipBtn.Text = "🔴 NOCLIP: OFF"
noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipBtn.TextSize = 13
noclipBtn.Font = Enum.Font.GothamBold
noclipBtn.Parent = mainFrame

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 210, 0, 20)
statusLabel.Position = UDim2.new(0, 15, 0, 150)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "💤 Ожидание"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Обработчики
autoFarmBtn.MouseButton1Click:Connect(function()
    if state.autoFarm then
        StopAutoFarm()
        autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        statusLabel.Text = "💤 Фарм остановлен"
        statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        StartAutoFarm()
        autoFarmBtn.Text = "🟢 AUTO FARM: ON"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        statusLabel.Text = "✨ Фарм активен! Сбор монет..."
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end)

noclipBtn.MouseButton1Click:Connect(function()
    if state.noClip then
        state.noClip = false
        if not state.autoFarm then
            SetNoclipFly(false)
        end
        noclipBtn.Text = "🔴 NOCLIP: OFF"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    else
        state.noClip = true
        SetNoclipFly(true)
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

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if state.autoFarm then
        SetNoclipFly(true)
    end
    if state.noClip then
        SetNoclipFly(true)
    end
end)

print([[
╔═══════════════════════════════════════════╗
║     🔪 MM2 AUTOFARM — GUI TEST 🔪         ║
╠═══════════════════════════════════════════╣
║  Управление через меню в левом верхнем   ║
║  углу экрана.                            ║
║                                          ║
║  ✅ AUTO FARM - Автосбор монет           ║
║  ✅ NOCLIP    - Режим полёта            ║
╚═══════════════════════════════════════════╝
]])
