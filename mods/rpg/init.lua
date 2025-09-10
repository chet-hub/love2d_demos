-- mods/rpg/init.lua - RPG Mod for Experience, Levels, and Skills
-- Features: XP on block break/kill, leveling, dash skill

local rpg_data = { xp = 0, level = 1, max_xp = 100 }
local skill_cooldown = 0

local function init(api)
    -- Component: RPG stats
    concord.component("rpg", function(c, xp, level)
        c.xp = xp or 0
        c.level = level or 1
        c.max_xp = 100 * c.level
    end)

    -- System: Update RPG stats
    local rpg_system = concord.system({
        entities = { "rpg", "player" },
        update = function(self, dt)
            for _, e in ipairs(self.entities) do
                local rpg = e:get("rpg")
                if rpg.xp >= rpg.max_xp then
                    rpg.level = rpg.level + 1
                    rpg.xp = rpg.xp - rpg.max_xp
                    rpg.max_xp = 100 * rpg.level
                    local health = e:get("health")
                    if health then
                        health.hp = health.hp + 10 * rpg.level
                    end
                end
            end
            if skill_cooldown > 0 then
                skill_cooldown = skill_cooldown - dt
            end
        end
    })

    api.world:addSystem(rpg_system)

    -- Add RPG component to player
    api.world:on("register-entity-type", function(type, prefab_fn)
        if type == "player" then
            local old_prefab = prefab_fn
            api.register_entity_type(type, function(id, pos)
                local e = old_prefab(id, pos)
                e:give("rpg", rpg_data.xp, rpg_data.level)
                return e
            end)
        end
    end)

    -- XP on block break
    api.world:on("block-broken", function(wx, wy, type)
        local players = api.world:getEntitiesWithComponent("player")
        if #players > 0 then
            local player = players[1]
            local rpg = player:get("rpg")
            if rpg then
                rpg.xp = rpg.xp + 10
            end
        end
    end)

    -- XP on enemy kill
    api.world:on("combat", function(e1, e2)
        if e1:get("player") and e2:get("health") and e2:get("health").hp <= 0 then
            local rpg = e1:get("rpg")
            if rpg then
                rpg.xp = rpg.xp + 50
            end
        end
    end)

    -- Dash skill on Q
    api.world:on("keypressed", function(key)
        if key == "q" and skill_cooldown <= 0 then
            local players = api.world:getEntitiesWithComponent("player")
            if #players > 0 then
                local player = players[1]
                local vel = player:get("velocity").vel
                local speed = 500
                if love.keyboard.isDown("a") then vel.x = -speed end
                if love.keyboard.isDown("d") then vel.x = speed end
                if love.keyboard.isDown("w") then vel.y = -speed end
                if love.keyboard.isDown("s") then vel.y = speed end
                skill_cooldown = 5
            end
        end
    end)

    -- Draw RPG stats
    api.world:on("draw", function()
        local players = api.world:getEntitiesWithComponent("player")
        if #players > 0 then
            local rpg = players[1]:get("rpg")
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Level: " .. rpg.level, 10, 10)
            love.graphics.print("XP: " .. rpg.xp .. "/" .. rpg.max_xp, 10, 30)
        end
    end)
end

return { init = init }