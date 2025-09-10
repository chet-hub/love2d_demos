-- mods/shooter/init.lua - Shooter Mod for Guns and Bullets
-- Features: Pistol weapon, bullet entities, shooting mechanics

local weapons = { pistol = { damage = 20, speed = 500, ammo = 10 } }
local current_weapon = "pistol"
local ammo = weapons.pistol.ammo

local function init(api)
    -- Component: Bullet
    concord.component("bullet", function(c, damage, speed)
        c.damage = damage
        c.speed = speed
    end)

    -- System: Bullet movement and collision
    local bullet_system = concord.system({
        bullets = { "bullet", "position", "velocity" },
        enemies = { "health", "position" },
        update = function(self, dt)
            for _, bullet in ipairs(self.bullets) do
                local pos = bullet:get("position").pos
                local vel = bullet:get("velocity").vel
                for _, enemy in ipairs(self.enemies) do
                    local epos = enemy:get("position").pos
                    local dx = pos.x - epos.x
                    local dy = pos.y - epos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < api.config.tile_size then
                        local health = enemy:get("health")
                        health.hp = health.hp - bullet:get("bullet").damage
                        bullet:destroy()
                        if health.hp <= 0 then
                            enemy:destroy()
                            api.emit("combat", bullet, enemy)
                        end
                        break
                    end
                end
            end
        end
    })

    api.world:addSystem(bullet_system)

    -- Register bullet entity type
    api.register_entity_type("bullet", function(id, pos, dir)
        local e = concord.entity(api.world)
        e:give("position", pos.x, pos.y)
        e:give("velocity", dir.x * weapons[current_weapon].speed, dir.y * weapons[current_weapon].speed)
        e:give("render", { 1, 1, 0 }, 8)
        e:give("bullet", weapons[current_weapon].damage, weapons[current_weapon].speed)
        return e
    end)

    -- Shoot on left click
    api.world:on("mousepressed", function(mx, my, button)
        if button == 1 and ammo > 0 then
            local players = api.world:getEntitiesWithComponent("player")
            if #players > 0 then
                local player = players[1]
                local ppos = player:get("position").pos
                local dx = mx - ppos.x
                local dy = my - ppos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    ammo = ammo - 1
                    api.register_entity_type("bullet")(nil, {
                        x = ppos.x + dx / dist * api.config.tile_size,
                        y = ppos.y + dy / dist * api.config.tile_size
                    }, { x = dx / dist, y = dy / dist })
                end
            end
        end
    end)

    -- Switch weapon on E
    api.world:on("keypressed", function(key)
        if key == "e" then
            current_weapon = "pistol"
            ammo = weapons[current_weapon].ammo
        end
    end)

    -- Draw weapon and ammo
    api.world:on("draw", function()
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Weapon: " .. current_weapon, 10, 50)
        love.graphics.print("Ammo: " .. ammo, 10, 70)
    end)
end

return { init = init }