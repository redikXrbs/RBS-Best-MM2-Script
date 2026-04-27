-- ╔════════════════════════════════════════════════════════════════════╗
-- ║              🔪 ТЕСТОВЫЙ NOCLIP | Murder Mystery 2 🔪              ║
-- ║                                                                    ║
-- ║  Управление:                                                       ║
-- ║    Нажми [N] - Включить/Выключить NoClip                          ║
-- ║    Нажми [V] - Показать статус в консоль                           ║
-- ║                                                                    ║
-- ║  Как работает:                                                     ║
-- ║    Активно проталкивает персонажа сквозь стены                    ║
-- ║    Работает даже когда обычный NoClip не помогает                  ║
-- ╚════════════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===========================
-- НАСТРОЙКИ (можно менять)
-- ===========================
local CONFIG = {
    TELEPORT_DISTANCE = 0.5,   -- На сколько студий телепортировать за шаг (0.3-0.8)
    USE_CAMERA_DIRECTION = true, -- Использовать направление камеры (true) или клавиши WASD (false)
    SHOW_DEBUG = true,          -- Показывать сообщения в консоль
}

-- Состояние
local noclipActive = false

-- ===========================
-- ФУНКЦИИ
-- ===========================

local function log(message)
    if CONFIG.SHOW_DEBUG then
        print("[NoClip Test] " .. message)
    end
end

-- Получение направления движения
local function getMoveDirection()
    if CONFIG.USE_CAMERA_DIRECTION then
        -- Движение в ту сторону, куда смотрит камера
        local camera = workspace.CurrentCamera
        if camera then
            return camera.CFrame.LookVector
        end
    else
        -- Движение по клавишам WASD (более сложная реализация)
        local moveVector = Vector3.new(
            (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
            0,
            (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        )
        if moveVector.Magnitude > 0 then
            return moveVector.Unit
        end
    end
    return Vector3.new(0, 0, 0)
end

-- Основной цикл NoClip
local noclipConnection = nil

local function startNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    noclipConnection = RunService.Stepped:Connect(function()
        if not noclipActive then return end
        
        local character = LocalPlayer.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoidRootPart or not humanoid then return end
        
        -- Получаем направление движения
        local moveDir = getMoveDirection()
        
        -- Если не используем направление камеры и нет нажатых клавиш — не двигаем
        if not CONFIG.USE_CAMERA_DIRECTION and moveDir.Magnitude == 0 then
            return
        end
        
        -- Телепортируем персонажа в направлении движения
        local newPosition = humanoidRootPart.Position + (moveDir * CONFIG.TELEPORT_DISTANCE)
        humanoidRootPart.CFrame = CFrame.new(newPosition)
        
        -- Небольшая отладочная индикация (каждый 60 кадров примерно)
        if CONFIG.SHOW_DEBUG and tick() % 2 < 0.1 then
            log("NoClip активен, позиция: " .. tostring(newPosition))
        end
    end)
    
    log("NoClip цикл запущен")
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
        log("NoClip цикл остановлен")
    end
end

-- ===========================
-- УПРАВЛЕНИЕ
-- ===========================

-- Включение/выключение через клавишу N
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.N then
        noclipActive = not noclipActive
        
        if noclipActive then
            log("════════════════════════════════════════")
            log("🔓 NOCLIP ВКЛЮЧЕН")
            log("   Теперь ты проходишь сквозь стены!")
            log("   Нажми [N] ещё раз чтобы выключить")
            log("════════════════════════════════════════")
            startNoclip()
        else
            log("════════════════════════════════════════")
            log("🔒 NOCLIP ВЫКЛЮЧЕН")
            log("   Стены снова твёрдые")
            log("════════════════════════════════════════")
            stopNoclip()
        end
    end
    
    -- Показать статус по клавише V
    if input.KeyCode == Enum.KeyCode.V then
        if noclipActive then
            log("Статус: NOCLIP ВКЛЮЧЕН | Дистанция: " .. CONFIG.TELEPORT_DISTANCE)
        else
            log("Статус: NOCLIP ВЫКЛЮЧЕН | Нажми [N] для включения")
        end
    end
end)

-- ===========================
-- ЗАЩИТА ПРИ РЕСПАВНЕ
-- ===========================
LocalPlayer.CharacterAdded:Connect(function()
    log("Персонаж пересоздан, NoClip статус сохранён")
    if noclipActive then
        -- Небольшая задержка чтобы персонаж успел загрузиться
        task.wait(0.5)
        startNoclip()
    end
end)

-- ===========================
-- ЗАПУСК
-- ===========================
print([[
╔════════════════════════════════════════════════════════════════════╗
║                    🔪 ТЕСТОВЫЙ NOCLIP v1.0 🔪                      ║
╠════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║   Управление:                                                      ║
║     [N] - Включить/Выключить проход сквозь стены                  ║
║     [V] - Показать текущий статус                                 ║
║                                                                    ║
║   Как это работает:                                                ║
║     • Персонаж телепортируется в направлении камеры               ║
║     • Это позволяет "продавливать" любые стены                    ║
║     • Работает даже когда обычный NoClip бессилен                 ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
]])

log("Скрипт загружен! Нажми [N] для активации NoClip")

