
function love.load()
    state = {
        start_time = love.timer.getTime(),
        last_spawn_time = love.timer.getTime(),
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
        pressed = {},
        show_spellbook = false,
        score_font = love.graphics.newFont(30),
    }

    spritesheet = love.graphics.newImage("spritesheet.png")
    local w = spritesheet:getWidth()
    local h = spritesheet:getHeight()
    local size = 8*4
    quads = {
        shield          = love.graphics.newQuad(0,        size*5,     size,   size,   w, h),
        mark            = love.graphics.newQuad(0,        size*6,     size,   size,   w, h),
        gate            = love.graphics.newQuad(size,     size*6,     size,   size,   w, h),
        projectile      = love.graphics.newQuad(0,        size*7,     size/2, size/2, w, h),
        arrow_up        = love.graphics.newQuad(0,        size*15/2,  size/2, size/2, w, h),
        arrow_down      = love.graphics.newQuad(size/2,   size*15/2,  size/2, size/2, w, h),
        arrow_right     = love.graphics.newQuad(size,     size*15/2,  size/2, size/2, w, h),
        arrow_left      = love.graphics.newQuad(size*1.5, size*15/2,  size/2, size/2, w, h),
    }

    animations = {
        player_idle = {
            size = 8*4,
            count = 4,
            x = 0,
            y = 0,
            quads = {},
        },
        player_cast = {
            size = 8*4,
            count = 4,
            x = 0,
            y = size,
            quads = {},
        },
        player_walk = {
            size = 8*4,
            count = 5,
            x = 0,
            y = 2*size,
            quads = {},
        },
        enemy_live = {
            size = 8*4,
            count = 4,
            x = 0,
            y = 3*size,
            quads = {},
        },
        enemy_dead = {
            size = 8*4,
            count = 4,
            x = 0,
            y = 4*size,
            quads = {},
        }
    }

    -- fill in the animation quad lists
    for _, animation in pairs(animations) do
        for index = 0, animation.count do
            local quad = love.graphics.newQuad(animation.x + animation.size*index, animation.y, size, size, w, h)
            table.insert(animation.quads, quad)
        end
    end

    -- spell data
    -- TODO(bkaylor): Slow enemies
    -- TODO(bkaylor): Slow projectiles 
    -- TODO(bkaylor): Fast player
    -- TODO(bkaylor): Reflect projectiles
    spells = {
        projectile = {
            recipe = {"left", "left"},
            procedure = function()
                local projectile = {
                    x = player.x + player.w/4,
                    y = player.y + player.h/4,
                    w = 8*2,
                    h = 8*2,
                    direction = get_normalized_vector_between(player.mark, player),
                    speed = 300,
                }

                table.insert(projectiles, projectile)
            end,
        },
        double_speed_projectiles = {
            recipe = {"up", "right", "down", "left"},
            procedure = function()
                for _, projectile in ipairs(projectiles) do
                    projectile.speed = projectile.speed * 2
                end
            end,
        },
        swap = {
            recipe = {"up", "down"},
            procedure = function()
                player.x, player.y, player.mark.x, player.mark.y =
                player.mark.x, player.mark.y, player.x, player.y
            end,
        },
        reflect_mark = {
            recipe = {"left", "right"},
            procedure = function()
                local vec = get_vector_between(player, player.mark)
                player.mark.x, player.mark.y = player.mark.x + 2*vec.x, player.mark.y + 2*vec.y
            end,
        },
        reflect_player = {
            recipe = {"right", "left"},
            procedure = function()
                local vec = get_vector_between(player.mark, player)
                player.x, player.y = player.x + 2*vec.x, player.y + 2*vec.y
            end,
        },
        return_mark = {
            recipe = {"left", "right", "down"},
            procedure = function()
                player.mark.held = true
            end,
        },
        send = {
            recipe = {"right", "right"},
            procedure = function()
                for i, gate in ipairs(gates) do
                    if collide(player.mark, gate) then
                        close_gate(i)
                    end
                end
            end,
        },
        bfg = {
            recipe = {"up", "up", "down", "down", "left", "right", "left", "right"},
            procedure = function()
                player.score = player.score + #gates
                gates = {}
                player.score = player.score + #enemies
                enemies = {}
            end,
        },
        shield = {
            recipe = {"down", "down", "down"},
            procedure = function()
                player.shielded = true
            end,
        }
    }

    player = {
        x = state.width/2, 
        y = state.height/2, 
        w = 8*4, 
        h = 8*4,
        speed = 100,
        casting = false,
        cast_queue = {},
        shielded = false,
        mark = {
            held = true,
            x = 0,
            y = 0,
            w = 8*4,
            h = 8*4,
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
end

function close_gate(i)
    player.score = player.score + 1
    table.remove(gates, i)
end

function destroy_enemy(i)
    player.score = player.score + 1

    local enemy = enemies[i]
    enemy.state = "dying"
    enemy.state_timer = 0
    enemy.animation.state = "enemy_dead"
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

function restart()
    love.load()
end

function collide(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and 
           a.y < b.y + b.h and a.h + a.y > b.y 
end

function make_enemy()
    local enemy = {
        x = love.math.random(state.width), 
        y = love.math.random(state.height), 
        w = 8*4, 
        h = 8*4,
        speed = 100,
        animation = {
            state = "enemy_live",
            progress = 0,
        },
        state = "live",
        state_timer = 0,
    }

    table.insert(enemies, enemy)
end

function make_gate()
    local gate = {
        x = love.math.random(state.width), 
        y = love.math.random(state.height), 
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

function love.update(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end

    if love.keyboard.isDown("r") then
        restart()
    end

    if pressed("b") then
        state.show_spellbook = not state.show_spellbook
    end

    if not player.casting then
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

        -- drop mark button
        if love.keyboard.isDown("lctrl") then
            player.mark.held = false
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
    if player.mark.held then
        player.mark.x = player.x
        player.mark.y = player.y
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
            local vec = get_normalized_vector_between(player, enemy)
            enemy.x = enemy.x + vec.x * enemy.speed * dt
            enemy.y = enemy.y + vec.y * enemy.speed * dt
        end

        enemy.animation.progress = enemy.animation.progress + dt

    end

    -- check projectile-enemy collision
    for i, projectile in ipairs(projectiles) do
        for j, enemy in ipairs(enemies) do
            -- TODO(bkaylor): Improve projectile hitboxes
            if collide(projectile, enemy) then
                table.remove(projectiles, i)
                destroy_enemy(j)
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
                restart()
            end
        end
    end

    -- spawn enemy or gate every some seconds
    local freq = 5
    if (love.timer.getTime() - state.last_spawn_time) > freq then
        if love.math.random(2) == 1 then
            make_enemy()
        else
            make_gate()
        end

        state.last_spawn_time = love.timer.getTime()
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
            next_quad = quads.arrow_up
        elseif direction == "down" then
            next_quad = quads.arrow_down
        elseif direction == "right" then
            next_quad = quads.arrow_right
        else
            next_quad = quads.arrow_left
        end

        love.graphics.draw(spritesheet, next_quad, x+offset, y)

        offset = offset + 16
    end
end

function love.draw()
    love.graphics.clear()

    -- draw gates
    for _, gate in ipairs(gates) do 
        love.graphics.draw(spritesheet, quads.gate, gate.x, gate.y)
    end

    -- draw mark
    love.graphics.draw(spritesheet, quads.mark, math.floor(player.mark.x), math.floor(player.mark.y))

    if player.casting then
        -- draw line between player and mark
        love.graphics.line(player.x+player.w/2, player.y+player.h/2, 
                           player.mark.x+player.mark.w/2, player.mark.y+player.mark.h/2)
    end

    -- draw enemies
    for _, enemy in ipairs(enemies) do 
        local animation = animations[enemy.animation.state]
        local index = (math.floor(enemy.animation.progress*12) % animation.count) + 1
        local quad = animation.quads[index]
        love.graphics.draw(spritesheet, quad, enemy.x, enemy.y)
    end

    -- draw player
    local animation = animations[player.animation.state]
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

    -- draw player's shield
    if player.shielded then
        love.graphics.draw(spritesheet, quads.shield, player.x, player.y)
    end

    -- draw player's cast queue
    draw_arrows_at(player.cast_queue, player.x, player.y-20)

    -- draw projectiles
    for _, projectile in ipairs(projectiles) do
        love.graphics.draw(spritesheet, quads.projectile, projectile.x, projectile.y)
    end

    -- draw score
    love.graphics.print(player.score, state.score_font, state.width/2, 10)

    if state.show_spellbook then
        -- draw spellbook
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
end

