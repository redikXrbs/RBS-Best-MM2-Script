-- ⚡ RBS - MM2 ULTIMATE FARM (Classic v3.0 Style GUI) ⚡
-- Рабочая система автофарма Zyn-ic + старый дизайн GUI

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
    AutoFarm = false,
    GodMode = false,
    NoClip = false,
}

-- ===========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ===========================
local currentTween = nil
local farmLoop = nil
local noclipConnection = nil
local godModeConnection = nil
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
-- ПОИСК БЛИЖАЙШЕЙ МОНЕТЫ (С КЭШЕМ)
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
            local isCoin = name:find("coin") or name:find("money") or 
                          name:find("gold") or name:find("cash") or
                          name:find("snow") or name:find("token") or
                          name:find("beach") or name:find("ball") or
                          name:find("candy") or name:find("present")

            if not isCoin and obj.BrickColor then
                local color = obj.BrickColor.Name:lower()
                isCoin = color == "bright yellow" or color == "gold" or 
                         color == "new yeller" or color == "pastel yellow"
            end

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
-- ПЛАВНЫЙ TWEEN
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

        if not success then
            local root = GetRootPart()
            if root then
                local oldPos = root.Position
                root.CFrame = coin.CFrame
                wait(0.02)
                root.CFrame = CFrame.new(oldPos)
                success = true
            end
        end
    end)
    return success
end

-- ===========================
-- GOD MODE
-- ===========================
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

-- ===========================
-- АВТОФАРМ
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
            wait(CONFIG.COLLECT_DELAY)
        else
            wait(0.15)
        end
    end)

    print("[RBS] Auto Farm запущен")
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

    if not state.NoClip then
        SetNoclipFly(false)
    end

    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI В СТИЛЕ СТАРОЙ ВЕРСИИ (v3.0)
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
    mainFrame.Size = UDim2.new(0, 250, 0, 190)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(255, 100, 100)
    mainFrame.Parent = screenGui

    -- Заголовок (как в старом скрипте)
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

    -- Кнопка Auto Farm
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 220, 0, 35)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 13
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame

    -- Кнопка God Mode
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 220, 0, 35)
    godModeBtn.Position = UDim2.new(0, 15, 0, 85)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 13
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame

    -- Кнопка NoClip
    local noclipBtn = Instance.new("TextButton")
    noclipBtn.Size = UDim2.new(0, 220, 0, 35)
    noclipBtn.Position = UDim2.new(0, 15, 0, 125)
    noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    noclipBtn.Text = "🔴 NOCLIP: OFF"
    noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noclipBtn.TextSize = 13
    noclipBtn.Font = Enum.Font.GothamBold
    noclipBtn.Parent = mainFrame

    -- Кнопка сворачивания (как в старом скрипте)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 220, 0, 25)
    closeBtn.Position = UDim2.new(0, 15, 0, 165)
    closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    closeBtn.Text = "✖ HIDE MENU"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 11
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame

    -- Обработчики
    autoFarmBtn.MouseButton1Click:Connect(function()
        if state.AutoFarm then
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
        if state.GodMode then
            state.GodMode = false
            SetGodMode(false)
            godModeBtn.Text = "🔴 GOD MODE: OFF"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            state.GodMode = true
            SetGodMode(true)
            godModeBtn.Text = "🟢 GOD MODE: ON"
            godModeBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
        end
        UpdateUI()
    end)

    noclipBtn.MouseButton1Click:Connect(function()
        if state.NoClip then
            state.NoClip = false
            if not state.AutoFarm then
                SetNoclipFly(false)
            end
            noclipBtn.Text = "🔴 NOCLIP: OFF"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            state.NoClip = true
            SetNoclipFly(true)
            noclipBtn.Text = "🟢 NOCLIP: ON"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
        end
        UpdateUI()
    end)

    -- Сворачивание меню
    local menuVisible = true
    closeBtn.MouseButton1Click:Connect(function()
        menuVisible = not menuVisible
        mainFrame.Visible = menuVisible
        closeBtn.Text = menuVisible and "✖ HIDE MENU" or "☰ SHOW MENU"
        closeBtn.BackgroundColor3 = menuVisible and Color3.fromRGB(100, 50, 50) or Color3.fromRGB(50, 100, 50)
    end)

    -- Перетаскивание окна (как в старом скрипте)
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
            local text = btn.Text
            if text:find("AUTO FARM") then
                btn.Text = state.AutoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.AutoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            elseif text:find("GOD MODE") then
                btn.Text = state.GodMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.GodMode and Color3.fromRGB(100, 60, 100) or Color3.fromRGB(80, 80, 100)
            elseif text:find("NOCLIP") then
                btn.Text = state.NoClip and "🟢 NOCLIP: ON" or "🔴 NOCLIP: OFF"
                btn.BackgroundColor3 = state.NoClip and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(80, 80, 100)
            end
        end
    end
end

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if state.AutoFarm then
        SetNoclipFly(true)
    end
    if state.GodMode then
        SetGodMode(true)
    end
    if state.NoClip then
        SetNoclipFly(true)
    end
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE FARM (Classic GUI)║
╠═══════════════════════════════════════════╣
║  ✅ Тот же дизайн, что в v3.0            ║
║  ✅ Рабочая система Zyn-ic Core          ║
║  ✅ Плавный Tween + NoClip               ║
║  ✅ Кнопка HIDE MENU для сворачивания    ║
╚═══════════════════════════════════════════╝
]])

CreateMenu()
UpdateUI()
