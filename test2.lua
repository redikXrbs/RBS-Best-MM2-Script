--[[
    MM2 AutoFarm — Clean Test Script
    Источник: Zyn-ic MM2-AutoFarm (Open Source)
    Лицензия: MIT
    Активация: нажми F
    
    Система работает через Tween к ближайшей монете
    Использует кэширование для оптимизации
    Требуется только Delta/Solara/любой Executor
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- НАСТРОЙКИ (меняй под себя)
-- ============================================================
local CONFIG = {
    TWEEN_SPEED = 65,        -- скорость полёта (65-75)
    COLLECT_DELAY = 0.05,    -- задержка между сборами
    ACTIVATION_KEY = "F",    -- клавиша вкл/выкл
    FLY_HEIGHT = -8,         -- высота полёта под картой
    ENABLE_NOCLIP = true,    -- отключать коллизию
}

-- ============================================================
-- СОСТОЯНИЯ
-- ============================================================
local isActive = false
local currentTween = nil
local farmConnection = nil
local coinCache = {}
local lastCacheUpdate = 0

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
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

-- ============================================================
-- NOCLIP + ПОЛЁТ (опционально)
-- ============================================================
local function SetFlightMode(enabled)
    if not CONFIG.ENABLE_NOCLIP then return end
    
    local char = GetCharacter()
    local hrp = GetRootPart()
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return
    
    if enabled then
        -- отключаем гравитацию
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        hum.PlatformStand = true
        hum.AutoRotate = false
        
        -- отключаем коллизию
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanQuery = false
            end
        end
        
        -- фиксируем высоту
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

-- ============================================================
-- ОСНОВНАЯ МЕХАНИКА — ПОИСК БЛИЖАЙШЕЙ МОНЕТЫ (Zyn-ic)
-- Источник: https://github.com/Zyn-ic/MM2-AutoFarm
-- ============================================================
local function FindNearestCoin()
    local now = tick()
    
    -- кэш обновляется раз в 0.1 секунды для оптимизации
    if now - lastCacheUpdate < 0.1 and #coinCache > 0 then
        return coinCache[1]
    end
    
    local rootPart = GetRootPart()
    if not rootPart then return nil end
    
    local coins = {}
    
    -- сканируем workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        -- проверка: это монета?
        if obj:IsA("BasePart") and obj.Parent ~= GetCharacter() then
            local name = obj.Name:lower()
            local isCoin = name:find("coin") or 
                          name:find("money") or 
                          name:find("gold") or 
                          name:find("cash") or
                          name:find("candy") or
                          name:find("present")
            
            if isCoin then
                local dist = (rootPart.Position - obj.Position).Magnitude
                table.insert(coins, {obj = obj, dist = dist})
            end
        end
    end
    
    -- сортируем от ближайшей к дальней
    table.sort(coins, function(a, b) return a.dist < b.dist end)
    coinCache = coins
    lastCacheUpdate = now
    
    return coins[1] and coins[1].obj or nil
end

-- ============================================================
-- TWEEN АНИМАЦИЯ
-- ============================================================
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

-- ============================================================
-- СБОР МОНЕТЫ
-- ============================================================
local function CollectCoin(coin)
    if not coin or not coin.Parent then return false end
    
    pcall(function()
        FlyToPosition(coin.Position)
        wait(0.03)
        
        -- ClickDetector
        local click = coin:FindFirstChildWhichIsA("ClickDetector")
        if click then
            fireclickdetector(click)
        end
        
        -- ProximityPrompt
        local prompt = coin:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            prompt:InputHoldBegin()
            wait(0.03)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- ============================================================
-- АВТОФАРМ — ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function StartAutoFarm()
    if farmConnection then return end
    
    isActive = true
    SetFlightMode(true)
    
    farmConnection = RunService.Stepped:Connect(function()
        if not isActive then
            farmConnection:Disconnect()
            farmConnection = nil
            return
        end
        
        local targetCoin = FindNearestCoin()
        
        if targetCoin then
            CollectCoin(targetCoin)
            wait(CONFIG.COLLECT_DELAY)
        else
            wait(0.15)
        end
    end)
    
    print("[AutoFarm] ✅ Запущен")
end

local function StopAutoFarm()
    isActive = false
    
    if farmConnection then
        farmConnection:Disconnect()
        farmConnection = nil
    end
    
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    
    SetFlightMode(false)
    
    print("[AutoFarm] ⛔ Остановлен")
end

-- ============================================================
-- УПРАВЛЕНИЕ ПО КНОПКЕ
-- ============================================================
local function ToggleAutoFarm()
    if isActive then
        StopAutoFarm()
    else
        StartAutoFarm()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode[CONFIG.ACTIVATION_KEY] then
        ToggleAutoFarm()
    end
end)

-- ============================================================
-- ЗАЩИТА ПРИ РЕСПАВНЕ
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if isActive then
        SetFlightMode(true)
    end
end)

-- ============================================================
-- INFO
-- ============================================================
print([[
╔══════════════════════════════════════════════════════════════════╗
║              🔪 MM2 AUTOFARM — CLEAN TEST SCRIPT 🔪              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   Активация: нажми [F]                                          ║
║                                                                  ║
║   Система найдёт ближайшую монету, прилетит к ней через Tween,   ║
║   соберёт, затем сразу полетит к следующей.                      ║
║                                                                  ║
║   NoClip + полёт под картой включены по умолчанию.              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
]])
