-- [[ RBS - MM2 ULTIMATE FARM v3.0 (WORKING NOCLIP ONLY) ]]
-- Оригинальная версия 3.0 + проверенный NoClip (без доработок)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- СОСТОЯНИЯ (НЕ МЕНЯЛИ)
-- ===========================
local state = {
    autoFarm = false,
    godMode = false,
    noclip = false,              -- Добавлена кнопка NoClip
}

-- Глобальные переменные (из v3.0)
local centerPosition = nil
local isCollecting = false
local currentTween = nil
local farmLoop = nil
local godModeConnection = nil

-- ===========================
-- ⭐ РАБОЧИЙ NOCLIP (ПРОВЕРЕННЫЙ)
-- ===========================
local noclipConnection = nil

local function applyWorkingNoclip()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- Отключаем коллизию у всех частей тела
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
        end
    end
    
    -- БЛОКИРУЕМ КАРАБКАНЬЕ (рабочий фикс)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        humanoid.AutoRotate = false
        humanoid.HipHeight = 0
    end
end

local function startWorkingNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    noclipConnection = RunService.Stepped:Connect(function()
        if state.noclip or state.autoFarm then
            applyWorkingNoclip()
        end
    end)
end

local function stopWorkingNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

-- ===========================
-- ОСТАЛЬНЫЕ ФУНКЦИИ (ОРИГИНАЛ v3.0, БЕЗ ПРАВОК)
-- ===========================

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
    end
end

-- ===========================
-- AUTO FARM (ОРИГИНАЛ)
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.autoFarm = true

    startWorkingNoclip()

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

    if not state.noclip then
        stopWorkingNoclip()
    end

    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (оригинал + кнопка NoClip)
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
    autoFarmBtn.Size = UDim2.new(0, 220, 0, 35)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 40)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 13
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame

    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 220, 0, 35)
    godModeBtn.Position = UDim2.new(0, 15, 0, 80)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 13
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame

    local noclipBtn = Instance.new("TextButton")
    noclipBtn.Size = UDim2.new(0, 220, 0, 35)
    noclipBtn.Position = UDim2.new(0, 15, 0, 120)
    noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    noclipBtn.Text = "🔴 NOCLIP: OFF"
    noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noclipBtn.TextSize = 13
    noclipBtn.Font = Enum.Font.GothamBold
    noclipBtn.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 220, 0, 30)
    closeBtn.Position = UDim2.new(0, 15, 0, 160)
    closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    closeBtn.Text = "✖ HIDE MENU"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame

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
            godModeBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
        end
    end)

    noclipBtn.MouseButton1Click:Connect(function()
        if state.noclip then
            state.noclip = false
            if not state.autoFarm then
                stopWorkingNoclip()
            end
            noclipBtn.Text = "🔴 NOCLIP: OFF"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        else
            state.noclip = true
            startWorkingNoclip()
            noclipBtn.Text = "🟢 NOCLIP: ON"
            noclipBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
        end
    end)

    local menuVisible = true
    closeBtn.MouseButton1Click:Connect(function()
        menuVisible = not menuVisible
        mainFrame.Visible = menuVisible
        closeBtn.Text = menuVisible and "✖ HIDE MENU" or "☰ SHOW MENU"
        closeBtn.BackgroundColor3 = menuVisible and Color3.fromRGB(100, 50, 50) or Color3.fromRGB(50, 100, 50)
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
                btn.Text = state.autoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.autoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(80, 80, 100)
            elseif text:find("GOD MODE") then
                btn.Text = state.godMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.godMode and Color3.fromRGB(100, 60, 100) or Color3.fromRGB(80, 80, 100)
            elseif text:find("NOCLIP") then
                btn.Text = state.noclip and "🟢 NOCLIP: ON" or "🔴 NOCLIP: OFF"
                btn.BackgroundColor3 = state.noclip and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(80, 80, 100)
            end
        end
    end
end

-- ===========================
-- ЗАЩИТА ПРИ РЕСПАВНЕ
-- ===========================
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(0.5)
    if state.autoFarm or state.noclip then
        startWorkingNoclip()
    end
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
╔═══════════════════════════════════════════════════════════════════╗
║     RBS - MM2 ULTIMATE FARM v3.0 (WORKING NOCLIP)                ║
╠═══════════════════════════════════════════════════════════════════╣
║  ✅ Только проверенный NoClip (фикс карабканья)                  ║
║  ✅ Оригинальная механика v3.0 без изменений                     ║
║  ✅ Отдельная кнопка NoClip в GUI                                ║
╚═══════════════════════════════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
