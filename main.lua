
function love.load()
    -- window setup
    love.window.setTitle("Mark Mage")
    -- love.window.setFullscreen(true)
    love.window.setMode(1920, 1080, {
        fullscreen = false,
        fullscreentype = "desktop",
        vsync = 1,
        resizable = true,
        borderless = true,
    })

    disable_enemies = true

    -- graphics setup
    spritesheet = love.graphics.newImage("assets/graphics/markmage.png");

    -- audio setup
    sounds = {
        scored =           love.audio.newSource("assets/sounds/scored.wav", "static"),
        teleport =         love.audio.newSource("assets/sounds/teleport.wav", "static"),
        failed_teleport =  love.audio.newSource("assets/sounds/failed_teleport.wav", "static"),
        projectile_shot =  love.audio.newSource("assets/sounds/projectile_shot.wav", "static"),
        lost_gate =        love.audio.newSource("assets/sounds/lost_gate.wav", "static"),
    }

    state = {
        start_time = love.timer.getTime(),
        last_spawn_time = love.timer.getTime(),
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
        pressed = {},
        show_spellbook = false,
        show_hitboxes = false,
        score_font = love.graphics.newFont(30),
    }

    local w = spritesheet:getWidth()
    local h = spritesheet:getHeight()
    local size = 8*4

    sprites = {
        player_idle = {
            type = "animation",
            count = 5,
            quads = {},
        },
        player_walk = {
            type = "animation",
            count = 4,
            quads = {},
        },
        player_cast = {
            type = "animation",
            count = 7,
            quads = {},
        },
        enemy_idle = {
            type = "animation",
            count = 5,
            quads = {},
        },
        enemy_death = {
            type = "animation",
            count = 5,
            quads = {},
        },
        shield = {
            type = "sprite",
            quad = nil,
        },
        mark = {
            type = "sprite",
            quad = nil,
        },
        gate = {
            type = "sprite",
            quad = nil,
        },
        projectile = {
            type = "sprite",
            quad = nil,
        },
        arrow_up = {
            type = "sprite",
            quad = nil,
        },
        arrow_down = {
            type = "sprite",
            quad = nil,
        },
        arrow_right = {
            type = "sprite",
            quad = nil,
        },
        arrow_left = {
            type = "sprite",
            quad = nil,
        },
        ranged_enemy_idle = {
            type = "animation",
            count = 5,
            quads = {},
        },
        ranged_enemy_death = {
            type = "animation",
            count = 5,
            quads = {},
        },
    }

    local ordered = {}
    table.insert(ordered, "player_idle")
    table.insert(ordered, "player_walk")
    table.insert(ordered, "player_cast")
    table.insert(ordered, "enemy_idle")
    table.insert(ordered, "enemy_death")
    table.insert(ordered, "shield")
    table.insert(ordered, "mark")
    table.insert(ordered, "gate")
    table.insert(ordered, "projectile")
    table.insert(ordered, "arrow_up")
    table.insert(ordered, "arrow_down")
    table.insert(ordered, "arrow_right")
    table.insert(ordered, "arrow_left")
    table.insert(ordered, "ranged_enemy_idle")
    table.insert(ordered, "ranged_enemy_death")

    -- fill in the quad lists
    local current_x = 0
    for _, asset_name in ipairs(ordered) do
        local object = sprites[asset_name]
        if object.type == "animation" then
            for index = 0, object.count-1 do
                local quad = love.graphics.newQuad(current_x, 0, size, size, w, h)
                table.insert(object.quads, quad)
                current_x = current_x + size
            end
        else
            object.quad = love.graphics.newQuad(current_x, 0, size, size, w, h)
            current_x = current_x + size
        end

    end

    -- TODO(bkaylor): possible spell reworks
    --   idea 1:
    --     drag and drop to create spells
    --     have one version of "swap", one version of "push/pull"
    --     and you slot in nouns (player, mark, enemy, projectile) from a bank
    --   idea 2:
    --     spells are premade, but you assign their recipe
    --     using some ui, maybe similar to spell_mapping_page_mockup.png

    -- spell data
    -- TODO(bkaylor): Slow enemies
    -- TODO(bkaylor): Slow projectiles 
    -- TODO(bkaylor): Fast player
    -- TODO(bkaylor): Reflect projectiles
    -- TODO(bkaylor): Swap with projectile
    spells = {
        projectile = {
            recipe = {"left", "left"},
            procedure = function()

                love.audio.play(sounds.projectile_shot)

                local projectile = {
                    x = player.x + player.w/4,
                    y = player.y + player.h/4,
                    w = 8*2,
                    h = 8*2,
                    hitbox = {
                        x_offset = 2,
                        y_offset = 2,
                        w = 8*2-4,
                        h = 8*2-4,
                    },
                    direction = get_normalized_vector_between(player.mark, player),
                    speed = 550,
                    pierce = false,
                }

                projectile.x = projectile.x + projectile.direction.x*25
                projectile.y = projectile.y + projectile.direction.y*25

                table.insert(projectiles, projectile)
            end,
        },
        swap = {
            recipe = {"up", "down"},
            procedure = function()
                love.audio.play(sounds.teleport)

                player.x, player.y, player.mark.x, player.mark.y =
                player.mark.x, player.mark.y, player.x, player.y
            end,
        },
        reflect_mark = {
            recipe = {"left", "right"},
            procedure = function()
                local vec = get_vector_between(player, player.mark)
                local x = player.mark.x + 2*vec.x
                local y = player.mark.y + 2*vec.y

                try_teleport(player.mark, x, y)
            end,
        },
        reflect_player = {
            recipe = {"right", "left"},
            procedure = function()
                local vec = get_vector_between(player.mark, player)
                local x = player.x + 2*vec.x
                local y = player.y + 2*vec.y

                try_teleport(player, x, y)
            end,
        },
        send = {
            recipe = {"right", "right"},
            procedure = function()
                -- define the circle around the mark
                local mark_circle = {
                    center = {
                        x = player.mark.x + player.mark.w/2,
                        y = player.mark.y + player.mark.h/2,
                    },
                    radius = 200,
                }

                make_send_spell_circle(mark_circle)
                for i, gate in ipairs(gates) do
                    if hitbox_and_circle_collide(gate, mark_circle) then
                        -- start the gate's close timer
                        begin_close_gate(i)
                    end
                end
            end,
        },
        apply_burst = {
            recipe = {"down", "down", "left"},
            procedure = function()
                -- define the circle around the mark
                local mark_circle = {
                    center = {
                        x = player.mark.x + player.mark.w/2,
                        y = player.mark.y + player.mark.h/2,
                    },
                    radius = 200,
                }

                make_send_spell_circle(mark_circle)
                for i, gate in ipairs(gates) do
                    if hitbox_and_circle_collide(gate, mark_circle) then
                        -- change gate type
                        gate.type = "spread"
                    end
                end
            end,
        },
        apply_pierce = {
            recipe = {"down", "down", "right"},
            procedure = function()
                -- define the circle around the mark
                local mark_circle = {
                    center = {
                        x = player.mark.x + player.mark.w/2,
                        y = player.mark.y + player.mark.h/2,
                    },
                    radius = 200,
                }

                make_send_spell_circle(mark_circle)
                for i, gate in ipairs(gates) do
                    if hitbox_and_circle_collide(gate, mark_circle) then
                        -- change gate type
                        gate.type = "pierce"
                    end
                end
            end,
        },
        apply_size = {
            recipe = {"down", "down", "up"},
            procedure = function()
                -- define the circle around the mark
                local mark_circle = {
                    center = {
                        x = player.mark.x + player.mark.w/2,
                        y = player.mark.y + player.mark.h/2,
                    },
                    radius = 200,
                }

                make_send_spell_circle(mark_circle)
                for i, gate in ipairs(gates) do
                    if hitbox_and_circle_collide(gate, mark_circle) then
                        -- change gate type
                        gate.type = "size"
                    end
                end
            end,
        },
        stop_mark = {
            recipe = {"up", "up", "up"},
            procedure = function()
                player.mark.moving = false
            end,
        },
        shield = {
            recipe = {"down", "down", "down"},
            procedure = function()
                player.shielded = true
            end,
        },
        push = {
            recipe = {"up", "right", "down"},
            procedure = function()
                player.mark.moving = true

                -- get push destination
                local vec_between = get_vector_between(player.mark, player)
                local stretched = set_length_of_vec2(vec_between, 500)
                local new_x = player.mark.x + stretched.x
                local new_y = player.mark.y + stretched.y

                player.mark.movement = {
                    start = {x=player.mark.x, y=player.mark.y},
                    finish = {x=new_x, y=new_y},
                    progress = 0,
                    timer = 0,
                    max_timer = 2.0,
                }

                player.mark.movement.timer = player.mark.movement.timer
            end,
        },
        pull = {
            recipe = {"up", "left", "down"},
            procedure = function()
                player.mark.moving = true

                -- get push destination
                local vec_between = get_vector_between(player.mark, player)
                local stretched = set_length_of_vec2(vec_between, 500)
                local new_x = player.mark.x - stretched.x
                local new_y = player.mark.y - stretched.y

                player.mark.movement = {
                    start = {x=player.mark.x, y=player.mark.y},
                    finish = {x=new_x, y=new_y},
                    progress = 0,
                    timer = 0,
                    max_timer = 2.0,
                }

                player.mark.movement.timer = player.mark.movement.timer
            end,
        },
    }

    player = {
        x = state.width/2, 
        y = state.height/2, 
        w = 8*4, 
        h = 8*4,
        hitbox = {
            x_offset = 4, 
            y_offset = 0, 
            w = 8*3, 
            h = 8*4,
        },
        speed = 100,
        casting = false,
        cast_queue = {},
        shielded = false,
        mark = {
            held = true,
            x = state.width/2,
            y = state.height/2,
            w = 8*4,
            h = 8*4,
            hitbox = {
                x_offset = 0,
                y_offset = 0,
                w = 8*4,
                h = 8*4,
            },
            moving = false,
            movement = {
                start = {x=0, y=0},
                finish = {x=0, y=0},
                progress = 0,
                timer = 0,
                max_timer = 3.0,
            }
        },
        score = 0,
        animation = {
            state = "player_idle",
            progress = 0,
        },
        facing = "right"
    }

    enemies = {}

    projectiles = {}

    gates = {}

    poofs = {}

    send_circles = {}
end

function make_projectile(x, y, direction)
    love.audio.play(sounds.projectile_shot)

    local projectile = {
        x = x,
        y = y,
        w = 8*2,
        h = 8*2,
        hitbox = {
            x_offset = 2,
            y_offset = 2,
            w = 8*2-4,
            h = 8*2-4,
        },
        direction = direction,
        speed = 550,
        pierce = false,
    }

    table.insert(projectiles, projectile)
end

function enemy_shoot_projectile(enemy)
    love.audio.play(sounds.projectile_shot)

    local projectile = {
        x = enemy.x + enemy.w/4,
        y = enemy.y + enemy.h/4,
        w = 8*2,
        h = 8*2,
        hitbox = {
            x_offset = 2,
            y_offset = 2,
            w = 8*2-4,
            h = 8*2-4,
        },
        direction = get_normalized_vector_between(player, enemy),
        speed = 550,
        pierce = false,
    }

    projectile.x = projectile.x + projectile.direction.x*25
    projectile.y = projectile.y + projectile.direction.y*25

    table.insert(projectiles, projectile)
end

function normalize_vec2(a)
    local scale = math.sqrt(a.x*a.x + a.y*a.y)
    local result = {x=a.x/scale, y=a.y/scale}
    return result 
end

function set_length_of_vec2(a, scale)
    local unit = normalize_vec2(a)
    local result = {x=unit.x*scale, y=unit.y*scale}
    return result
end

function lerp(t, a, b)
    return a + (b-a)*t
end

function easeInOutQuart(t, a, b)
    value = 0

    if t < 0.5 then
        value = 8*t*t*t*t
    else
        value = 1 - (((-2*t + 2)^4)/2)
    end

    return a + (b-a)*value
end

function try_teleport(e, x, y)
    if x > 0 and x < (state.width - e.w) and
       y > 0 and y < (state.height - e.h) then

       love.audio.play(sounds.teleport)

       local poof = {
           source = {
               x = e.x,
               y = e.y,
           },
           destination = {
               x = x,
               y = y,
           },
           time = 0,
       }

       table.insert(poofs, poof)

       e.x = x
       e.y = y

       return true
   else
       love.audio.play(sounds.failed_teleport)
       return false
   end
end

function begin_close_gate(i)
    gates[i].closing = true
end

function increase_score()
    player.score = player.score + 1
    love.audio.play(sounds.scored)
end

function destroy_enemy(i)
    increase_score()

    local enemy = enemies[i]
    enemy.state = "dying"
    enemy.state_timer = 0
    if enemy.type == "ranged" then
        enemy.animation.state = "ranged_enemy_death"
    else
        enemy.animation.state = "enemy_death"
    end
    enemy.animation.progress = 0
    -- table.remove(enemies, i)
end

function get_vector_between(a, b)
    local vec = {
        x = a.x - b.x,
        y = a.y - b.y,
    }
    return vec
end

function get_normalized_vector_between(a, b)
    local vec = {
        x = a.x - b.x,
        y = a.y - b.y,
    }

    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y)

    vec.x = vec.x / length
    vec.y = vec.y / length

    return vec
end

function normalize(a)
    local length = math.sqrt(a.x * a.x + a.y * a.y)
    a.x = a.x / length
    a.y = a.y / length

    return a
end

function make_send_spell_circle(circle)
    local circle_info = {
        center = {
            x = circle.center.x,
            y = circle.center.y,
        },
        radius = circle.radius,
        timer = 0,
        timer_max = 2.0,
    }

    circle_info.timer = circle_info.timer_max

    table.insert(send_circles, circle_info)
end

function restart()
    love.load()
end

function collide_old(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and 
           a.y < b.y + b.h and a.h + a.y > b.y 
end

function collide(a_orig, b_orig)
    a = {
        x = a_orig.x + a_orig.hitbox.x_offset,
        y = a_orig.y + a_orig.hitbox.y_offset,
        w = a_orig.hitbox.w,
        h = a_orig.hitbox.h,
    }

    b = {
        x = b_orig.x + b_orig.hitbox.x_offset,
        y = b_orig.y + b_orig.hitbox.y_offset,
        w = b_orig.hitbox.w,
        h = b_orig.hitbox.h,
    }

    return a.x < b.x + b.w and 
           a.x + a.w > b.x and 
           a.y < b.y + b.h and 
           a.h + a.y > b.y 
end

function hitbox_and_circle_collide(thing, circle)
    local corner1 = {
        x = thing.x + thing.hitbox.x_offset,
        y = thing.y + thing.hitbox.y_offset,
    }

    local corner2 = {
        x = thing.x + thing.hitbox.x_offset + thing.hitbox.w,
        y = thing.y + thing.hitbox.y_offset,
    }

    local corner3 = {
        x = thing.x + thing.hitbox.x_offset,
        y = thing.y + thing.hitbox.y_offset + thing.hitbox.h,
    }

    local corner4 = {
        x = thing.x + thing.hitbox.x_offset + thing.hitbox.w,
        y = thing.y + thing.hitbox.y_offset + thing.hitbox.h,
    }

    local corners = {corner1, corner2, corner3, corner4}

    for _, corner in ipairs(corners) do
        local x_part = corner.x - circle.center.x
        local y_part = corner.y - circle.center.y
        local distance = math.sqrt(x_part^2 + y_part^2)
        if distance < circle.radius then
            return true
        end
    end

    return false
end

function make_enemy_at(x, y)
    local enemy = {
        x = x,
        y = y,
        w = 8*4, 
        h = 8*4,
        hitbox = {
            x_offset = 8,
            y_offset = 0,
            w = 8*2, 
            h = 8*4,
        },
        speed = 100,
        animation = {
            state = "enemy_idle",
            progress = 0,
        },
        state = "live",
        state_timer = 0,
    }

    table.insert(enemies, enemy)
end

function make_enemy()
    local enemy = {
        w = 8*4, 
        h = 8*4,
        hitbox = {
            x_offset = 8,
            y_offset = 0,
            w = 8*2, 
            h = 8*4,
        },
        speed = 100,
        animation = {
            state = "enemy_idle",
            progress = 0,
        },
        state = "live",
        state_timer = 0,
    }

    enemy.x = love.math.random(state.width - enemy.w)
    enemy.y = love.math.random(state.height - enemy.h) 

    table.insert(enemies, enemy)
end

function make_ranged_enemy()
    local enemy = {
        w = 8*4, 
        h = 8*4,
        hitbox = {
            x_offset = 8,
            y_offset = 0,
            w = 8*2, 
            h = 8*4,
        },
        speed = 100,
        animation = {
            state = "ranged_enemy_idle",
            progress = 0,
        },
        state = "live",
        state_timer = 0,
        cooldown_timer = 0,
        type = "ranged",
    }

    enemy.x = love.math.random(state.width - enemy.w)
    enemy.y = love.math.random(state.height - enemy.h) 

    table.insert(enemies, enemy)
end

function make_gate_at(x, y)
    local gate = {
        x = x,
        y = y,
        w = 8*4, 
        h = 8*4,
        timer = 3.0,
        closing = false,
        type = "normal",
        modifier_active = false,
    }
    gate.hitbox = {
        x_offset = 0,
        y_offset = 0,
        w = 8*4, 
        h = 8*4,
    }

    table.insert(gates, gate)
end

function make_gate()
    local gate = {
        w = 8*4, 
        h = 8*4,
        timer = 3.0,
        closing = false,
        type = "normal",
        modifier_active = false,
    }
    gate.x = love.math.random(state.width - gate.w)
    gate.y = love.math.random(state.height - gate.h)

    gate.hitbox = {
        x_offset = 0,
        y_offset = 0,
        w = 8*4, 
        h = 8*4,
    }

    table.insert(gates, gate)
end

function cast_matches(queue, recipe)
    if #queue ~= #recipe then
        return false
    end

    for i = 1, #queue do
        if queue[i] ~= recipe[i] then
            return false
        end
    end

    return true
end

function love.keypressed(key)
    state.pressed[key] = true
end

function love.keyreleased(key)
    state.pressed[key] = false
end

function pressed(key)
    return state.pressed[key]
end

function randomly_place_rect_in_rect(r1, r2)
    -- this function sets r1.x and r1.y such that r1 is inside r2
    r1.x = r2.x + love.math.random(r2.w - r1.w)
    r1.y = r2.y + love.math.random(r2.h - r1.h)

    return r1
end

function spawn_gameplay_event()
    local encounters = {
            function()
                make_enemy()
            end,

            function()
                make_ranged_enemy()
            end,

            function()
                make_gate()
            end,

            -- this is really weird and bad and buggy!
            function()
                local event_rect = {
                    w = 300,
                    h = 300,
                }

                event_rect = randomly_place_rect_in_rect(event_rect, {x=0,y=0,w=state.width,h=state.height})
                e1 = {w=8*4, h=8*4}
                e2 = {w=8*4, h=8*4}
                e3 = {w=8*4, h=8*4}
                e1 = randomly_place_rect_in_rect(e1, event_rect)
                e2 = randomly_place_rect_in_rect(e2, event_rect)
                e3 = randomly_place_rect_in_rect(e3, event_rect)
                make_enemy_at(e1.x, e1.y)
                make_enemy_at(e2.x, e2.y)
                make_enemy_at(e3.x, e3.y)
                make_gate_at(event_rect.x + event_rect.w/2, event_rect.y + event_rect.h/2)
            end,
    }

    if disable_enemies then
        local encounters_easy = {
            encounters[3],
        }

        encounters = encounters_easy
    end

    encounters[love.math.random(#encounters)]()

    -- local seed = love.math.random(3)
    -- if seed == 1 then
    --     make_enemy()
    -- else if seed == 2 then
    --     make_gate()
    -- else if seed == 3 then
    -- end

    state.last_spawn_time = love.timer.getTime()
end

function love.update(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end

    if love.keyboard.isDown("r") then
        restart()
    end

    -- toggle spellbook
    if pressed("b") then
        state.show_spellbook = not state.show_spellbook
    end

    if pressed("h") then
        state.show_hitboxes = not state.show_hitboxes
    end

    -- spawn something
    if pressed("n") then
        spawn_gameplay_event()
    end

    if not player.casting then
        -- TODO(bkaylor): moving diagonally shouldn't be faster than cardinally
        -- handle movement buttons
        player.moving = false
        if love.keyboard.isDown("w") then
            player.y = player.y - (player.speed * dt)
            player.moving = true
        end

        if love.keyboard.isDown("a") then
            player.x = player.x - (player.speed * dt)
            player.moving = true
            player.facing = "left"
        end

        if love.keyboard.isDown("s") then
            player.y = player.y + (player.speed * dt)
            player.moving = true
        end

        if love.keyboard.isDown("d") then
            player.x = player.x + (player.speed * dt)
            player.moving = true
            player.facing = "right"
        end

        -- casting start button
        if pressed("space") then
            player.casting = true
        end

        -- return mark button
        if love.keyboard.isDown("lctrl") then
            player.mark.x = player.x
            player.mark.y = player.y
        end
    else
        -- check if a recipe has been matched
        local did_cast = false
        local spell_to_cast
        for name, spell in pairs(spells) do
            if cast_matches(player.cast_queue, spell.recipe) then
                did_cast = true
                spell_to_cast = spell
            end
        end

        if did_cast then
            -- handle the spell
            spell_to_cast.procedure()

            player.casting = false
            player.cast_queue = {}

        else
            -- wait for the next button
            local directions = {"up", "left", "right", "down"}
            for _, direction in ipairs(directions) do
                if pressed(direction) then
                    table.insert(player.cast_queue, direction)
                end
            end

            -- or for a cancel
            if pressed("space") then
                player.casting = false
                player.cast_queue = {}
            end
        end
    end

    -- update mark
    if player.mark.moving then
        if player.mark.movement.timer > player.mark.movement.max_timer then
            -- end the movement
            player.mark.moving = false
        end

        local progress = player.mark.movement.timer / player.mark.movement.max_timer

        player.mark.x = easeInOutQuart(progress, player.mark.movement.start.x, player.mark.movement.finish.x)
        player.mark.y = easeInOutQuart(progress, player.mark.movement.start.y, player.mark.movement.finish.y)

        player.mark.movement.timer = player.mark.movement.timer + dt
    end

    -- update projectiles
    for i, projectile in ipairs(projectiles) do
        projectile.x = projectile.x + (projectile.direction.x * projectile.speed * dt)
        projectile.y = projectile.y + (projectile.direction.y * projectile.speed * dt)
    end

    -- update enemies
    for index, enemy in ipairs(enemies) do
        enemy.state_timer = enemy.state_timer + dt

        if enemy.state == "dying" then
            if enemy.state_timer > 0.3 then
                table.remove(enemies, index)
            end
        else
            if enemy.type == "ranged" then
                if enemy.cooldown_timer <= 0 then
                    enemy_shoot_projectile(enemy)
                    enemy.cooldown_timer = 3.0
                end
                enemy.cooldown_timer = enemy.cooldown_timer - dt
            else
                local vec = get_normalized_vector_between(player, enemy)
                enemy.x = enemy.x + vec.x * enemy.speed * dt
                enemy.y = enemy.y + vec.y * enemy.speed * dt
            end
        end

        enemy.animation.progress = enemy.animation.progress + dt

    end

    -- update gates
    local mark_circle = {
        center = {
            x = player.mark.x + player.mark.w/2,
            y = player.mark.y + player.mark.h/2,
        },
        radius = 300,
    }

    for i, gate in ipairs(gates) do
        if gate.closing then 
            -- verify mark is still there
            if hitbox_and_circle_collide(gate, mark_circle) then
                gate.timer = gate.timer - dt
                if gate.timer <= 0 then
                    -- TODO(bkaylor): instead of removing, change to become a projectile modifier
                    if gate.type == normal then
                        increase_score()
                        table.remove(gates, i)
                    else
                        gate.modifier_active = true
                        gate.closing = false
                        gate.timer = 3
                    end
                end
            else
                love.audio.play(sounds.lost_gate)

                gate.timer = 3
                gate.closing = false
            end
        end
    end

    -- update send circles
    for i, circle in ipairs(send_circles) do
        if circle.timer <= 0 then
            table.remove(send_circles, i)
        end

        circle.timer = circle.timer - dt
    end

    -- check projectile-enemy collision
    for i, projectile in ipairs(projectiles) do
        for j, enemy in ipairs(enemies) do
            if collide(projectile, enemy) then
                if not projectile.pierce then
                    table.remove(projectiles, i)
                end

                destroy_enemy(j)
            end
        end
    end

    -- check projectile-gate collision
    for i, projectile in ipairs(projectiles) do
        for j, gate in ipairs(gates) do
            if collide(projectile, gate) and gate.modifier_active then
                -- modify projectile (spawn new projectiles?) based on type of gate
                if gate.type == "size" then
                    local multiplier = 2
                    -- projectile.x = projectile.x - projectile.w/multiplier
                    -- projectile.y = projectile.y - projectile.h/multiplier
                    projectile.w = projectile.w * multiplier 
                    projectile.h = projectile.h * multiplier
                    projectile.hitbox.w = projectile.hitbox.w * multiplier 
                    projectile.hitbox.h = projectile.hitbox.h * multiplier
                elseif gate.type == "spread" then
                    make_projectile(projectile.x, projectile.y, normalize({x=1,y=1}))
                    make_projectile(projectile.x, projectile.y, normalize({x=-1,y=1}))
                    make_projectile(projectile.x, projectile.y, normalize({x=1,y=-1}))
                    make_projectile(projectile.x, projectile.y, normalize({x=-1,y=-1}))
                elseif gate.type == "pierce" then
                    projectile.pierce = true
                end

                gate.modifier_active = false
            end
        end
    end

    -- check player-enemy collision
    for _, enemy in ipairs(enemies) do
        if collide(player, enemy) then
            if player.shielded then
                enemy.x, enemy.y = player.mark.x, player.mark.y
                player.shielded = false
            else
                -- TODO(bkaylor): reset screen (or health?) instead of insta-restart
                restart()
            end
        end
    end

    -- check player-projectile collission
    for i, projectile in ipairs(projectiles) do
        if collide(player, projectile) then
            if player.shielded then
                projectile.x, projectile.y = player.mark.x, player.mark.y
                player.shielded = false
            else
                -- TODO(bkaylor): reset screen (or health?) instead of insta-restart
                restart()
            end
        end
    end

    -- spawn enemy or gate every some seconds
    -- TODO(bkaylor): more events? more interesting groupings of events?
    --                what if spawned encounters instead of individual things?
    local freq = 5
    if (love.timer.getTime() - state.last_spawn_time) > freq then
        spawn_gameplay_event()
        freq = freq - 0.5 
        if freq < 0.5 then
            freq = 0.5
        end
    end

    -- update pressed table
    for key, value in pairs(state.pressed) do
        state.pressed[key] = false
    end

    -- set player animation state
    if player.casting then
        if player.animation.state == "player_cast" then
            player.animation.progress = player.animation.progress + dt;
        else
            player.animation.state = "player_cast"
            player.animation.progress = 0
        end
    elseif player.moving then
        if player.animation.state == "player_walk" then
            player.animation.progress = player.animation.progress + dt;
        else
            player.animation.state = "player_walk"
            player.animation.progress = 0
        end
    else
        if player.animation.state == "player_idle" then
            player.animation.progress = player.animation.progress + dt;
        else
            player.animation.state = "player_idle"
            player.animation.progress = 0
        end
    end
end

function draw_arrows_at(arrows, x, y)
    local offset = 0
    for _, direction in ipairs(arrows) do
        local next_quad

        if direction == "up" then
            next_quad = sprites["arrow_up"].quad
        elseif direction == "down" then
            next_quad = sprites["arrow_down"].quad
        elseif direction == "right" then
            next_quad = sprites["arrow_right"].quad
        else
            next_quad = sprites["arrow_left"].quad
        end

        love.graphics.draw(spritesheet, next_quad, x+offset, y)

        offset = offset + 16
    end
end

function draw_hitbox(thing)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.rectangle("line", thing.x + thing.hitbox.x_offset, thing.y + thing.hitbox.y_offset, thing.hitbox.w, thing.hitbox.h)
    love.graphics.reset()
end

function love.draw()
    love.graphics.clear()

    -- draw background
    love.graphics.setColor(100, 255, 255, 0.1)
    for x=0, state.width, 100 do
        love.graphics.line(x, 0, x, state.height)
    end
    for y=0, state.height, 100 do
        love.graphics.line(0, y, state.width, y)
    end
    love.graphics.reset()

    -- draw gates
    for _, gate in ipairs(gates) do 
        if gate.type == "size" then
            love.graphics.setColor(255, 0, 0, 255)
        elseif gate.type == "spread" then
            love.graphics.setColor(0, 255, 0, 255)
        elseif gate.type == "pierce" then
            love.graphics.setColor(0, 0, 255, 255)
        end

        love.graphics.draw(spritesheet, sprites["gate"].quad, gate.x, gate.y)

        love.graphics.reset()

        if gate.modifier_active then
            love.graphics.circle("line", gate.x + gate.w/2, gate.y + gate.h/2, gate.w/2)
        end

        if state.show_hitboxes then
            draw_hitbox(gate)
        end
    end

    -- draw mark
    love.graphics.draw(spritesheet, sprites["mark"].quad, math.floor(player.mark.x), math.floor(player.mark.y))

    if state.show_hitboxes then
        draw_hitbox(player.mark)
    end

    if player.casting then
        -- draw line between player and mark
        love.graphics.line(player.x+player.w/2, player.y+player.h/2, 
                           player.mark.x+player.mark.w/2, player.mark.y+player.mark.h/2)
    end

    -- draw send circles
    for _, circle in ipairs(send_circles) do
        local greyscale = (circle.timer / circle.timer_max)
        greyscale = greyscale * greyscale

        love.graphics.setColor(10, 10, 10, greyscale)
        love.graphics.circle("line", circle.center.x, circle.center.y, circle.radius)
        love.graphics.reset()
    end

    -- draw enemies
    for _, enemy in ipairs(enemies) do 
        local animation = sprites[enemy.animation.state]
        local index = (math.floor(enemy.animation.progress*12) % animation.count) + 1
        local quad = animation.quads[index]
        love.graphics.draw(spritesheet, quad, enemy.x, enemy.y)

        if state.show_hitboxes then
            draw_hitbox(enemy)
        end
    end

    -- draw player
    local animation = sprites[player.animation.state]
    local index = (math.floor(player.animation.progress*12) % animation.count) + 1
    local quad = animation.quads[index]

    local flip = false
    if player.facing == "left" then
        flip = true
    end

    local scale = 1
    if flip then
        scale = -1
    end

    local bump = 0
    if flip then
        bump = player.w
    end

    love.graphics.draw(spritesheet, quad, player.x, player.y, 0, scale, 1, bump, 0)

    if state.show_hitboxes then
        draw_hitbox(player)
    end

    -- draw player's shield
    if player.shielded then
        love.graphics.draw(spritesheet, sprites["shield"].quad, player.x, player.y)
    end

    -- draw player's cast queue
    draw_arrows_at(player.cast_queue, player.x, player.y-20)

    -- draw projectiles
    for _, projectile in ipairs(projectiles) do
        love.graphics.draw(spritesheet, sprites["projectile"].quad, projectile.x, projectile.y, projectile.w/16, projectile.h/16)

        if state.show_hitboxes then
            draw_hitbox(projectile)
        end
    end

    -- draw gate timers
    -- love.graphics.setLineWidth(2)
    -- love.graphics.setColor(0, 255, 0, 255)
    -- for _, gate in ipairs(gates) do 
    --     if gate.closing then
    --         line_x1 = gate.x
    --         line_x2 = gate.x + (gate.h * ((3.0 - gate.timer)/3.0))
    --         line_y = gate.y + gate.h + 3 
    --         love.graphics.line(line_x1, line_y, line_x2, line_y)
    --     end
    -- end
    -- love.graphics.reset()
    
    -- draw connecting and progress lines
    love.graphics.setLineWidth(1)
    for _, gate in ipairs(gates) do 
        if gate.closing then
            -- draw connecting lines
            love.graphics.setColor(255, 0, 0, 255)
            local x1 = player.mark.x + player.mark.w/2
            local y1 = player.mark.y + player.mark.h/2
            local x2 = gate.x + gate.w/2
            local y2 = gate.y + gate.h/2
            love.graphics.line(x1, y1, x2, y2)

            -- draw progress lines
            love.graphics.setColor(0, 255, 0, 255)
            local x1 = player.mark.x + player.mark.w/2
            local y1 = player.mark.y + player.mark.h/2
            local vec = get_vector_between(gate, player.mark)
            vec.x = vec.x * ((3.0 - gate.timer)/3.0)
            vec.y = vec.y * ((3.0 - gate.timer)/3.0)
            local x2 = x1 + vec.x
            local y2 = y1 + vec.y
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    love.graphics.reset()

    -- TODO(bkaylor): draw poofs?

    -- draw score
    love.graphics.print(player.score, state.score_font, state.width/2, 10)

    -- draw debug stuff
    if false then
        local x = 100 
        local y = 20
        local y_increment = 20
        for _, circle in ipairs(send_circles) do
            love.graphics.print(circle.center.x .. "," .. circle.center.y .. " " .. circle.radius, x, y)

            y = y + y_increment
        end
    end

    -- draw spellbook
    if state.show_spellbook then
        local x = 10
        local y = 20
        local y_increment = 20
        for spell_name, spell_data in pairs(spells) do
            love.graphics.print(spell_name, x, y)
            y = y + y_increment

            draw_arrows_at(spell_data.recipe, x, y)
            y = y + y_increment
        end
    end

    -- if spellbook is open, also draw various spell guides
    if state.show_spellbook then
        -- projectile
        love.graphics.setColor(10, 10, 10, 0.1)
        local player_center = {x = player.x + player.w/2, y = player.y + player.h/2}
        local mark_center = {x = player.mark.x + player.mark.w/2, y = player.mark.y + player.mark.h/2}
        local vec = get_normalized_vector_between(player_center, mark_center)
        vec.x = vec.x * 10000
        vec.y = vec.y * 10000
        love.graphics.line(player_center.x, player_center.y, player_center.x - vec.x, player_center.y - vec.y)
        love.graphics.reset()
        -- swap
        -- reflect mark
        love.graphics.setColor(10, 10, 10, 0.1)
        local player_center = {x = player.x + player.w/2, y = player.y + player.h/2}
        local mark_center = {x = player.mark.x + player.mark.w/2, y = player.mark.y + player.mark.h/2}
        local vec = get_vector_between(player_center, mark_center)
        local circle = {x = mark_center.x + 2*vec.x, y = mark_center.y + 2*vec.y, radius=10}
        love.graphics.circle("fill", circle.x, circle.y, circle.radius)
        love.graphics.reset()
        -- reflect player
        love.graphics.setColor(10, 10, 10, 0.1)
        local player_center = {x = player.x + player.w/2, y = player.y + player.h/2}
        local mark_center = {x = player.mark.x + player.mark.w/2, y = player.mark.y + player.mark.h/2}
        local vec = get_vector_between(mark_center, player_center)
        local circle = {x = player_center.x + 2*vec.x, y = player_center.y + 2*vec.y, radius=10}
        love.graphics.circle("fill", circle.x, circle.y, circle.radius)
        love.graphics.reset()
        -- send
        -- stop_mark
        -- shield
        -- push
        -- pull
    end
end

