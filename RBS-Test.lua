-- ⚡ MM2 CORE FARM SYSTEM (by Zyn-ic) - для вставки в любой GUI
-- Источник: https://github.com/Zyn-ic/MM2-AutoFarm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- НАСТРОЙКИ
-- ===========================
local CONFIG = {
    TWEEN_SPEED = 65,        -- скорость полёта (65-75 оптимально)
    COLLECT_DELAY = 0.05,    -- задержка между монетами
    FLY_HEIGHT = -8,         -- высота полёта под картой
}

-- ===========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ===========================
local state = {
    AutoFarm = false,
    Noclip = false,
    GodMode = false,
}

local currentTween = nil
local farmLoop = nil
local noclipConnection = nil
local godModeConnection = nil

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
-- ⭐ NOCLIP + ПОЛЁТ (БЕЗ ГРАВИТАЦИИ)
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
-- ⭐ ПОИСК БЛИЖАЙШЕЙ МОНЕТЫ (ОПТИМИЗИРОВАН)
-- ===========================
local lastCoinCheck = 0
local coinCache = {}

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
            -- Расширенный список названий монет
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
-- ⭐ ПЛАВНЫЙ TWEEN (ОТЛИЧАЕТСЯ ОТ СТАНДАРТНОГО)
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
    
    -- Linear + Out для идеального скольжения
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    return tween
end

-- ===========================
-- ⭐ СБОР МОНЕТЫ (ОСНОВНАЯ МЕХАНИКА)
-- ===========================
local function CollectCoin(coin)
    if not coin or not coin.Parent then return false end
    
    local success = false
    pcall(function()
        FlyToPosition(coin.Position)
        wait(0.03)
        
        -- ClickDetector
        local click = coin:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
            success = true
        end
        
        -- ProximityPrompt
        local prompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.03)
            prompt:InputHoldEnd()
            success = true
        end
        
        -- Если ничего не сработало — телепортируемся прямо на монету (триггер через касание)
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
-- ⭐ GOD MODE (ОТДЕЛЬНЫЙ, НЕ ВЛИЯЕТ НА ФАРМ)
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
-- ⭐ АВТОФАРМ (ГЛАВНЫЙ ЦИКЛ)
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
    
    if not state.Noclip then
        SetNoclipFly(false)
    end
    
    print("[RBS] Auto Farm остановлен")
end

-- ===========================
-- ЭКСПОРТ ДЛЯ ТВОЕГО GUI
-- ===========================
return {
    StartAutoFarm = StartAutoFarm,
    StopAutoFarm = StopAutoFarm,
    SetGodMode = SetGodMode,
    SetNoclipFly = SetNoclipFly,
    GetState = function() return state end,
}
