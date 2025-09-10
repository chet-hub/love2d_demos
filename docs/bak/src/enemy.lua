local love = require("love")
local Assets = _G.Assets

local Enemy = {}

function Enemy.load()
    -- print("Enemy module loaded!")
end

function Enemy.update(dt)
    -- 敌人逻辑
end

function Enemy.draw()
    -- love.graphics.print("I am enemy", 200, 200)
end

return Enemy
