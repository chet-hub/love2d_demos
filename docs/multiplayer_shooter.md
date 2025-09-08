
---

### 案例 3: 多人射击游戏

**文件名**: `docs/multiplayer_shooter.md`

**lua-enet**:GitHub (leafo/lua-enet)，复制 enet.dll（Windows）到项目目录。
**JSON 库**:GitHub (rxi/json.lua)，复制 json.lua 到项目。



```markdown
# 多人射击游戏

## 概述
多人射击游戏是一个简单的 2D 对战游戏，两名玩家控制角色移动并射击，同步位置和动作。这是学习 Love2D 网络同步的基础项目，为 UGC 平台的多人功能做准备。

## 学习目标
- 掌握 lua-enet 的基本使用（服务器-客户端模型）。
- 实现简单的多人同步（位置）。
- 学习 Fennel 的宏系统，简化同步逻辑。
- 理解权威服务器模型。

## 代码实现

### Lua 版本（main.lua）
```lua
local enet = require("enet")
local json = require("json")  -- 需要 json 库
local host, server

function love.load()
    if arg[2] == "server" then
        host = enet.host_create("localhost:6789")
    else
        host = enet.host_create()
        server = host:connect("localhost:6789")
    end
    players = {[1] = {x = 100, y = 300, id = 1}, [2] = {x = 700, y = 300, id = 2}}
end

function love.update(dt)
    local event = host:service(100)
    if event then
        if event.type == "receive" then
            local data = json.decode(event.data)
            players[data.id].x = data.x
            players[data.id].y = data.y
        elseif event.type == "connect" then
            print("Player connected!")
        end
    end
    if server then
        if love.keyboard.isDown("left") then
            players[1].x = players[1].x - 200 * dt
        elseif love.keyboard.isDown("right") then
            players[1].x = players[1].x + 200 * dt
        end
        host:broadcast(json.encode({id = 1, x = players[1].x, y = players[1].y}))
    end
end

function love.draw()
    for _, player in pairs(players) do
        love.graphics.rectangle("fill", player.x, player.y, 32, 32)
    end
end

```


### fennel 版本
```lua

(local enet (require :enet))
(local json (require :json))
(local host nil)
(local server nil)

(fn love.load []
  (if (= (. arg 2) "server")
    (set host (: enet :host_create "localhost:6789"))
    (do
      (set host (: enet :host_create))
      (set server (: host :connect "localhost:6789"))))
  (set players {1 {:x 100 :y 300 :id 1} 2 {:x 700 :y 300 :id 2}}))

(fn love.update [dt]
  (let [event (: host :service 100)]
    (when event
      (match event.type
        :receive (let [data (: json :decode event.data)]
                   (set (. players data.id :x) data.x)
                   (set (. players data.id :y) data.y))
        :connect (print "Player connected!"))))
  (when server
    (when (: love.keyboard :isDown "left")
      (set (. players 1 :x) (- (. players 1 :x) (* 200 dt))))
    (when (: love.keyboard :isDown "right")
      (set (. players 1 :x) (+ (. players 1 :x) (* 200 dt))))
    (: host :broadcast (: json :encode {:id 1 :x (. players 1 :x) :y (. players 1 :y)}))))

(fn love.draw []
  (each [_ player players]
    (: love.graphics :rectangle "fill" player.x player.y 32 32)))

```