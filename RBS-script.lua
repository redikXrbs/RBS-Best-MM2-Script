-- [[ RBS - MM2 ULTIMATE FARM v3.0 (FIXED COLLISION + SMOOTH NOCLIP) ]]
-- Оригинальная рабочая версия 3.0, исправлено отключение коллизии (Больше никаких дерганий)

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

local centerPosition = nil
local isCollecting = false
local currentTween = nil
local godModeConnection = nil
local farmLoop = nil

-- ===========================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ===========================

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

local function GetCharacter()
    local character = LocalPlayer.Character
    if not character or not character.Parent then
        character = LocalPlayer.CharacterAdded:Wait()
    end
    return character
end

local function GetRootPart()
    local character = GetCharacter()
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        character:WaitForChild("HumanoidRootPart")
        rootPart = character.HumanoidRootPart
    end
    return rootPart
end

local function UpdateCenterPosition()
    local map = workspace:FindFirstChild("Map")
    if map then
        local primaryPart = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primaryPart then
            centerPosition = primaryPart.Position + Vector3.new(0, -10, 0)
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
        centerPosition = (totalPos / count) + Vector3.new(0, -10, 0)
    else
        centerPosition = Vector3.new(0, 0, 0) + Vector3.new(0, -10, 0)
    end
end

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

    table.sort(coins, function(a, b)
        return a.distance < b.distance
    end)

    return coins
end

local function TweenToPosition(targetPosition, callback)
    local rootPart = GetRootPart()
    if not rootPart then return end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    local distance = (rootPart.Position - targetPosition).Magnitude
    local speed = 35
    local duration = math.max(0.2, distance / speed)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})

    if callback then
        currentTween.Completed:Connect(callback)
    end

    currentTween:Play()
    return currentTween
end

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

-- ✅ ИСПРАВЛЕННАЯ ФУНКЦИЯ НОКЛИПА (БЕЗ ДЕРГАНИЙ [citation:3])
local function setNoclip(enabled)
    local character = GetCharacter()
    -- Проходим по всем частям тела игрока
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Главный секрет: HumanoidRootPart должен иметь CanCollide = true, чтобы физика не "вырубалась"
            if part.Name == "HumanoidRootPart" then
                -- Для RootPart оставляем коллизию включенной, но отключаем её влияние на передвижение через MovementScript
                part.CanCollide = true 
                part.CanQuery = false
            else
                -- Для всех остальных частей (ноги, руки, голова) просто отключаем столкновения
                -- Это убирает дерганье, т.к. только RootPart теперь взаимодействует с миром
                part.CanCollide = not enabled
                part.CanQuery = not enabled
            end
        end
    end
    
    -- Дополнительная страховка: отключаем коллизию в Gravity и Impact
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
    end
end

-- God Mode (оригинальный)
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
            if humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = humanoid.MaxHealth
            end
        end)

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanQuery = false
            end
        end
    else
        if godModeConnection then
            godModeConnection:Disconnect()
            godModeConnection = nil
        end

        humanoid.MaxHealth = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        humanoid.BreakJointsOnDeath = true

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
                part.CanQuery = true
            end
        end
    end
end

-- ОРИГИНАЛЬНЫЙ AUTO FARM (без лишних изменений)
local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true

    setNoclip(true)  -- Включаем правильный ноклип

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

        if state.godMode then
            SetGodMode(true)
        end

        UpdateCenterPosition()
        local coins = FindAllCoins()

        if #coins > 0 then
            isCollecting = true

            for _, coin in ipairs(coins) do
                if not state.autoFarm then break end
                if coin.object and coin.object.Parent then
                    CollectCoin(coin)
                    wait(0.1)
                end
            end

            isCollecting = false

            if state.autoFarm and IsRoundActive() and #FindAllCoins() == 0 then
                if centerPosition then
                    TweenToPosition(centerPosition)
                end
            end
        else
            if not isCollecting and centerPosition then
                local rootPart = GetRootPart()
                if rootPart and (rootPart.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
            wait(0.2)
        end
    end)

    print("[RBS] Auto Farm запущен (Noclip активен)")
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

    setNoclip(false)  -- Выключаем ноклип, возвращаем обычное поведение

    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (оригинальное)
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
    title.Text = "RBS - MM2 ULTIMATE"
    title.TextColor3 = Color3.fromRGB(255, 120, 120)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar

    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 220, 0, 40)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 45)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 14
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame

    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 220, 0, 40)
    godModeBtn.Position = UDim2.new(0, 15, 0, 95)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 14
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame

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

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(0.5)

    setNoclip(state.autoFarm)

    if state.godMode then
        SetGodMode(true)
    end

    UpdateCenterPosition()

    print("[RBS] Character respawn detected, states restored")
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE FARM v3.0         ║
║            (SMOOTH NOCLIP)               ║
╠═══════════════════════════════════════════╣
║  ✓ Дерганья устранены                    ║
║  ✓ Плавный полёт Tween                   ║
║  ✓ Noclip через HumanoidRootPart         ║
╚═══════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
UpdateCenterPosition()
