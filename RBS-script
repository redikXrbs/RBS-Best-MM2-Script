-- [[ RBS - MM2 ULTIMATE FARM v3.2 SLOW EDITION ]]
-- Изменения: медленные плавные движения, задержка 2 секунды между монетами

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
local farmActive = false

-- ===========================
-- НАСТРОЙКИ (можно менять)
-- ===========================
local CONFIG = {
    FLY_SPEED = 18,           -- Скорость полета (было 35, теперь 18 - медленнее)
    COLLECTION_DELAY = 2.0,   -- Задержка между монетами в секундах
    RETURN_DELAY = 1.5,       -- Задержка перед возвратом в центр
    CENTER_OFFSET = -8,       -- Смещение под центр карты
    TWEEN_STYLE = Enum.EasingStyle.Quad,  -- Плавное движение
}

-- ===========================
-- ПРОВЕРКА АКТИВНОСТИ РАУНДА
-- ===========================
local function IsRoundActive()
    local players = game.Players:GetPlayers()
    local murdererCount = 0
    local sheriffCount = 0
    
    for _, player in ipairs(players) do
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            local roleFrame = playerGui:FindFirstChild("Role")
            if roleFrame and roleFrame:FindFirstChild("RoleText") then
                local roleText = roleFrame.RoleText.Text or ""
                if roleText:lower():find("murderer") then
                    murdererCount = murdererCount + 1
                elseif roleText:lower():find("sheriff") then
                    sheriffCount = sheriffCount + 1
                end
            end
        end
        
        local character = player.Character
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                if tool.Name:lower():find("knife") then murdererCount = murdererCount + 1 end
                if tool.Name:lower():find("gun") then sheriffCount = sheriffCount + 1 end
            end
        end
    end
    
    local roundActive = murdererCount > 0 or sheriffCount > 0
    
    local character = LocalPlayer.Character
    local isInLobby = false
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart and math.abs(rootPart.Position.Y) > 300 then
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

-- ПОИСК МОНЕТ
local function FindAllCoins()
    local coins = {}
    local rootPart = GetRootPart()
    if not rootPart then return coins end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= LocalPlayer.Character then
            local name = obj.Name:lower()
            local isCoin = false
            
            if name:find("coin") or name:find("money") or name:find("gold") or 
               name:find("cash") or name:find("diamond") or name:find("gem") or
               name == "pickup" or name:find("collect") then
                isCoin = true
            end
            
            if not isCoin and obj.BrickColor then
                local colorName = obj.BrickColor.Name:lower()
                if colorName == "bright yellow" or colorName == "gold" or 
                   colorName == "new yeller" or colorName == "yellow" then
                    isCoin = true
                end
            end
            
            if not isCoin and obj.Size.Magnitude < 5 then
                isCoin = true
            end
            
            if isCoin then
                table.insert(coins, {
                    object = obj,
                    position = obj.Position,
                    distance = (rootPart.Position - obj.Position).Magnitude
                })
            end
        end
    end
    
    table.sort(coins, function(a, b)
        return a.distance < b.distance
    end)
    
    return coins
end

-- ПЛАВНОЕ МЕДЛЕННОЕ ДВИЖЕНИЕ
local function SmoothTweenToPosition(targetPosition)
    local rootPart = GetRootPart()
    if not rootPart then return end
    
    if currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing then
        currentTween:Cancel()
    end
    
    local distance = (rootPart.Position - targetPosition).Magnitude
    local duration = math.max(0.5, distance / CONFIG.FLY_SPEED)  -- Минимум 0.5 секунды для плавности
    
    local tweenInfo = TweenInfo.new(
        duration, 
        CONFIG.TWEEN_STYLE,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )
    
    local newTween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    currentTween = newTween
    
    pcall(function()
        newTween:Play()
    end)
    
    return newTween
end

-- СБОР МОНЕТЫ С ЗАДЕРЖКОЙ
local function CollectCoin(coin)
    if not coin or not coin.object or not coin.object.Parent then
        return false
    end
    
    local success = false
    
    pcall(function()
        -- Медленно летим к монете
        SmoothTweenToPosition(coin.position)
        
        -- Ждем полного прилета (плавно)
        local timeout = 0
        while currentTween and currentTween.PlaybackState == Enum.PlaybackState.Playing and timeout < 30 do
            wait(0.1)
            timeout = timeout + 1
        end
        
        wait(0.15)  -- Небольшая пауза после прилета
        
        -- Попытка сбора
        local clickDetector = coin.object:FindFirstChildWhichIsA("ClickDetector")
        if clickDetector then
            fireclickdetector(clickDetector)
            success = true
        end
        
        local proximityPrompt = coin.object:FindFirstChildWhichIsA("ProximityPrompt")
        if proximityPrompt then
            proximityPrompt:InputHoldBegin()
            wait(0.1)
            proximityPrompt:InputHoldEnd()
            success = true
        end
        
        if not success then
            local rootPart = GetRootPart()
            if rootPart then
                local originalCFrame = rootPart.CFrame
                rootPart.CFrame = coin.object.CFrame
                wait(0.1)
                rootPart.CFrame = originalCFrame
                success = true
            end
        end
    end)
    
    return success
end

-- GOD MODE
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
            if humanoid.Health < math.huge then
                humanoid.Health = math.huge
            end
        end)
        
        humanoid.Died:Connect(function()
            if state.godMode then
                wait(0.1)
                local newHumanoid = GetCharacter():FindFirstChild("Humanoid")
                if newHumanoid then
                    newHumanoid.Health = math.huge
                end
            end
        end)
        
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
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

local function SetCollision(enabled)
    local character = GetCharacter()
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = enabled
            part.CanQuery = enabled
        end
    end
end

-- ОБНОВЛЕНИЕ ЦЕНТРА КАРТЫ
local function UpdateCenterPosition()
    local map = workspace:FindFirstChild("Map")
    if map then
        local primaryPart = map:FindFirstChild("PrimaryPart") or map:FindFirstChild("Baseplate")
        if primaryPart then
            centerPosition = primaryPart.Position + Vector3.new(0, CONFIG.CENTER_OFFSET, 0)
            return
        end
    end
    
    local totalPos = Vector3.new(0, 0, 0)
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 50 then
            totalPos = totalPos + obj.Position
            count = count + 1
        end
    end
    
    if count > 0 then
        centerPosition = (totalPos / count) + Vector3.new(0, CONFIG.CENTER_OFFSET, 0)
    else
        centerPosition = Vector3.new(0, 0, 0)
    end
end

-- AUTO FARM С МЕДЛЕННЫМ СБОРОМ
local function StartAutoFarm()
    if farmActive then return end
    state.autoFarm = true
    farmActive = true
    
    SetCollision(false)
    
    print("[RBS] Auto Farm запущен (медленный режим, задержка " .. CONFIG.COLLECTION_DELAY .. " сек)")
    UpdateUI()
    
    spawn(function()
        while state.autoFarm do
            if not IsRoundActive() then
                wait(1)
                goto continue
            end
            
            if state.godMode then
                SetGodMode(true)
            end
            
            UpdateCenterPosition()
            
            local coins = FindAllCoins()
            
            if #coins > 0 then
                isCollecting = true
                
                for index, coin in ipairs(coins) do
                    if not state.autoFarm then break end
                    
                    if coin.object and coin.object.Parent then
                        local success = CollectCoin(coin)
                        
                        if success then
                            print("[RBS] Монета собрана, ждем " .. CONFIG.COLLECTION_DELAY .. " сек...")
                            
                            -- ЗАДЕРЖКА 2 СЕКУНДЫ МЕЖДУ МОНЕТАМИ
                            local delayStart = tick()
                            while state.autoFarm and (tick() - delayStart) < CONFIG.COLLECTION_DELAY do
                                wait(0.1)
                            end
                        end
                    end
                end
                
                isCollecting = false
                
                -- Возврат в центр после всех монет
                if state.autoFarm and centerPosition then
                    local remainingCoins = #FindAllCoins()
                    if remainingCoins == 0 then
                        wait(CONFIG.RETURN_DELAY)
                        local rootPart = GetRootPart()
                        if rootPart and centerPosition and (rootPart.Position - centerPosition).Magnitude > 15 then
                            SmoothTweenToPosition(centerPosition)
                        end
                    end
                end
            else
                -- Нет монет - медленно летим в центр
                if centerPosition then
                    local rootPart = GetRootPart()
                    if rootPart and (rootPart.Position - centerPosition).Magnitude > 15 then
                        SmoothTweenToPosition(centerPosition)
                    end
                end
                wait(0.5)
            end
            
            ::continue::
            wait(0.1)
        end
        
        farmActive = false
        isCollecting = false
        SetCollision(true)
    end)
end

local function StopAutoFarm()
    state.autoFarm = false
    
    local timeout = 0
    while farmActive and timeout < 30 do
        wait(0.1)
        timeout = timeout + 1
    end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    SetCollision(true)
    
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
    screenGui.Name = "RBS_MM2_Ultimate"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 260, 0, 160)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(255, 80, 80)
    mainFrame.Parent = screenGui
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🐢 RBS - MM2 SLOW FARM v3.2"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    local autoFarmBtn = Instance.new("TextButton")
    autoFarmBtn.Size = UDim2.new(0, 230, 0, 40)
    autoFarmBtn.Position = UDim2.new(0, 15, 0, 40)
    autoFarmBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    autoFarmBtn.Text = "🔴 AUTO FARM: OFF"
    autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFarmBtn.TextSize = 14
    autoFarmBtn.Font = Enum.Font.GothamBold
    autoFarmBtn.Parent = mainFrame
    
    local godModeBtn = Instance.new("TextButton")
    godModeBtn.Size = UDim2.new(0, 230, 0, 40)
    godModeBtn.Position = UDim2.new(0, 15, 0, 90)
    godModeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    godModeBtn.Text = "🔴 GOD MODE: OFF"
    godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    godModeBtn.TextSize = 14
    godModeBtn.Font = Enum.Font.GothamBold
    godModeBtn.Parent = mainFrame
    
    -- Индикатор задержки
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0, 230, 0, 20)
    delayLabel.Position = UDim2.new(0, 15, 0, 135)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Text = "⏱️ Задержка: " .. CONFIG.COLLECTION_DELAY .. " сек"
    delayLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    delayLabel.TextSize = 11
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.Parent = mainFrame
    
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
    
    -- Перетаскивание
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
            end
        end
    end
end

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(0.8)
    
    if state.autoFarm then
        SetCollision(false)
        if farmActive then
            state.autoFarm = false
            wait(0.5)
            state.autoFarm = true
            StartAutoFarm()
        end
    end
    
    if state.godMode then
        SetGodMode(true)
    end
    
    UpdateCenterPosition()
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔═══════════════════════════════════════════╗
║     RBS - MM2 SLOW FARM v3.2             ║
╠═══════════════════════════════════════════╣
║  Настройки:                              ║
║    🐢 Скорость полета: 18 (медленно)     ║
║    ⏱️ Задержка между монетами: 2 сек     ║
║    🎯 Плавные движения Quad              ║
╚═══════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
