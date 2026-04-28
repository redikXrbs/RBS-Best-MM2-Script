local Noclip = nil
local Clip = false

function noclip()
    Clip = false
    local function Nocl()
        if Clip == false and game.Players.LocalPlayer.Character ~= nil then
            for _, v in pairs(game.Players.LocalPlayer.Character:GetDescendants()) do
                if v:IsA('BasePart') then
                    -- Убираем любое условие на имя, отключаем всё
                    v.CanCollide = false
                    v.CanQuery = false
                end
            end
        end
        wait(0.21) -- задержка для оптимизации
    end
    if Noclip then Noclip:Disconnect() end
    Noclip = game:GetService('RunService').Stepped:Connect(Nocl)
end

function clip()
    if Noclip then Noclip:Disconnect() end
    Clip = true
    -- Опционально: вернуть CanCollide = true для всех частей, но не обязательно
end

noclip() -- включает режим прохода сквозь всё

