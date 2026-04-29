-- ⚡ RBS - MM2 ULTIMATE FARM (Working Version) ⚡

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
local AutoFarm = false
local GodMode = false
local NoClip = false

-- ===========================
-- ПЕРЕМЕННЫЕ
-- ===========================
local currentTween = nil
local farmLoop = nil
local noclipConnection = nil
local godModeConnection = nil
local lastCoinCheck = 0
local coinCache = {}

-- ===========================
-- ФУНКЦИИ
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

local function SetGodMode(enabled)
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return

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

local function StartAutoFarm()
    if farmLoop then return end
    AutoFarm = true
    SetNoclipFly(true)

    farmLoop = RunService.Stepped:Connect(function()
        if not AutoFarm then
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

    print("[RBS] Auto Farm запущен")
end

local function StopAutoFarm()
    AutoFarm = false

    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    if not NoClip then
        SetNoclipFly(false)
    end

    print("[RBS] Auto Farm остановлен")
end

-- ===========================
-- GUI МЕНЮ (УПРОЩЁННОЕ, ГАРАНТИРОВАННО РАБОТАЕТ)
-- ===========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RBS_Farm"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 150)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 100, 100)
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
title.Text = "RBS - MM2 FARM"
title.TextColor3 = Color3.fromRGB(255, 120, 120)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = frame

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(0, 220, 0, 35)
autoBtn.Position = UDim2.new(0, 15, 0, 40)
autoBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
autoBtn.Text = "🔴 AUTO FARM: OFF"
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.TextSize = 13
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Parent = frame

local godBtn = Instance.new("TextButton")
godBtn.Size = UDim2.new(0, 220, 0, 35)
godBtn.Position = UDim2.new(0, 15, 0, 80)
godBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
godBtn.Text = "🔴 GOD MODE: OFF"
godBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
godBtn.TextSize = 13
godBtn.Font = Enum.Font.GothamBold
godBtn.Parent = frame

local noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(0, 220, 0, 35)
noclipBtn.Position = UDim2.new(0, 15, 0, 120)
noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
noclipBtn.Text = "🔴 NOCLIP: OFF"
noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipBtn.TextSize = 13
noclipBtn.Font = Enum.Font.GothamBold
noclipBtn.Parent = frame

autoBtn.MouseButton1Click:Connect(function()
    if AutoFarm then
        StopAutoFarm()
        autoBtn.Text = "🔴 AUTO FARM: OFF"
        autoBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    else
        StartAutoFarm()
        autoBtn.Text = "🟢 AUTO FARM: ON"
        autoBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    end
end)

godBtn.MouseButton1Click:Connect(function()
    if GodMode then
        GodMode = false
        SetGodMode(false)
        godBtn.Text = "🔴 GOD MODE: OFF"
        godBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    else
        GodMode = true
        SetGodMode(true)
        godBtn.Text = "🟢 GOD MODE: ON"
        godBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
    end
end)

noclipBtn.MouseButton1Click:Connect(function()
    if NoClip then
        NoClip = false
        if not AutoFarm then
            SetNoclipFly(false)
        end
        noclipBtn.Text = "🔴 NOCLIP: OFF"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    else
        NoClip = true
        SetNoclipFly(true)
        noclipBtn.Text = "🟢 NOCLIP: ON"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    end
end)

-- Перетаскивание
local dragging = false
local dragStart = nil
local framePos = nil

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        framePos = frame.Position
    end
end)

frame.InputEnded:Connect(function()
    dragging = false
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
    end
end)

print("RBS Farm loaded - Click buttons to start")
