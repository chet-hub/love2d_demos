-- mods/core/init.lua - Core Mod for Minimal Minecraft-like Gameplay
-- Features: Player movement, block interaction, inventory, pickup, crafting, NPC combat

local block_types = {}  -- {type: {name, color}}
local entity_types = {}  -- {type: fn(id, args)}
local items = {}  -- {type: {name}}
local recipes = {}  -- {id: {inputs, output}}
local inventory = {}  -- {slot: {item, count}}
local hotbar_selected = 1
local player_id = nil

local function init(api)
    -- Components
    concord.component("position", function(c, x, y) c.pos = { x = x or 0, y = y or 0 } end)
    concord.component("velocity", function(c, vx, vy) c.vel = { x = vx or 0, y = vy or 0 } end)
    concord.component("render", function(c, color, size) c.color = color; c.size = size end)
    concord.component("health", function(c, hp) c.hp = hp end)
    concord.component("player", function(c) end)
    concord.component("ai", function(c, speed) c.speed = speed end)
    concord.component("pickup", function(c, item) c.item = item end)

    -- Systems
    local movement_system = concord.system({
        entities = { "position", "velocity" },
        update = function(self, dt)
            for _, e in ipairs(self.entities) do
                local pos = e:get("position").pos
                local vel = e:get("velocity").vel
                local tx = math.floor((pos.x + vel.x * dt) / api.config.tile_size)
                local ty = math.floor((pos.y + vel.y * dt) / api.config.tile_size)
                if not api.get_tile(tx, ty) then
                    pos.x = pos.x + vel.x * dt
                    pos.y = pos.y + vel.y * dt
                end
            end
        end
    })

    local ai_system = concord.system({
        entities = { "position", "velocity", "ai" },
        update = function(self, dt)
            for _, e in ipairs(self.entities) do
                local pos = e:get("position").pos
                local vel = e:get("velocity").vel
                local ai = e:get("ai")
                local target = self.world:getEntitiesWithComponent("player")
                local target_pos = target[1] and target[1]:get("position").pos
                if target_pos then
                    local dx = target_pos.x - pos.x
                    local dy = target_pos.y - pos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0 then
                        vel.x = (dx / dist) * ai.speed
                        vel.y = (dy / dist) * ai.speed
                    end
                end
            end
        end
    })

    local combat_system = concord.system({
        entities = { "position", "health" },
        players = { "player", "position", "health" },
        update = function(self, dt)
            if #self.players > 0 then
                local player = self.players[1]
                local ppos = player:get("position").pos
                for _, e in ipairs(self.entities) do
                    if e ~= player then
                        local pos = e:get("position").pos
                        local dx = ppos.x - pos.x
                        local dy = ppos.y - pos.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist < api.config.tile_size then
                            local php = player:get("health").hp
                            local ehp = e:get("health").hp
                            php = php - 10 * dt
                            ehp = ehp - 5 * dt
                            player:get("health").hp = php
                            e:get("health").hp = ehp
                            if php <= 0 then print("Player died!") end
                            if ehp <= 0 then
                                e:destroy()
                                api.emit("combat", player, e)
                            end
                        end
                    end
                end
            end
        end
    })

    local pickup_system = concord.system({
        pickups = { "pickup", "position" },
        players = { "player", "position" },
        update = function(self, dt)
            if #self.players > 0 then
                local ppos = self.players[1]:get("position").pos
                for _, e in ipairs(self.pickups) do
                    local pos = e:get("position").pos
                    local dx = pos.x - ppos.x
                    local dy = pos.y - ppos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < api.config.tile_size then
                        add_item(e:get("pickup").item, 1)
                        e:destroy()
                    end
                end
            end
        end
    })

    local render_system = concord.system({
        entities = { "position", "render" },
        draw = function(self)
            for key, _ in pairs(loaded_chunks) do
                local cx, cy = key:match("(-?%d+),(-?%d+)")
                cx, cy = tonumber(cx), tonumber(cy)
                local chunk = chunks[key]
                for lx = 1, api.config.chunk_size do
                    for ly = 1, api.config.chunk_size do
                        local block = chunk.tiles[lx][ly]
                        if block then
                            local props = block_types[block] or {}
                            local color = props.color or { 1, 1, 1 }
                            local wx = cx * api.config.chunk_size + (lx - 1)
                            local wy = cy * api.config.chunk_size + (ly - 1)
                            love.graphics.setColor(color[1], color[2], color[3])
                            love.graphics.rectangle("fill", wx * api.config.tile_size, wy * api.config.tile_size, api.config.tile_size, api.config.tile_size)
                        end
                    end
                end
            end
            for _, e in ipairs(self.entities) do
                local pos = e:get("position").pos
                local render = e:get("render")
                love.graphics.setColor(render.color[1], render.color[2], render.color[3])
                if render.size == 8 then
                    love.graphics.circle("fill", pos.x, pos.y, render.size)
                else
                    love.graphics.rectangle("fill", pos.x, pos.y, render.size, render.size)
                end
            end
        end
    })

    api.world:addSystem(movement_system)
    api.world:addSystem(ai_system)
    api.world:addSystem(combat_system)
    api.world:addSystem(pickup_system)
    api.world:addSystem(render_system)

    -- Register Content
    api.register_block(1, { name = "dirt", color = { 0.5, 0.3, 0 } })
    api.register_block(2, { name = "stone", color = { 0.8, 0.8, 0.8 } })

    api.register_item(1, { name = "dirt" })
    api.register_item(2, { name = "stone" })

    api.register_entity_type("player", function(id, pos)
        local e = concord.entity(api.world)
        e:give("position", pos.x, pos.y)
        e:give("velocity", 0, 0)
        e:give("health", 100)
        e:give("render", { 0, 1, 0 }, api.config.tile_size)
        e:give("player")
        player_id = e
        return e
    end)

    api.register_entity_type("zombie", function(id, pos)
        local e = concord.entity(api.world)
        e:give("position", pos.x, pos.y)
        e:give("velocity", 0, 0)
        e:give("health", 50)
        e:give("render", { 1, 0, 0 }, api.config.tile_size)
        e:give("ai", 100)
        return e
    end)

    api.register_entity_type("pickup", function(id, pos, item)
        local e = concord.entity(api.world)
        e:give("position", pos.x, pos.y)
        e:give("render", { 0.5, 0.5, 0.5 }, 8)
        e:give("pickup", item)
        return e
    end)

    api.register_recipe({ inputs = { [1] = 2 }, output = { [2] = 1 } })

    -- Events
    api.world:on("mods-loaded", function()
        api.load_chunk(0, 0)
        entity_types.player(nil, { x = 0, y = -5 * api.config.tile_size })
        entity_types.zombie(nil, { x = 2 * api.config.tile_size, y = -5 * api.config.tile_size })
        add_item(1, 10)
        add_item(2, 5)
    end)

    api.world:on("generate-chunk", function(cx, cy, key)
        local chunk = chunks[key]
        for lx = 1, api.config.chunk_size do
            for ly = 1, api.config.chunk_size do
                local wy = cy * api.config.chunk_size + (ly - 1)
                chunk.tiles[lx][ly] = wy > 0 and nil or 1
            end
        end
    end)

    api.world:on("keypressed", function(key)
        if key == "space" then craft() end
        local num = tonumber(key)
        if num and num >= 1 and num <= 9 then
            hotbar_selected = num
        end
        if player_id and api.world:getEntities(player_id) then
            local player = api.world:getEntities(player_id)[1]
            local vel = player:get("velocity").vel
            vel.x = 0
            vel.y = 0
            if love.keyboard.isDown("a") then vel.x = -200 end
            if love.keyboard.isDown("d") then vel.x = 200 end
            if love.keyboard.isDown("w") then vel.y = -200 end
            if love.keyboard.isDown("s") then vel.y = 200 end
        end
    end)

    api.world:on("mousepressed", function(mx, my, button)
        local wx = math.floor(mx / api.config.tile_size)
        local wy = math.floor(my / api.config.tile_size)
        if button == 1 then
            local type = api.get_tile(wx, wy)
            if type then
                api.set_tile(wx, wy, nil)
                entity_types.pickup(nil, { x = wx * api.config.tile_size, y = wy * api.config.tile_size }, type)
                api.emit("block-broken", wx, wy, type)
            end
        elseif button == 2 then
            local selected = inventory[hotbar_selected]
            if selected and not api.get_tile(wx, wy) then
                api.set_tile(wx, wy, selected.item)
                selected.count = selected.count - 1
                if selected.count <= 0 then
                    inventory[hotbar_selected] = nil
                end
            end
        end
    end)

    api.world:on("register-block", function(type, props)
        block_types[type] = props
    end)

    api.world:on("register-entity-type", function(type, prefab_fn)
        entity_types[type] = prefab_fn
    end)

    api.world:on("register-item", function(type, props)
        items[type] = props
    end)

    api.world:on("register-recipe", function(recipe)
        table.insert(recipes, recipe)
    end)

    api.world:on("draw", function()
        love.graphics.setColor(1, 1, 1)
        for i = 1, 9 do
            local item = inventory[i]
            local x = (i - 1) * 40
            local y = love.graphics.getHeight() - 40
            love.graphics.rectangle("line", x, y, 32, 32)
            if item then
                love.graphics.print(tostring(item.item), x, y)
                love.graphics.print(tostring(item.count), x + 20, y)
            end
            if i == hotbar_selected then
                love.graphics.setColor(1, 1, 0)
                love.graphics.rectangle("line", x, y, 32, 32)
                love.graphics.setColor(1, 1, 1)
            end
        end
    end)
end

local function craft()
    for _, recipe in ipairs(recipes) do
        local can_craft = true
        for itype, count in pairs(recipe.inputs) do
            if count_item(itype) < count then
                can_craft = false
                break
            end
        end
        if can_craft then
            for itype, count in pairs(recipe.inputs) do
                remove_item(itype, count)
            end
            for otype, count in pairs(recipe.output) do
                add_item(otype, count)
            end
        end
    end
end

local function count_item(type)
    local total = 0
    for _, slot in pairs(inventory) do
        if slot.item == type then
            total = total + slot.count
        end
    end
    return total
end

local function remove_item(type, amount)
    local rem = amount
    for i, slot in pairs(inventory) do
        if slot.item == type and rem > 0 then
            local remove = math.min(rem, slot.count)
            slot.count = slot.count - remove
            rem = rem - remove
            if slot.count <= 0 then
                inventory[i] = nil
            end
        end
    end
end

local function add_item(type, amount)
    local slot = find_slot(type) or find_empty()
    local inv_item = inventory[slot]
    if inv_item then
        inv_item.count = inv_item.count + amount
    else
        inventory[slot] = { item = type, count = amount }
    end
end

local function find_slot(type)
    for i = 1, 9 do
        if inventory[i] and inventory[i].item == type then
            return i
        end
    end
    return nil
end

local function find_empty()
    for i = 1, 9 do
        if not inventory[i] then
            return i
        end
    end
    return 1
end

return { init = init }