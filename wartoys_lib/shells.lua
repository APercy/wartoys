
function wartoys_lib.spawn_shell(self, player_name, ent_name, strength)
    if not self._shell_is_loaded then return end
	local pos = self.object:get_pos()
    if not pos then return end
	pos.y = pos.y + (self._cannon_base_y or 0)
    local rotation = wartoys_lib.normalize_rotations(self.object:get_rotation())
    rotation.x = rotation.x + self._turret_pitch
    rotation.y = rotation.y - self._turret_yaw
    local dir = wartoys_lib.rot_to_dir(rotation)
    local yaw = rotation.y
    local curr_velocity = self.object:get_velocity() --we could be flying
	local bullet_obj = nil
	bullet_obj = core.add_entity(pos, ent_name)

	if not bullet_obj then
		return
	end
    core.sound_play("wartoys_explode", {
        object = self.object,
        max_hear_distance = 50,
        gain = 5.0,
        fade = 0.0,
        pitch = 1.0,
    }, true)

	local lua_ent = bullet_obj:get_luaentity()
	lua_ent.shooter_name = player_name
    lua_ent.damage = lua_ent.damage * (math.random(5, 15)/10)
	--bullet_obj:set_yaw(yaw)
    bullet_obj:set_rotation({x=rotation.x,y=yaw, z = 0})
	local velocity = vector.multiply(dir, strength)
    velocity = vector.add(velocity, curr_velocity) --sum with the current velocity
	bullet_obj:set_velocity(velocity)
    self._shell_is_loaded = false
end

function wartoys_lib.remove_nodes(pos, radius, disable_drop_nodes)
    if not pos then return end
    if not disable_drop_nodes then disable_drop_nodes = false end
    local pr = PseudoRandom(os.time())
    for z = -radius, radius do
        for y = -radius, radius do
            for x = -radius, radius do
                -- remove the nodes
                local r = vector.length(vector.new(x, y, z))
                if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
                    local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
                    
	                local node = core.get_node(p).name
	                local nodedef = core.registered_nodes[node]
	                local is_liquid = nodedef.liquidtype ~= "none"
                    local is_leaf = (nodedef.drawtype == "plantlike") or (nodedef.drawtype == "allfaces_optional")

                    if is_leaf then
                        local node_name = "air"
                        node_name = "fire:basic_flame"

                        core.set_node(p, {name = node_name})
                    elseif not is_liquid then
                        core.remove_node(p)
                    end
                end
            end
        end
    end
    if disable_drop_nodes == false then
        local radius = radius
        for z = -radius, radius do
            for y = -radius, radius do
                for x = -radius, radius do
                    -- do fancy stuff
                    local r = vector.length(vector.new(x, y, z))
                    if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
                        local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
                        core.spawn_falling_node(p)
                    end
                end
            end
        end
    end
end

function wartoys_lib.add_destruction_effects(pos, radius, w_fire)
    if pos == nil then return end
    w_fire = w_fire
    if w_fire == nil then w_fire = true end
	local node = wartoys_lib.nodeatpos(pos)
    local is_liquid = false
    if (node.drawtype == 'liquid' or node.drawtype == 'flowingliquid') then is_liquid = true end

    core.sound_play("wartoys_explode", {
        pos = pos,
        max_hear_distance = 100,
        gain = 2.0,
        fade = 0.0,
        pitch = 1.0,
    }, true)
    if is_liquid == false and w_fire == true then
	    core.add_particle({
		    pos = pos,
		    velocity = vector.new(),
		    acceleration = vector.new(),
		    expirationtime = 0.4,
		    size = radius * 10,
		    collisiondetection = false,
		    vertical = false,
		    texture = "wartoys_boom.png",
		    glow = 15,
	    })
	    core.add_particlespawner({
		    amount = 32,
		    time = 0.5,
		    minpos = vector.subtract(pos, radius / 2),
		    maxpos = vector.add(pos, radius / 2),
		    minvel = {x = -10, y = -10, z = -10},
		    maxvel = {x = 10, y = 10, z = 10},
		    minacc = vector.new(),
		    maxacc = vector.new(),
		    minexptime = 1,
		    maxexptime = 2.5,
		    minsize = radius * 3,
		    maxsize = radius * 5,
		    texture = "wartoys_boom.png",
	    })
    end
	core.add_particlespawner({
		amount = 64,
		time = 1.0,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x = -10, y = -10, z = -10},
		maxvel = {x = 10, y = 10, z = 10},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 2.5,
		minsize = radius * 3,
		maxsize = radius * 5,
		texture = "wartoys_smoke2.png",
	})
end

function wartoys_lib.add_blast_damage(pos, radius, damage_cal)
    if not pos then return end
    radius = radius or 10
    damage_cal = damage_cal or 4

    local objs = core.get_objects_inside_radius(pos, radius)
	for _, obj in pairs(objs) do
		local obj_pos = obj:get_pos()
		local dist = math.max(1, vector.distance(pos, obj_pos))
        local damage = (damage_cal / dist) * radius

        if obj:is_player() then
            obj:set_hp(obj:get_hp() - damage)
        else
            local luaobj = obj:get_luaentity()

            -- object might have disappeared somehow
            if luaobj then
				local do_damage = true
				local do_knockback = true
				local entity_drops = {}
				local objdef = core.registered_entities[luaobj.name]

				if objdef and objdef.on_blast then
					do_damage, do_knockback, entity_drops = objdef.on_blast(luaobj, damage)
				end

				if do_knockback then
					local obj_vel = obj:get_velocity()
				end
				if do_damage then
                    obj:punch(obj, 1.0, {
                        full_punch_interval = 1.0,
                        damage_groups = {fleshy = damage},
                    }, nil)
				end
				--[[for _, item in pairs(entity_drops) do
					add_drop(drops, item) -- !!! accessing undefined variable add_drop, drops
				end]]--
			end

        end
    end
    --lets light some bombs
    local pr = PseudoRandom(os.time())
    for z = -radius, radius do
        for y = -radius, radius do
            for x = -radius, radius do
                -- remove the nodes
                local r = vector.length(vector.new(x, y, z))
                if (radius * radius) / (r * r) >= (pr:next(80, 125) / 100) then
                    local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
                    local node = core.get_node(p).name
                    if node == "tnt:tnt" then core.set_node(p, {name = "tnt:tnt_burning"}) end
                end
            end
        end
    end

end

function wartoys_lib.explode(object, radius, ipos)
    if not object then return end
    local rnd_radius = math.random(radius-1, radius+1)
    local pos = ipos or object:get_pos()
    wartoys_lib.add_destruction_effects(pos, rnd_radius + math.random(2,4), true)

    -- remove nodes
    local ent = object:get_luaentity()
    if wartoys_lib.bypass_protection == false then
        local name = ""
        if ent.shooter_name then
            name = ent.shooter_name
        end

        if core.is_protected(pos, name) == false then
            wartoys_lib.remove_nodes(pos, rnd_radius)
        end
    else
        wartoys_lib.remove_nodes(pos, rnd_radius)
    end

    --damage entites/players
    wartoys_lib.add_blast_damage(pos, rnd_radius+math.random(4,6), 50)

    object:remove()
end

local function add_flash(obj_pos)
    core.add_particle({
        pos = obj_pos,
        velocity = {x=0, y=0, z=0},
      	acceleration = {x=0, y=0, z=0},
        expirationtime = 1,
        size = math.random(10,20)/10,
        collisiondetection = false,
        vertical = false,
        texture = "wartoys_boom.png",
        glow = 10,
    })

end

function wartoys_lib.register_shell(ent_name, inv_image, bullet_texture, description, bullet_damage, boom_radius, bullets_max_stack)
    bullets_max_stack = bullets_max_stack or 99
	core.register_entity(ent_name, {
		hp_max = 5,
		physical = false,
		collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
		visual = "sprite",
		textures = {bullet_texture},
        lastpos = {},
		visual_size = {x = 0.15, y = 0.15},
        collide_with_objects = false,
		old_pos = nil,
		velocity = nil,
		is_liquid = nil,
		shooter_name = "",
        damage = bullet_damage,
		groups = {bullet = 1},
        _total_time = 0,
        bomb_radius = boom_radius,

		on_activate = function(self)
			self.object:set_acceleration({x = 0, y = -9.81, z = 0})
		end,

		on_step = function(self, dtime, moveresult)
            self._total_time = self._total_time + dtime
            if self._total_time > 5 then
                --destroy after 5 seconds
                self.object:remove()
            end

			local pos = self.object:get_pos()
            if not pos then return end
			self.old_pos = self.old_pos or pos
			local velocity = self.object:get_velocity()
			local hit_bullet_sound = "wartoys_collision"

			local cast = core.raycast(self.old_pos, pos, true, true)
			local thing = cast:next()
			while thing do
				if thing.type == "object" and thing.ref ~= self.object then
                    local is_the_shooter_vehicle = false
                    local ent = thing.ref:get_luaentity()
                    if ent then
                        if ent.driver_name then
                            if ent.driver_name == self.shooter_name then is_the_shooter_vehicle = true end
                        end
                    end
					if (not thing.ref:is_player() or thing.ref:get_player_name() ~= self.shooter_name) and is_the_shooter_vehicle == false then
                        --core.chat_send_all("acertou "..thing.ref:get_entity_name())
						thing.ref:punch(self.object, 1.0, {
							full_punch_interval = 0.5,
		                    groupcaps={
			                    choppy={times={[1]=2.10, [2]=0.90, [3]=0.50}, uses=30, maxlevel=3},
		                    },
							damage_groups = {fleshy=self.damage}
						})
						local thing_pos = thing.ref:get_pos()
						if thing_pos then
                            core.sound_play(hit_bullet_sound, {
                                object = self.object,
                                max_hear_distance = 50,
                                gain = 1.0,
                                fade = 0.0,
                                pitch = 1.0,
                            }, true)
                            wartoys_lib.explode(self.object, self.bomb_radius)
						end
						self.object:remove()

                        --do damage on my old planes
                        --[[if ent then
                            if ent.hp_max then ent.hp_max = ent.hp_max - self.damage end
                        end]]--

						if core.is_protected(pos, self.shooter_name) then
							return
						end

						return
					end
				elseif thing.type == "node" then
					local node_name = core.get_node(thing.under).name
                    if not node_name or node_name == nil or node_name == "" or node_name == "ignore" then return end
					local drawtype = core.registered_nodes[node_name]["drawtype"]
					if drawtype == 'liquid' then
						if not self.is_liquid then
							self.velocity = velocity
							self.is_liquid = true
							local liquidviscosity = core.registered_nodes[node_name]["liquid_viscosity"]
							local drag = 1/(liquidviscosity*3)
							self.object:set_velocity(vector.multiply(velocity, drag))
							self.object:set_acceleration({x = 0, y = -1.0, z = 0})
							--TODO splash here
						end
					elseif self.is_liquid then
						self.is_liquid = false
						if self.velocity then
							self.object:set_velocity(self.velocity)
						end
						self.object:set_acceleration({x = 0, y = -9.81, z = 0})
					end
					if core.registered_items[node_name].walkable then
                        core.sound_play(hit_bullet_sound, {
                            object = self.object,
                            max_hear_distance = 50,
                            gain = 1.0,
                            fade = 0.0,
                            pitch = 1.0,
                        }, true)

                        --explode TNT
                        local node = core.get_node(pos)
                        local node_name = node.name
                        if node_name == "tnt:tnt" then core.set_node(pos, {name = "tnt:tnt_burning"}) end

                        local i_pos = thing.intersection_point
                        add_flash(i_pos)

                        --explode here
                        wartoys_lib.explode(self.object, self.bomb_radius, i_pos)

						self.object:remove()

						if core.is_protected(pos, self.shooter_name) then
							return
						end

                        local player = core.get_player_by_name(self.shooter_name)
                        if player then
                            core.node_punch(pos, node, player, {damage_groups={fleshy=20}})--{type = "punch"})
                        end

						--replace node
						--core.set_node(pos, {name = "air"})
                        --core.add_item(pos,node_name)

						return
					end
				end
				thing = cast:next()
			end
            --TODO set a trail here using the stored old position
			self.old_pos = pos
		end,
	})
	core.register_craftitem(ent_name, {
		description = description,
		inventory_image = inv_image,
		stack_max = bullets_max_stack,
	})
end
