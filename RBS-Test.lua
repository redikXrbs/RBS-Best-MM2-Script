-- ⚡ АБСОЛЮТНЫЙ NOCLIP (ПРОХОДИТ СКВОЗЬ ВСЁ) ⚡
-- Позволяет проходить сквозь стены, предметы и проваливаться под карту.

-- Переменная для включения/выключения (изначально ВКЛЮЧЕН)
local noclipActive = true

-- Главная функция, которая всё ломает
local function enableAbsoluteNoclip()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end

    -- 1. Отключаем коллизию у всех частей тела
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
        end
    end

    -- 2. [СЕКРЕТНЫЙ ИНГРЕДИЕНТ] Убираем "высоту бедер".
    -- Это физически отрывает персонажа от земли, позволяя падать.
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        -- Запоминаем стандартную высоту, если нужно будет вернуть
        if not humanoid:GetAttribute("OriginalHipHeight") then
            humanoid:SetAttribute("OriginalHipHeight", humanoid.HipHeight)
        end
        humanoid.HipHeight = 0
    end
end

-- Функция для возврата всего "как было" (на случай, если понадобится отключить)
local function disableAbsoluteNoclip()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
            part.CanQuery = true
        end
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        local originalHeight = humanoid:GetAttribute("OriginalHipHeight")
        if originalHeight then
            humanoid.HipHeight = originalHeight
        end
    end
end

-- Запускаем бесконечный цикл, который будет следить за состоянием
-- Используем RunService.Stepped для максимальной эффективности (срабатывает до просчета физики)
local runService = game:GetService("RunService")
local noclipConnection

noclipConnection = runService.Stepped:Connect(function()
    if noclipActive then
        -- При каждом "шаге" физики принудительно применяем наши настройки
        enableAbsoluteNoclip()
    end
end)

-- Для удобства: нажмите 'P', чтобы включить/выключить NoClip
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        noclipActive = not noclipActive
        if noclipActive then
            print("[NoClip] Активирован (можно ходить сквозь пол!)")
            enableAbsoluteNoclip() -- Применяем сразу
        else
            print("[NoClip] Деактивирован")
            disableAbsoluteNoclip()
        end
    end
end)

enableAbsoluteNoclip()
print("[NoClip] Активирован! Нажми 'P' для вкл/выкл.")
