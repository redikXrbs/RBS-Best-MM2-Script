-- ⚡ MM2 ULTRA FARM | RBS V8 (Стабильная механика) ⚡

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Настройки (можно менять)
local CONFIG = {
    ToggleKey = "F",        -- Клавиша включения (по умолчанию F)
    FlyHeight = -8,         -- Высота полета под картой
}

-- Состояния
local isActive = false     -- Вкл/Выкл фарма
local noclipConnection = nil
local farmLoop = nil

-- Получение персонажа
local function GetChar()
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    return char
end

-- Поиск ближайшей монеты (БЕЗ TWEEN, через простую механику полета)
local function GetNearestCoin()
    local char = GetChar()
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    local nearest = nil
    local minDist = math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= char then
            local name = obj.Name:lower()
            -- Проверяем имена монет, мячиков и т.д.
            if name:find("coin") or name:find("money") or name:find("gold") or name:find("beach") or name:find("ball") then
                local dist = (rootPart.Position - obj.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

-- ❄️ СИСТЕМА NOCLIP + ПОЛЕТА (Без Tween)
local function setNoclipFly(enabled)
    local char = GetChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    
    if enabled then
        -- 1. Выключаем Гравитацию (Ключевой момент!)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        humanoid.PlatformStand = true -- Зависание в воздухе
        humanoid.AutoRotate = false
        
        -- 2. Отключаем столкновения (Noclip)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanQuery = false
            end
        end
        
        -- 3. Фиксируем позицию под картой, чтобы не падать
        hrp.Anchored = true
        hrp.Position = Vector3.new(hrp.Position.X, CONFIG.FlyHeight, hrp.Position.Z)
    else
        -- Возвращаем все как было
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        
        hrp.Anchored = false
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.CanQuery = true
            end
        end
    end
end

-- 📦 ОСНОВНОЙ ЦИКЛ ФАРМА (Летаем через CFrame, не падаем)
local function startFarming()
    if farmLoop then return end
    farmLoop = RunService.Stepped:Connect(function()
        if not isActive then return end
        
        local char = GetChar()
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        -- 1. Ищем монету
        local target = GetNearestCoin()
        
        if target then
            -- Если есть монета: мгновенно телепортируемся к ней через CFrame
            -- Это заменяет Tween и убирает дерганья
            rootPart.CFrame = target.CFrame * CFrame.new(0, 2, 0) -- Немного выше, чтобы не застревать
            
            -- Имитируем сбор (FireClickDetector)
            local detector = target:FindFirstChildWhichIsA("ClickDetector")
            if detector then
                fireclickdetector(detector)
            end
        else
            -- Если монет нет: стоим на месте под картой
            -- (RootPart уже заанкерен и не падает)
            wait(0.2)
        end
    end)
end

-- Остановка
local function stopFarming()
    if farmLoop then
        farmLoop:Disconnect()
        farmLoop = nil
    end
    setNoclipFly(false)
end

-- 🎮 Управление по кнопке
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[CONFIG.ToggleKey] then
        isActive = not isActive
        if isActive then
            setNoclipFly(true)
            startFarming()
            print("[RBS] ✅ Фарм ВКЛ: Режим полета активирован")
        else
            stopFarming()
            print("[RBS] ⛔ Фарм ВЫКЛ")
        end
    end
end)

-- Защита при респавне
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if isActive then
        setNoclipFly(true)
    end
end)

print("⚡ RBS ULTRA FARM | Нажми 'F' для старта")
print("🔹 Персонаж парит под картой и собирает монеты")
