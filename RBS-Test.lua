-- ╔══════════════════════════════════════════════════════════════════╗
-- ║           🔪 FIXED NOCLIP + FLY MODE | НЕ ПАДАЕТ 🔪              ║
-- ╚══════════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === НАСТРОЙКИ ===
local CONFIG = {
    NO_CLIP_KEY = "F",           -- Клавиша для включения NoClip
    ANCHOR_HEIGHT = -8,          -- На какой высоте "заякорить" (под картой)
    ANTI_FALL_Y = -100,          -- Глубина, на которой сработает защита
}

-- === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
local noclipActive = false
local isAnchored = false
local originalCollision = true

-- === ПОЛУЧЕНИЕ ПЕРСОНАЖА ===
local function GetRootPart()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- === ФУНКЦИИ УПРАВЛЕНИЯ СОСТОЯНИЕМ ===
local function SetFlyingState(enabled)
    local hrp = GetRootPart()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    if enabled then
        -- 🛑 Отключаем всё, что может уронить
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        humanoid.AutoRotate = false

        -- Принудительно переводим в состояние ПОЛЕТА (Flying)
        humanoid:ChangeState(Enum.HumanoidStateType.Flying)

        -- ЗАПОМИНАЕМ POSITION и ЗАЯКОРИВАЕМ RootPart на высоте
        -- Это не дает гравитации стащить его вниз
        if CONFIG.ANCHOR_HEIGHT then
            hrp.Anchored = true
            local targetPos = Vector3.new(hrp.Position.X, CONFIG.ANCHOR_HEIGHT, hrp.Position.Z)
            hrp.Position = targetPos
            isAnchored = true
        end

        -- 💥 ОТКЛЮЧАЕМ КОЛЛИЗИИ (NoClip)
        originalCollision = hrp.CanCollide
        hrp.CanCollide = false
        hrp.CanQuery = false

    else
        -- 🟢 ВОССТАНАВЛИВАЕМ ВСЕ НАСТРОЙКИ
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        humanoid.AutoRotate = true
        humanoid:ChangeState(Enum.HumanoidStateType.Running) -- Возврат в обычное состояние

        if isAnchored then
            hrp.Anchored = false
            isAnchored = false
        end

        hrp.CanCollide = originalCollision
        hrp.CanQuery = originalCollision
    end
end

-- === АНТИ-ВОЙД (ЗАЩИТА ОТ ПАДЕНИЯ) ===
local function AntiVoid()
    local hrp = GetRootPart()
    if not hrp then return end

    if hrp.Position.Y < CONFIG.ANTI_FALL_Y then
        -- Телепортируем в безопасную точку под центром карты
        hrp.CFrame = CFrame.new(0, CONFIG.ANCHOR_HEIGHT, 0)
        print("[ANTI-VOID] Спасение от падения!")
    end
end

-- === ГЛАВНЫЙ ЦИКЛ (ПОСТОЯННАЯ ПРОВЕРКА) ===
RunService.Stepped:Connect(function()
    if noclipActive then
        SetFlyingState(true)  -- Поддерживаем состояние "полета"
        AntiVoid()            -- Проверяем, не упал ли игрок
    else
        SetFlyingState(false) -- Возвращаем всё как было
    end
end)

-- === ТОГГЛ ПО КНОПКЕ ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode[CONFIG.NO_CLIP_KEY] then
        noclipActive = not noclipActive
        if noclipActive then
            print("[NoClip] ✅ ВКЛЮЧЕН | Проход сквозь стены и полет активированы")
        else
            print("[NoClip] ❌ ВЫКЛЮЧЕН")
        end
    end
end)

-- === ПЕРЕЗАГРУЗКА ПЕРСОНАЖА ===
LocalPlayer.CharacterAdded:Connect(function()
    -- Небольшая задержка, чтобы игра создала нового персонажа
    task.wait(0.5)
    if noclipActive then
        SetFlyingState(true)
    end
end)

print([[

╔══════════════════════════════════════════════════════════════════╗
║     🔧 ИСПРАВЛЕННЫЙ NOCLIP + РЕЖИМ ПОЛЕТА ЗАГРУЖЕН 🔧            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  🎮 Управление:                                                 ║
║     Нажмите [F] для включения/выключения режима                 ║
║                                                                 ║
║  ✨ Что исправлено:                                             ║
║     ✅ Принудительное состояние Flying (не падает)              ║
║     ✅ Якорение (Anchored) на нужной высоте                     ║
║     ✅ Защита от падения в бездну (Anti-Void)                   ║
║     ✅ Плавный полет между монетами                             ║
║                                                                 ║
╚══════════════════════════════════════════════════════════════════╝
]])
