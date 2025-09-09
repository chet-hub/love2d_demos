
local love = require('love')
local game = {}

function game.load()
    game.player = {x = 100, y = 400, w = 32, h = 32, speed = 200, vy = 0, jump = -400}
    game.gravity = 800
    game.player.on_ground = true
    game.platforms = {{x = 0, y = 500, w = 800, h = 100}}
    game.coins = {{x = 300, y = 400, r = 10}}
end

function game.update(dt)
    -- 玩家移动
    if love.keyboard.isDown("left") then
        game.player.x = game.player.x - game.player.speed * dt
    elseif love.keyboard.isDown("right") then
        game.player.x = game.player.x + game.player.speed * dt
    end
    if love.keyboard.isDown("space") and game.player.on_ground then
        game.player.vy = game.player.jump
        game.player.on_ground = false
    end
    -- 物理
    game.player.vy = game.player.vy + game.gravity * dt
    game.player.y = game.player.y + game.player.vy * dt
    -- 平台碰撞
    game.player.on_ground = false
    for _, platform in ipairs(game.platforms) do
        if game.player.x + game.player.w > platform.x and game.player.x < platform.x + platform.w
            and game.player.y + game.player.h > platform.y and game.player.y < platform.y + platform.h
            and game.player.vy > 0 then
            game.player.y = platform.y - game.player.h
            game.player.vy = 0
            game.player.on_ground = true
        end
    end
    -- 金币收集
    for i = #game.coins, 1, -1 do
        local coin = game.coins[i]
        if math.sqrt((game.player.x - coin.x)^2 + (game.player.y - coin.y)^2) < coin.r + game.player.w then
            table.remove(game.coins, i)
        end
    end
end

function game.draw()
    love.graphics.rectangle("fill", game.player.x, game.player.y, game.player.w, game.player.h)
    for _, platform in ipairs(game.platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end
    for _, coin in ipairs(game.coins) do
        love.graphics.circle("fill", coin.x, coin.y, coin.r)
    end
end

return game