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