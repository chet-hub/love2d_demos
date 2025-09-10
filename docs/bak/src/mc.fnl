;; main.fnl - 2D Minecraft-like MVP in Love2D + Fennel
;; Compile: fennel --compile main.fnl > main.lua
;; Run: love .

(local love (require :love))

;; --- 配置 ---
(local tile-size 32)  ;; 方块大小
(local world-dim 50)  ;; 世界网格 50x50
(local player-speed 200)  ;; 玩家速度 (像素/秒)

;; --- 数据结构 ---
(var world {})  ;; world[x][y] = block-type (nil=air, 1=dirt, 2=stone)
(var entities {})  ;; {id: {type: :player/:zombie, x:, y:, health:, vel-x:, vel-y:}}
(var next-entity-id 1)
(var player-id nil)
(var inventory {})  ;; {slot: {item: :dirt, count: 1}}
(var hotbar-selected 1)  ;; 当前道具栏槽 (1-9)
(var items-on-ground {})  ;; {id: {x:, y:, item: :dirt}}

;; --- 辅助函数 ---
(fn init-world []
  (set world {})
  (for [x 1 world-dim]
    (tset world x {})
    (for [y 1 world-dim]
      (tset (. world x) y (if (< y 20) 1 nil))))  ;; 下层 dirt，上层 air
)

(fn create-entity [type x y]
  (let [id next-entity-id]
    (set next-entity-id (+ id 1))
    (tset entities id {:type type :x x :y y :health (if (= type :player) 100 50) :vel-x 0 :vel-y 0})
    id))

(fn update-entities [dt]
  (each [id ent (pairs entities)]
    ;; 移动
    (set ent.x (+ ent.x (* ent.vel-x dt)))
    (set ent.y (+ ent.y (* ent.vel-y dt)))
    ;; 僵尸 AI
    (when (= ent.type :zombie)
      (let [player (. entities player-id)
            dx (- player.x ent.x)
            dy (- player.y ent.y)
            dist (math.sqrt (+ (* dx dx) (* dy dy)))]
        (when (> dist 0)
          (set ent.vel-x (* (/ dx dist) 100))  ;; 慢速追逐
          (set ent.vel-y (* (/ dy dist) 100)))))
    ;; 简单碰撞: 防止掉进方块
    (let [tx (math.floor (/ ent.x tile-size))
          ty (math.floor (/ ent.y tile-size))]
      (when (and (. world tx ty) (> ent.vel-y 0))
        (set ent.vel-y 0)
        (set ent.y (* ty tile-size))))))

(fn handle-input [dt]
  (let [player (. entities player-id)]
    (set player.vel-x 0)
    (set player.vel-y 0)
    (when (love.keyboard.isDown :a) (set player.vel-x (- player-speed)))
    (when (love.keyboard.isDown :d) (set player.vel-x player-speed))
    (when (love.keyboard.isDown :w) (set player.vel-y (- player-speed)))
    (when (love.keyboard.isDown :s) (set player.vel-y player-speed))))

(fn break-block [mx my]
  (let [tx (math.floor (/ mx tile-size))
        ty (math.floor (/ my tile-size))]
    (when (. world tx ty)
      (let [item-type (or (. world tx ty) 1)]
        (tset items-on-ground (length items-on-ground) {:x (* tx tile-size) :y (* ty tile-size) :item item-type}))
      (tset (. world tx) ty nil))))

(fn place-block [mx my]
  (let [tx (math.floor (/ mx tile-size))
        ty (math.floor (/ my tile-size))
        selected-item (. inventory hotbar-selected)]
    (when (and selected-item (. selected-item :item) (not (. world tx ty)))
      (tset (. world tx) ty selected-item.item)
      (set selected-item.count (- (or selected-item.count 1) 1))
      (when (<= selected-item.count 0)
        (tset inventory hotbar-selected nil)))))

(fn find-slot-with-item [type]
  (for [i 1 9]
    (when (and (. inventory i) (= (. inventory i :item) type))
      (lua "return i")))
  nil)

(fn find-empty-slot []
  (for [i 1 9]
    (when (not (. inventory i)) (lua "return i")))
  1)


(fn pickup-items []
  (let [player (. entities player-id)]
    (var new-items {})
    (each [id item (pairs items-on-ground)]
      (let [dx (- item.x player.x)
            dy (- item.y player.y)
            dist (math.sqrt (+ (* dx dx) (* dy dy)))]
        (if (< dist tile-size)
          (let [slot (or (find-slot-with-item item.item) (find-empty-slot))]
            (let [inv-item (. inventory slot)]
              (if inv-item
                (set inv-item.count (+ (or inv-item.count 0) 1))
                (tset inventory slot {:item item.item :count 1}))))
          (tset new-items id item))))
    (set items-on-ground new-items)))



(fn count-item [type]
  (var total 0)
  (each [_ slot (pairs inventory)]
    (when (= slot.item type) (set total (+ total (or slot.count 0)))))
  total)


(fn remove-item [type amount]
  (var rem amount)
  (each [i slot (pairs inventory)]
    (when (and (= slot.item type) (> rem 0))
      (let [remove (math.min rem slot.count)]
        (set slot.count (- slot.count remove))
        (set rem (- rem remove))
        (when (<= slot.count 0) (tset inventory i nil))))))

(fn add-item [type amount]
  (let [slot (or (find-slot-with-item type) (find-empty-slot))]
    (let [inv-item (. inventory slot)]
      (if inv-item
        (set inv-item.count (+ (or inv-item.count 0) amount))
        (tset inventory slot {:item type :count amount})))))


(fn craft []
  (let [dirt-count (count-item 1)]
    (when (>= dirt-count 2)
      (remove-item 1 2)
      (add-item 2 1))))


(fn collide? [a b]
  (let [dx (- a.x b.x)
        dy (- a.y b.y)]
    (< (math.sqrt (+ (* dx dx) (* dy dy))) tile-size)))


(fn update-combat [dt]
  (let [player (. entities player-id)]
    (each [id ent (pairs entities)]
      (when (and (= ent.type :zombie) (collide? player ent))
        (set player.health (- player.health (* 10 dt)))
        (set ent.health (- ent.health (* 5 dt)))
        (when (<= player.health 0) (print "Player died!"))
        (when (<= ent.health 0) (tset entities id nil))))))



(fn draw-world []
  (for [x 1 world-dim]
    (for [y 1 world-dim]
      (let [block (. world x y)]
        (when block
          (when (= block 1) (love.graphics.setColor 0.5 0.3 0))  ;; dirt
          (when (= block 2) (love.graphics.setColor 0.8 0.8 0.8))  ;; stone
          (love.graphics.rectangle :fill (* x tile-size) (* y tile-size) tile-size tile-size))))))

(fn draw-entities []
  (each [_ ent (pairs entities)]
    (if (= ent.type :player)
      (love.graphics.setColor 0 1 0)
      (love.graphics.setColor 1 0 0))
    (love.graphics.rectangle :fill ent.x ent.y tile-size tile-size)))

(fn draw-items-on-ground []
  (each [_ item (pairs items-on-ground)]
    (love.graphics.setColor 0.5 0.5 0.5)
    (love.graphics.circle :fill item.x item.y 8)))

(fn draw-inventory []
  (love.graphics.setColor 1 1 1)
  (for [i 1 9]
    (let [item (. inventory i)
          x (* (- i 1) 40)
          y (- (love.graphics.getHeight) 40)]
      (love.graphics.rectangle :line x y 32 32)
      (when item
        (love.graphics.print (tostring item.item) x y)
        (love.graphics.print (tostring item.count) (+ x 20) y))
      (when (= i hotbar-selected)
        (love.graphics.setColor 1 1 0)
        (love.graphics.rectangle :line x y 32 32)
        (love.graphics.setColor 1 1 1)))))

;; --- Love2D 回调 ---
(fn load []
  (init-world)
  (set player-id (create-entity :player (* world-dim tile-size 0.5) (* 10 tile-size)))
  (create-entity :zombie (* world-dim tile-size 0.6) (* 10 tile-size))
  (add-item 1 10)  ;; 10 dirt
  (add-item 2 5))  ;; 5 stone

(fn update [dt]
  (handle-input dt)
  (update-entities dt)
  (update-combat dt)
  (pickup-items))

(fn draw []
  (draw-world)
  (draw-entities)
  (draw-items-on-ground)
  (draw-inventory))

(fn love.keypressed [key]
  (when (= key :space) (craft))
  (when (= key :1) (set hotbar-selected 1))
  (when (= key :2) (set hotbar-selected 2))
  (when (= key :3) (set hotbar-selected 3))
  (when (= key :4) (set hotbar-selected 4))
  (when (= key :5) (set hotbar-selected 5))
  (when (= key :6) (set hotbar-selected 6))
  (when (= key :7) (set hotbar-selected 7))
  (when (= key :8) (set hotbar-selected 8))
  (when (= key :9) (set hotbar-selected 9)))

(fn love.mousepressed [mx my button]
  (if (= button 1) (break-block mx my)
      (= button 2) (place-block mx my)))

;; --- 导出 ---
{:load load :update update :draw draw}