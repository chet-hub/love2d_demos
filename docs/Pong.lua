local love = require("love")
local Pong = {}


-- load some default values for our rectangle.
function Pong.load()
    Pong.ball = {x = 400, y = 300, radius = 10, dx = 200, dy = 200}
    Pong.paddle1 = {x = 50, y = 250, w = 20, h = 100, speed = 300}
    Pong.paddle2 = {x = 750, y = 250, w = 20, h = 100, speed = 300}
    Pong.score1, Pong.score2 = 0, 0
end

function Pong.update(dt)
    -- 玩家 1 移动
    if love.keyboard.isDown("w") then
        Pong.paddle1.y = Pong.paddle1.y - Pong.paddle1.speed * dt
    elseif love.keyboard.isDown("s") then
        Pong.paddle1.y = Pong.paddle1.y + Pong.paddle1.speed * dt
    end

    -- 玩家 2 移动
    if love.keyboard.isDown("up") then
        Pong.paddle2.y = Pong.paddle2.y - Pong.paddle2.speed * dt
    elseif love.keyboard.isDown("down") then
        Pong.paddle2.y = Pong.paddle2.y + Pong.paddle2.speed * dt
    end

    -- 球移动
    Pong.ball.x = Pong.ball.x + Pong.ball.dx * dt
    Pong.ball.y = Pong.ball.y + Pong.ball.dy * dt
    

    -- 边界碰撞
    if Pong.ball.y < 0 or Pong.ball.y > 600 then
        Pong.ball.dy = - Pong.ball.dy
    end

    -- 挡板碰撞
    if Pong.ball.x < Pong.paddle1.x + Pong.paddle1.w and Pong.ball.y > Pong.paddle1.y and Pong.ball.y < Pong.paddle1.y + Pong.paddle1.h then
        Pong.ball.dx = -Pong.ball.dx
    elseif Pong.ball.x > Pong.paddle2.x - Pong.paddle2.w and Pong.ball.y > Pong.paddle2.y and Pong.ball.y < Pong.paddle2.y + Pong.paddle2.h then
        Pong.ball.dx = -Pong.ball.dx
    end

    -- 得分
    if Pong.ball.x < 0 then
        Pong.score2 = Pong.score2 + 1
        Pong.ball.x, Pong.ball.y = 400, 300
    elseif Pong.ball.x > 800 then
        Pong.score1 = Pong.score1 + 1
        Pong.ball.x, Pong.ball.y = 400, 300
    end

end

function Pong.draw()
    love.graphics.rectangle("fill", Pong.paddle1.x, Pong.paddle1.y, Pong.paddle1.w, Pong.paddle1.h)
    love.graphics.rectangle("fill", Pong.paddle2.x, Pong.paddle2.y, Pong.paddle2.w, Pong.paddle2.h)
    love.graphics.circle("fill", Pong.ball.x, Pong.ball.y, Pong.ball.radius)
    love.graphics.print("Score: " .. Pong.score1 .. " - " .. Pong.score2, 350, 50)
end

return Pong