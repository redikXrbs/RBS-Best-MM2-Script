-- ⚡ RBS - MM2 TEST (v3.0 GUI + Zyn-ic Core) ⚡
-- Только одна кнопка: AUTO FARM

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- НАСТРОЙКИ
-- ===========================
local TWEEN_SPEED = 65
local COLLECT_DELAY = 0.05
local FLY_HEIGHT = -8

-- ===========================
-- СОСТОЯНИЯ
-- ===========================
local autoFarm = false
local currentTween = nil
local farmLoop = nil
local lastCoinCheck = 0
local coinCache = {}

-- ===========================
-- ФУНКЦИИ ZYN-IC (скопированы без изменений)
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

-- NoClip + полёт
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
        hrp.Position = Vector3.new(hrp.Position.X, FLY_HEIGHT, hrp.Position.Z)
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

-- Поиск ближайшей монеты (с кэшем)
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
            local isCoin = name:find("coin") or name:find("money") or name:find("gold") or name:find("cash") or name:find("candy") or name:find("present")
            
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

-- Tween движение
local function FlyToPosition(targetPos)
    local root = GetRootPart()
    if not root then return end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    local dist = (root.Position - targetPos).Magnitude
    local duration = math.max(0.08, dist / TWEEN_SPEED)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    return tween
end

-- Сбор монеты
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

-- Автофарм
local function StartAutoFarm()
    if farmLoop then return end
    autoFarm = true
    SetNoclipFly(true)

    farmLoop = RunService.Stepped:Connect(function()
        if not autoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end

        local coin = GetNearestCoin()
        if coin then
            CollectCoin(coin)
            wait(COLLECT_DELAY)
        else
            wait(0.15)
        end
    end)

    print("[TEST] Auto Farm Запущен")
end

local function StopAutoFarm()
    autoFarm = false

    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    SetNoclipFly(false)
    print("[TEST] Auto Farm Остановлен")
end

-- ===========================
-- GUI ИЗ 3.0 (только одна кнопка AUTO FARM)
-- ===========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RBS_MM2_Ultimate"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 120)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 100, 100)
mainFrame.Parent = screenGui

-- Заголовок (как в 3.0)
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

-- Кнопка AUTO FARM (единственная)
local autoFarmBtn = Instance.new("TextButton")
autoFarmBtn.Size = UDim2.new(0, 220, 0, 40)
autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoFarmBtn.TextSize = 14
autoFarmBtn.Font = Enum.Font.GothamBold
autoFarmBtn.Parent = mainFrame

-- Обработчик кнопки
autoFarmBtn.MouseButton1Click:Connect(function()
    if autoFarm then
        StopAutoFarm()
        autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    else
        StartAutoFarm()
        autoFarmBtn.Text = "🟢 AUTO FARM: ON"
        autoFarmBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    end
end)

-- Перетаскивание окна (как в 3.0)
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
    if autoFarm then
        SetNoclipFly(true)
    end
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE (TEST)            ║
╠═══════════════════════════════════════════╣
║  ✅ GUI из v3.0                          ║
║  ✅ Система Zyn-ic                       ║
║  ✅ Только одна кнопка AUTO FARM         ║
╚═══════════════════════════════════════════╝
]])
