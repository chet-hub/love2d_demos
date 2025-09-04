(local love (require :love))

(fn init []
  (print "Player from Fennel!"))

(fn update [dt]
  ;; nothing

)

(fn draw []
  (love.graphics.print "I am player" 100 100))

{:init init :update update :draw draw}
