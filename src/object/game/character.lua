local Character, super = Class(Object)

function Character:init(name, x, y, variant)
    super:init(self, x, y, 0, 0)

    self.name = name
    self.variant = variant or "dark"
    self.facing = "down"

    self.sprite = Sprite("party/"..self.name.."/world/"..self.variant.."/down")
    self.sprite:setOrigin(0.5, 1)
    self.sprite:setScale(2)
    self:addChild(self.sprite)

    self.sprite_subdir = "world"
    self.sprite_name = self.facing
    self.sprite:setFrame(1)

    self.collider = Hitbox(-19, -26, 38, 28, self)

    self.interact_collider = {
        ["down"] = Hitbox(-19, 2, 38, 16, self),
        ["up"] = Hitbox(-19, -42, 38, 16, self),
        ["left"] = Hitbox(-31, -26, 12, 28, self),
        ["right"] = Hitbox(19, -26, 12, 28, self)
    }

    -- 1px movement increments
    self.partial_x = (x % 1)
    self.partial_y = (y % 1)

    self.last_collided_x = false
    self.last_collided_y = false

    self.x = math.floor(self.x)
    self.y = math.floor(self.y)
end

function Character:onAdd(parent)
    if parent:includes(World) then
        self.world = parent
    end
end

function Character:interact()
    local col = self.interact_collider[self.facing]

    for _,obj in ipairs(self.world.children) do
        if obj.onInteract and obj:collidesWith(col) and obj:onInteract(self, self.facing) then
            return true
        end
    end

    return false
end

function Character:moveX(amount, speed, move_y)
    if amount * (speed or 1) == 0 then
        return false
    end

    self.partial_x = self.partial_x + (amount * speed)

    local move = math.floor(self.partial_x)
    self.partial_x = self.partial_x % 1

    if move ~= 0 then
        return self:moveXExact(move, move_y)
    else
        return not self.last_collided_x
    end
end

function Character:moveY(amount, speed, move_x)
    if amount * (speed or 1) == 0 then
        return false
    end

    self.partial_y = self.partial_y + (amount * speed)

    local move = math.floor(self.partial_y)
    self.partial_y = self.partial_y % 1

    if move ~= 0 then
        return self:moveYExact(move, move_x)
    else
        return not self.last_collided_y
    end
end

function Character:moveXExact(amount, move_y)
    local sign = Utils.sign(amount)
    for i = sign, amount, sign do
        local last_x = self.x
        local last_y = self.y

        self.x = self.x + sign

        local collided, target = self.world:checkCollision(self.collider)
        if collided and not (move_y > 0) then
            for i = 1, 3 do
                self.y = self.y - i
                collided, target = self.world:checkCollision(self.collider)
                if not collided then break end
            end
        end
        if collided and not (move_y < 0) then
            self.y = last_y
            for i = 1, 3 do
                self.y = self.y + i
                collided, target = self.world:checkCollision(self.collider)
                if not collided then break end
            end
        end

        if collided then
            self.x = last_x
            self.y = last_y
            
            if target and target.onCollide then
                target:onCollide(self)
            end

            self.last_collided_x = true
            return false, target
        end
    end
    self.last_collided_x = false
    return true
end

function Character:moveYExact(amount, move_x)
    local sign = Utils.sign(amount)
    for i = sign, amount, sign do
        local last_x = self.x
        local last_y = self.y

        self.y = self.y + sign

        local collided, target = self.world:checkCollision(self.collider)
        if collided and not (move_x > 0) then
            for i = 1, 2 do
                self.x = self.x - i
                collided, target = self.world:checkCollision(self.collider)
                if not collided then break end
            end
        end
        if collided and not (move_x < 0) then
            self.x = last_x
            for i = 1, 2 do
                self.x = self.x + i
                collided, target = self.world:checkCollision(self.collider)
                if not collided then break end
            end
        end

        if collided then
            self.x = last_x
            self.y = last_y
            
            if target and target.onCollide then
                target:onCollide(self)
            end

            self.last_collided_y = true
            return i ~= sign, target
        end
    end
    self.last_collided_y = false
    return true
end

function Character:walk(x, y, run, force_dir)
    if x ~= 0 or y ~= 0 then
        local last_dir = self.facing
        local dir = force_dir or "down"
        if not force_dir then
            if x > 0 then
                dir = (y ~= 0 and (self.facing == "down" or self.facing == "up")) and self.facing or "right"
            elseif x < 0 then
                dir = (y ~= 0 and (self.facing == "down" or self.facing == "up")) and self.facing or "left"
            elseif y > 0 then
                dir = (x ~= 0 and (self.facing == "left" or self.facing == "right")) and self.facing or "down"
            elseif y < 0 then
                dir = (x ~= 0 and (self.facing == "left" or self.facing == "right")) and self.facing or "up"
            end
        end
        self.facing = dir

        local target_frame = 1
        if last_dir == "down" or last_dir == "up" or last_dir == "right" or last_dir == "left" then
            target_frame = self.sprite.frame
        end
        self:setSprite("world", self.facing, target_frame)
        self.sprite:play(run and 0.125 or 0.25)

        local moved = false
        moved = self:moveX(x*(run and 8 or 4), DT * 30, y) or moved
        moved = self:moveY(y*(run and 8 or 4), DT * 30, x) or moved
        if not moved then
            self.sprite:stop()
        end
    else
        if self.sprite_name == "up" or self.sprite_name == "down" or self.sprite_name == "left" or self.sprite_name == "right" then
            self.sprite:stop()
        end
    end
end

function Character:setVariant(variant)
    if self.variant ~= variant then
        self.variant = variant
        self:setSprite(self.sprite_subdir, self.sprite_name, self.sprite.frame, true)
    end
end

function Character:setSprite(subdir, sprite, frame, force)
    if self.sprite_subdir ~= subdir or self.sprite_name ~= sprite or force then
        self.sprite_subdir = subdir
        self.sprite_name = sprite
        self.sprite:set("party/"..self.name.."/"..subdir.."/"..self.variant.."/"..sprite)
        if frame then
            self.sprite:setFrame(frame)
        end
    end
end

function Character:update(dt)
    self:updateChildren(dt)
end

function Character:draw()
    --love.graphics.setColor(0, 1, 0)
    --love.graphics.rectangle("fill", self.collider.x, self.collider.y, self.collider.width, self.collider.height)
    self:drawChildren()
end

return Character