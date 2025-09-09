
(local love (require "love"))
(local game {})

(fn game.load [] 
    (set game.player {:x 100 :y 400 :w 32 :h 32 :speed 200 :vy 0 :jump -400 :on_ground true}) 
    (set game.gravity 800)
    (set game.platforms {{:x 0 :y 500 :w 800 :h 100}})
    (set game.coins {{:x 300 :y 400 :r 10}}))

(fn game.update [] 
    (when (: love.keyboard :isDown "left") 
        (set game.player.x (- game.player.x ( * game.player.speed dt))))
    (when (: love.keyboard :isDown "right") 
        (set game.player.x (+ game.player.x ( * game.player.speed dt)))) 
    (when (and (: love.keyboard :isDown "space") game.player.on_ground)
        (set game.player.vy game.player.jump)
        (set game.player.on_ground false)) 
    (set game.player.y (+ game.player.y (* (+ game.player.vy  (* game.gravity dt)) dt )))
    (set game.player.on_ground false) 
    
    (for [_ platform (ipairs game.platforms)] 
        (when (and  (> (+ game.player.x game.player.w) platform.x) 
                    (> (+ platform.x platform.w) game.player.x)
                    (> (+ platform.y platform.h) game.player.y) 
                    (> (+ player.y player.h) platform.y)
                    (> game.player.vy 0)) 
            (set game.player.y (- platform.y   game.player.h))
            (set game.player.vy 0)
            (set game.player.on_ground true)))

    (for [i (length coins) 1 -1]
        (let [coin (. coins i)]
        (when (< (math.sqrt (+ (^ (- player.x coin.x) 2) (^ (- player.y coin.y) 2)))
                (+ coin.r player.w))
            (table.remove coins i)))))

(fn game.draw []
  (: love.graphics :rectangle "fill" game.player.x game.player.y game.player.w game.player.h)
  (each [_ platform platforms]
    (: love.graphics :rectangle "fill" platform.x platform.y platform.w platform.h))
  (each [_ coin coins]
    (: love.graphics :circle "fill" coin.x coin.y coin.r)))


game