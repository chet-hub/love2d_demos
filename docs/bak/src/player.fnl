(local love (require :love))

(fn load []
  (print ""))

(fn update [dt]
  ;; nothing

)

(fn draw []
  (love.graphics.print "" 100 100))

{:load load :update update :draw draw}
