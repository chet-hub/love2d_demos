# Pong（乒乓球游戏）

## 概述
Pong 是一个简单的 2D 双人乒乓球游戏，玩家控制挡板击打小球，率先得分获胜。这是学习 Love2D 和 Lua 的基础项目，适合熟悉渲染、输入处理和简单碰撞检测。

## 学习目标
- 掌握 Love2D 的核心循环（`love.load`、`love.update`、`love.draw`）。
- 理解键盘输入处理。
- 实现基本的 2D 碰撞检测。
- 学习 Lua 和 Fennel 的基本语法。

## 代码实现

### Lua 版本（main.lua）
```lua
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

```


### Fennel 版本（main.fnl）
```lua
(local love (require :love))

;; 顶级声明：local 用于表（字段可 set），var 用于标量（整个值可 set）
(local ball {:x 400 :y 300 :radius 10 :dx 200 :dy 200})
(local paddle1 {:x 50 :y 250 :w 20 :h 100 :speed 300})
(local paddle2 {:x 750 :y 250 :w 20 :h 100 :speed 300})
(var score1 0)
(var score2 0)

(fn load []
  ;; 重置位置（可选，顶级已初始化）
  (set ball.x 400)
  (set ball.y 300)
  (set paddle1.y 250)
  (set paddle2.y 250)
  ;; 设置窗口大小（推荐，匹配边界）
  (love.window.setMode 800 600 {:resizable false :vsync true}))

(fn update [dt]
  ;; 玩家 1 移动（用静态方法调用，避免动态 :isDown 潜在问题）
  (when (love.keyboard.isDown love.keyboard "w")
    (set paddle1.y (- paddle1.y (* paddle1.speed dt))))
  (when (love.keyboard.isDown love.keyboard "s")
    (set paddle1.y (+ paddle1.y (* paddle1.speed dt))))
  ;; 玩家 2 移动
  (when (love.keyboard.isDown love.keyboard "up")
    (set paddle2.y (- paddle2.y (* paddle2.speed dt))))
  (when (love.keyboard.isDown love.keyboard "down")
    (set paddle2.y (+ paddle2.y (* paddle2.speed dt))))
  ;; 球移动
  (set ball.x (+ ball.x (* ball.dx dt)))
  (set ball.y (+ ball.y (* ball.dy dt)))
  ;; 边界碰撞（垂直）
  (when (or (< ball.y 0) (> ball.y 600))
    (set ball.dy (- ball.dy)))
  ;; 挡板碰撞 - 左（玩家1）
  (when (and (< ball.x (+ paddle1.x paddle1.w))
             (> ball.y paddle1.y)
             (< ball.y (+ paddle1.y paddle1.h)))
    (set ball.dx (- ball.dx)))
  ;; 挡板碰撞 - 右（玩家2）- 修复：添加右边缘检查 (< ball.x (+ paddle2.x paddle2.w))
  (when (and (> ball.x (- paddle2.x paddle2.w))
             (< ball.x (+ paddle2.x paddle2.w))  ;; 新增：防止漏检
             (> ball.y paddle2.y)
             (< ball.y (+ paddle2.y paddle2.h)))
    (set ball.dx (- ball.dx)))
  ;; 得分 - 左超出
  (when (< ball.x 0)
    (set score2 (+ score2 1))
    (set ball.x 400)
    (set ball.y 300)
    (set ball.dx 200)  ;; 重置速度（防止继续飞出）
    (set ball.dy (if (> (math.random) 0.5) 200 -200)))  ;; 随机 Y 方向
  ;; 得分 - 右超出
  (when (> ball.x 800)
    (set score1 (+ score1 1))
    (set ball.x 400)
    (set ball.y 300)
    (set ball.dx -200)
    (set ball.dy (if (> (math.random) 0.5) 200 -200))))

(fn draw []
  ;; 清屏（黑色背景）
  (love.graphics.clear 0 0 0)
  ;; 绘制挡板和球
  (love.graphics.rectangle "fill" paddle1.x paddle1.y paddle1.w paddle1.h)
  (love.graphics.rectangle "fill" paddle2.x paddle2.y paddle2.w paddle2.h)
  (love.graphics.circle "fill" ball.x ball.y ball.radius)
  ;; 分数（用 .. 连接字符串）
  (love.graphics.print (.. "Score: " score1 " - " score2) 350 50))

;; 导出函数给 LÖVE（返回表，重命名）
{:love load :update update :draw draw}

```