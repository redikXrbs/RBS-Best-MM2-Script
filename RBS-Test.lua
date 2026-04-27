-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║                    🔪 MURDER MYSTERY 2 | RBS ULTIMATE HUB 🔪                   ║
-- ║                        Версия 5.0 | Стабильный фарм                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- [[ СИСТЕМА ЗАИМСТВОВАНА ИЗ ТОПОВЫХ ХАБОВ:
--      Eclipse Hub - Оптимизация и стабильность
--      Onyx Hub - Система телепортации и GUI
--      Vertex Hub - Авто-фарм и механики боя
--      OP GUI (U-ziii) - Система NoClip и God Mode
--      Moondiety - Защита от падения и плавность ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- КОНФИГУРАЦИЯ (можно менять под себя)
-- ===========================
local Config = {
    TweenSpeed = 55,           -- Скорость полета (высокая для плавности)
    CollectionDelay = 0.08,    -- Задержка между монетами (почти мгновенно)
    CenterOffset = -6,         -- Смещение под картой
    AntiFallHeight = -15,      -- Высота для анти-пада
}

-- ===========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ===========================
local state = {
    AutoFarm = false,
    GodMode = false,
    NoClip = false,
    InfiniteJump = false,
}

local centerPosition = nil
local currentTween = nil
local farmLoop = nil
local godModeConnection = nil
local infiniteJumpConn = nil
local originalHealth = nil

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

-- ОПРЕДЕЛЕНИЕ АКТИВНОГО РАУНДА (из OP GUI и Eclipse) [citation:2][citation:4]
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

-- ===========================
-- СИСТЕМА NOClip (из OP GUI и Moondiety) [citation:2][citation:6]
-- ===========================
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

-- ===========================
-- GOD MODE (из Onyx Hub и Moondiety) [citation:4][citation:6]
-- ===========================
local function setGodMode(enabled)
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if enabled then
        if godModeConnection then
            godModeConnection:Disconnect()
        end
        
        originalHealth = hum.Health
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

-- ===========================
-- INFINITE JUMP (из Eclipse Hub) [citation:4]
-- ===========================
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

-- ===========================
-- ПОЛУЧЕНИЕ ЦЕНТРА КАРТЫ (из Onyx Hub) [citation:4]
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
    
    -- Fallback: ищем самую большую часть
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
-- ПОИСК МОНЕТ (оптимизировано)
-- ===========================
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

-- ===========================
-- TWEEN СИСТЕМА (плавный полет)
-- ===========================
local function TweenToPosition(targetPos)
    local root = GetRootPart()
    if not root then return end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    local dist = (root.Position - targetPos).Magnitude
    local duration = math.max(0.1, dist / Config.TweenSpeed)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    return tween
end

-- ===========================
-- СБОР МОНЕТЫ (мгновенный)
-- ===========================
local function CollectCoin(coinObj)
    pcall(function()
        TweenToPosition(coinObj.Position)
        wait(0.03)
        
        local click = coinObj:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
            return
        end
        
        local prompt = coinObj:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.03)
            prompt:InputHoldEnd()
        end
    end)
end

-- ===========================
-- АНТИ-ПАДЕНИЕ (из Moondiety) [citation:6]
-- ===========================
local antiFallConn = nil
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
-- AUTO FARM СИСТЕМА (из Vertex и Eclipse) [citation:4]
-- ===========================
local function StartAutoFarm()
    if farmLoop then return end
    state.AutoFarm = true
    
    setNoClip(true)
    startAntiFall()
    
    farmLoop = RunService.RenderStepped:Connect(function()
        if not state.AutoFarm then
            farmLoop:Disconnect()
            farmLoop = nil
            return
        end
        
        if not IsRoundActive() then
            wait(1)
            return
        end
        
        UpdateCenterPosition()
        
        local coins = FindAllCoins()
        
        if #coins > 0 then
            for _, coin in ipairs(coins) do
                if not state.AutoFarm then break end
                if coin.obj and coin.obj.Parent then
                    CollectCoin(coin.obj)
                    wait(Config.CollectionDelay)
                end
            end
            
            if state.AutoFarm and centerPosition then
                local root = GetRootPart()
                if root and #FindAllCoins() == 0 and (root.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
        else
            if centerPosition then
                local root = GetRootPart()
                if root and (root.Position - centerPosition).Magnitude > 15 then
                    TweenToPosition(centerPosition)
                end
            end
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
    
    if antiFallConn then
        antiFallConn:Disconnect()
        antiFallConn = nil
    end
    
    if not state.GodMode and not state.NoClip then
        setNoClip(false)
    end
    
    print("[RBS] Auto Farm остановлен")
    UpdateUI()
end

-- ===========================
-- GUI МЕНЮ (объединяющий все фичи)
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
    mainFrame.Size = UDim2.new(0, 270, 0, 230)
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
    local buttons = {
        {name = "Auto Farm", posY = 45, colorOn = Color3.fromRGB(60, 100, 60)},
        {name = "God Mode", posY = 85, colorOn = Color3.fromRGB(100, 60, 100)},
        {name = "NoClip", posY = 125, colorOn = Color3.fromRGB(60, 80, 120)},
        {name = "Infinite Jump", posY = 165, colorOn = Color3.fromRGB(100, 80, 60)},
    }
    
    local toggleButtons = {}
    
    for _, btnData in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 240, 0, 32)
        btn.Position = UDim2.new(0, 15, 0, btnData.posY)
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        btn.Text = "🔴 " .. btnData.name .. ": OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.Parent = mainFrame
        toggleButtons[btnData.name] = btn
    end
    
    -- Обработчики
    toggleButtons["Auto Farm"].MouseButton1Click:Connect(function()
        if state.AutoFarm then
            StopAutoFarm()
            toggleButtons["Auto Farm"].Text = "🔴 AUTO FARM: OFF"
            toggleButtons["Auto Farm"].BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            StartAutoFarm()
            toggleButtons["Auto Farm"].Text = "🟢 AUTO FARM: ON"
            toggleButtons["Auto Farm"].BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        end
    end)
    
    toggleButtons["God Mode"].MouseButton1Click:Connect(function()
        if state.GodMode then
            state.GodMode = false
            setGodMode(false)
            toggleButtons["God Mode"].Text = "🔴 GOD MODE: OFF"
            toggleButtons["God Mode"].BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.GodMode = true
            setGodMode(true)
            toggleButtons["God Mode"].Text = "🟢 GOD MODE: ON"
            toggleButtons["God Mode"].BackgroundColor3 = Color3.fromRGB(100, 60, 100)
        end
    end)
    
    toggleButtons["NoClip"].MouseButton1Click:Connect(function()
        if state.NoClip then
            state.NoClip = false
            setNoClip(false)
            toggleButtons["NoClip"].Text = "🔴 NOCLIP: OFF"
            toggleButtons["NoClip"].BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.NoClip = true
            setNoClip(true)
            toggleButtons["NoClip"].Text = "🟢 NOCLIP: ON"
            toggleButtons["NoClip"].BackgroundColor3 = Color3.fromRGB(60, 80, 120)
        end
    end)
    
    toggleButtons["Infinite Jump"].MouseButton1Click:Connect(function()
        if state.InfiniteJump then
            state.InfiniteJump = false
            setInfiniteJump(false)
            toggleButtons["Infinite Jump"].Text = "🔴 INFINITE JUMP: OFF"
            toggleButtons["Infinite Jump"].BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        else
            state.InfiniteJump = true
            setInfiniteJump(true)
            toggleButtons["Infinite Jump"].Text = "🟢 INFINITE JUMP: ON"
            toggleButtons["Infinite Jump"].BackgroundColor3 = Color3.fromRGB(100, 80, 60)
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
            local text = btn.Text
            if text:find("AUTO FARM") then
                btn.Text = state.AutoFarm and "🟢 AUTO FARM: ON" or "🔴 AUTO FARM: OFF"
                btn.BackgroundColor3 = state.AutoFarm and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(70, 70, 90)
            elseif text:find("GOD MODE") then
                btn.Text = state.GodMode and "🟢 GOD MODE: ON" or "🔴 GOD MODE: OFF"
                btn.BackgroundColor3 = state.GodMode and Color3.fromRGB(100, 60, 100) or Color3.fromRGB(70, 70, 90)
            elseif text:find("NOCLIP") then
                btn.Text = state.NoClip and "🟢 NOCLIP: ON" or "🔴 NOCLIP: OFF"
                btn.BackgroundColor3 = state.NoClip and Color3.fromRGB(60, 80, 120) or Color3.fromRGB(70, 70, 90)
            elseif text:find("INFINITE JUMP") then
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
╔══════════════════════════════════════════════════════════════════╗
║           🔪 MURDER MYSTERY 2 | RBS ULTIMATE HUB 🔪              ║
╠══════════════════════════════════════════════════════════════════╣
║  Вдохновлено: Eclipse Hub | Onyx Hub | Vertex Hub | OP GUI       ║
╠══════════════════════════════════════════════════════════════════╣
║  ✨ Auto Farm      - Авто-сбор монет с плавным полетом           ║
║  ✨ God Mode       - Полное бессмертие                           ║
║  ✨ NoClip         - Прохождение сквозь стены                    ║
║  ✨ Infinite Jump  - Бесконечные прыжки                          ║
╚══════════════════════════════════════════════════════════════════╝
]])

CreateMenu()
UpdateCenterPosition()
UpdateUI()

-- Подсказка по кнопкам
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "RBS ULTIMATE HUB",
    Text = "Все функции активируются через GUI меню!\nAuto Farm + God Mode + NoClip + Infinite Jump",
    Duration = 5
})
