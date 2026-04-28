-- ⚡ АБСОЛЮТНЫЙ NOCLIP + БЛОКИРОВКА КАРАБКАНИЯ ⚡
-- Проходит сквозь стены, пол, и не цепляется за края

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local noclipActive = true
local noclipConnection = nil

local function applyNoclip()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 1. Отключаем коллизию у всех частей тела
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery = false
        end
    end
    
    -- 2. БЛОКИРУЕМ КАРАБКАНИЕ (решает проблему "залипания")
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        -- Отключаем攀爬状态
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        -- Отключаем автоповорот (необязательно, но помогает)
        humanoid.AutoRotate = false
        -- Убираем высоту бедер (для проваливания сквозь пол)
        humanoid.HipHeight = 0
    end
end

-- Запускаем постоянный цикл
noclipConnection = RunService.Stepped:Connect(function()
    if noclipActive then
        applyNoclip()
    end
end)

-- Управление: нажми 'P' для вкл/выкл
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        noclipActive = not noclipActive
        print(noclipActive and "[NoClip] ВКЛ" or "[NoClip] ВЫКЛ")
    end
end)

print("[NoClip] Активирован! Нажми P для вкл/выкл.")
