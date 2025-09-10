;; main.fnl - Product-Grade 2D Minecraft-like Framework
;; Features: Concord ECS, Chunk System, Mod System, Hot Reloading, Persistence
;; Compile: fennel --compile main.fnl > main.lua
;; Run: love .

(local love (require :love))
(local concord (require :lib.concord))

;; --- 初始化 Concord ---
(concord.init {:use-events true})
(var world (concord.world))

;; --- 配置 ---
(var config {:tile-size 32
             :chunk-size 16
             :view-distance 5
             :save-dir "saves/"
             :debug-mode true})

(fn load-config []
  (let [config-file "config.json"
        info (love.filesystem.getInfo config-file)]
    (when info
      (let [(ok data) (pcall fennel.eval (love.filesystem.read config-file) {:env _G})]
        (when ok (set config (or data config)))))))

;; --- Chunk 系统 ---
(var chunks {})  ;; {key: {tiles: 2D array, entities: {id: true}, dirty: bool}}
(var loaded-chunks {})

(fn chunk-key [cx cy] (.. cx "," cy))

(fn load-chunk [cx cy]
  (let [key (chunk-key cx cy)
        save-file (.. config.save-dir key ".fnl")]
    (when (not (. chunks key))
      (let [chunk {:tiles (icollect [_ _ (ipairs (range config.chunk-size))] (icollect [_ _ (ipairs (range config.chunk-size))] nil))
                   :entities {}
                   :dirty false}
            info (love.filesystem.getInfo save-file)]
        (when info
          (let [(ok data) (pcall fennel.eval (love.filesystem.read save-file) {:env _G})]
            (when ok (set chunk.tiles (or data.tiles chunk.tiles)))))
        (tset chunks key chunk)
        (world:emit :generate-chunk cx cy key)))
    (tset loaded-chunks key true)))

(fn unload-chunk [cx cy]
  (let [key (chunk-key cx cy)
        chunk (. chunks key)]
    (when (and chunk chunk.dirty)
      (love.filesystem.write (.. config.save-dir key ".fnl") (fennel.view {:tiles chunk.tiles})))
    (tset loaded-chunks key nil)
    (world:emit :unload-chunk cx cy chunk)))

(fn get-tile [wx wy]
  (let [cx (math.floor (/ wx config.chunk-size))
        cy (math.floor (/ wy config.chunk-size))
        lx (% wx config.chunk-size)
        ly (% wy config.chunk-size)
        chunk (. chunks (chunk-key cx cy))]
    (when chunk (. chunk.tiles (+ lx 1) (+ ly 1)))))

(fn set-tile [wx wy val]
  (let [cx (math.floor (/ wx config.chunk-size))
        cy (math.floor (/ wy config.chunk-size))
        lx (% wx config.chunk-size)
        ly (% wy config.chunk-size)
        key (chunk-key cx cy)
        chunk (. chunks key)]
    (when (not chunk) (load-chunk cx cy) (set chunk (. chunks key)))
    (tset chunk.tiles (+ lx 1) (+ ly 1) val)
    (set chunk.dirty true)))

;; --- Mod API ---
(local api {:config config
            :world world
            :load-chunk load-chunk
            :unload-chunk unload-chunk
            :get-tile get-tile
            :set-tile set-tile
            :emit (fn [evt ...] (world:emit evt ...))})

(fn api.register-block [type props]
  (world:emit :register-block type props))

(fn api.register-entity-type [type prefab-fn]
  (world:emit :register-entity-type type prefab-fn))

(fn api.register-item [type props]
  (world:emit :register-item type props))

(fn api.register-recipe [recipe]
  (world:emit :register-recipe recipe))

;; --- Mod 加载 ---
(var mods {})  ;; {mod-name: {init: fn, reloaded: bool}}

(fn load-mods []
  (let [mod-dirs (love.filesystem.getDirectoryItems "mods/")]
    (each [_ dir (ipairs mod-dirs)]
      (let [mod-path (.. "mods/" dir "/init")
            (ok mod-module) (pcall require mod-path)]
        (when (and ok mod-module.init)
          (let [(init-ok err) (pcall mod-module.init api)]
            (if init-ok
              (tset mods dir {:init mod-module.init :reloaded false})
              (when config.debug-mode (print (.. "Mod " dir " init error: " err)))))))))
  (world:emit :mods-loaded))

(fn reload-mod [mod-name]
  (let [mod (. mods mod-name)]
    (when mod
      (package.loaded (.. "mods/" mod-name "/init") nil)
      (let [(ok new-module) (pcall require (.. "mods/" mod-name "/init"))]
        (when (and ok new-module.init)
          (let [(reload-ok err) (pcall new-module.init mod.api)]
            (if reload-ok
              (do (set mod.reloaded true) (world:emit :mod-reloaded mod-name))
              (when config.debug-mode (print (.. "Reload error for " mod-name ": " err)))))))))

;; --- Camera 系统 ---
(var camera {:x 0 :y 0 :scale 1})

(local camera-system
  (concord.system
    {:players [:player :position]}
    (fn update [self dt]
      (when (> (# self.players) 0)
        (let [pos (. (self.players[1]:get :position) :pos)
              w (love.graphics.getWidth)
              h (love.graphics.getHeight)]
          (set camera.x (- pos.x (/ w 2)))
          (set camera.y (- pos.y (/ h 2))))))))

;; --- Chunk 管理 ---
(local chunk-system
  (concord.system
    {:players [:player :position]}
    (fn update [self dt]
      (when (> (# self.players) 0)
        (let [pos (. (self.players[1]:get :position) :pos)
              pcx (math.floor (/ pos.x (* config.chunk-size config.tile-size)))
              pcy (math.floor (/ pos.y (* config.chunk-size config.tile-size)))]
          (for [cx (- pcx config.view-distance) (+ pcx config.view-distance)]
            (for [cy (- pcy config.view-distance) (+ pcy config.view-distance)]
              (load-chunk cx cy)))
          (each [key _ (pairs loaded-chunks)]
            (let [[cx cy] (icollect [n] (key:gmatch "(-?%d+)") (tonumber n))]
              (when (or (> (math.abs (- cx pcx)) (* config.view-distance 1.5))
                        (> (math.abs (- cy pcy)) (* config.view-distance 1.5)))
                (unload-chunk cx cy)))))))))

;; --- Love2D 回调 ---
(fn love.load [args]
  (load-config)
  (love.filesystem.createDirectory config.save-dir)
  (world:addSystem camera-system)
  (world:addSystem chunk-system)
  (load-mods))

(fn love.update [dt]
  (world:update dt))

(fn love.draw []
  (love.graphics.push)
  (love.graphics.translate (- camera.x) (- camera.y))
  (love.graphics.scale camera.scale)
  (world:draw)
  (love.graphics.pop))

(fn love.keypressed [key]
  (world:emit :keypressed key)
  (when (= key :f5)
    (each [name _ (pairs mods)]
      (reload-mod name))))

(set love.errhand (fn [msg]
  (print (.. "Error: " msg))
  (when config.debug-mode (love.system.openURL "https://love2d.org/wiki"))))

{:load love.load :update love.update :draw love.draw :keypressed love.keypressed}