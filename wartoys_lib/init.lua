-- Minetest 5.10.0 : wartoys

wartoys_lib = {
    storage = core.get_mod_storage()
}

wartoys_lib.S = nil

if(core.get_translator ~= nil) then
    wartoys_lib.S = core.get_translator(core.get_current_modname())

else
    wartoys_lib.S = function ( s ) return s end
end

local S = wartoys_lib.S
local storage = wartoys_lib.storage

wartoys_lib.fuel = {['biofuel:biofuel'] = 1,['biofuel:bottle_fuel'] = 1,
                ['biofuel:phial_fuel'] = 0.25, ['biofuel:fuel_can'] = 10,
                ['airutils:biofuel'] = 1,}

wartoys_lib.gravity = 9.8
wartoys_lib.ideal_step = 0.2
wartoys_lib.is_creative = core.settings:get_bool("creative_mode", false)
wartoys_lib.can_collect_car = core.settings:get_bool("collect_wartoys", false)
wartoys_lib.disable_crushing = core.settings:get_bool("disable_crushing", false)
wartoys_lib.disable_soil_crushing = core.settings:get_bool("disable_soil_crushing", true)

--cars colors
wartoys_lib.colors ={
    black='#2b2b2b',
    blue='#0063b0',
    brown='#8c5922',
    cyan='#07B6BC',
    dark_green='#567a42',
    dark_grey='#6d6d6d',
    green='#4ee34c',
    grey='#9f9f9f',
    magenta='#ff0098',
    orange='#ff8b0e',
    pink='#ff62c6',
    red='#dc1818',
    violet='#a437ff',
    white='#FFFFFF',
    yellow='#ffe400',
}

--
-- helpers and co.
--

function wartoys_lib.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

local function get_norm_angle(angle)
    local new_angle = angle/360
    new_angle = (new_angle - math.floor(new_angle))*360
    if new_angle < -180 then new_angle = new_angle + 360 end
    if new_angle > 180 then new_angle = new_angle - 360 end
    return new_angle
end

function wartoys_lib.normalize_rotations(rotations)
    return {x = get_norm_angle(rotations.x), y = get_norm_angle(rotations.y), z = get_norm_angle(rotations.z)}
end

function wartoys_lib.dot(v1,v2)
	return (v1.x*v2.x)+(v1.y*v2.y)+(v1.z*v2.z)
end

function wartoys_lib.sign(n)
	return n>=0 and 1 or -1
end

function wartoys_lib.minmax(v,m)
	return math.min(math.abs(v),m)*minekart.sign(v)
end

function wartoys_lib.properties_copy(origin_table)
    local tablecopy = {}
    for k, v in pairs(origin_table) do
      tablecopy[k] = v
    end
    return tablecopy
end

local function smoke_particle(self, pos)
	core.add_particle({
		pos = pos,
		velocity = {x = 0, y = 0, z = 0},
		acceleration = {x = 0, y = 0, z = 0},
		expirationtime = 0.25,
		size = 2.8*(self._vehicle_scale or 1),
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = "wartoys_smoke.png",
	})
end

function wartoys_lib.add_smoke(self, pos, yaw, rear_wheel_xpos)
    local direction = yaw
    
    --right
    local move = rear_wheel_xpos/10
    local smk_pos = vector.new(pos)
    smk_pos.x = smk_pos.x + move * math.cos(direction)
    smk_pos.z = smk_pos.z + move * math.sin(direction)
    
    smoke_particle(self, smk_pos)

    --left
    direction = direction - math.rad(180)
    smk_pos = vector.new(pos)
    smk_pos.x = smk_pos.x + move * math.cos(direction)
    smk_pos.z = smk_pos.z + move * math.sin(direction)
    
    smoke_particle(self, smk_pos)
end

--returns 0 for old, 1 for new
function wartoys_lib.detect_player_api(player)
    local player_proterties = player:get_properties()
    local models = player_api.registered_models
    local character = models[player_proterties.mesh]
    if character then
        if character.animations.sit.eye_height then
            if character.animations.sit.eye_height == 0.8 then
                --core.chat_send_all("new model");
                return 1
            end
        else
            --core.chat_send_all("old model");
            return 0
        end
    end

    return 0
end

function wartoys_lib.seats_create(self)
    if self.object then
        local pos = self.object:get_pos()
        self._passengers_base = {}
        self._passengers = {}
        if self._seat_pos then 
            local max_seats = table.getn(self._seat_pos)
            for i=1, max_seats do
                self._passengers_base[i] = core.add_entity(pos,'wartoys_lib:pivot_mesh')
                local seat_pos = self._seat_pos[i]
                local bone = ''
                if seat_pos == 'turret' then
                    bone = 'seat'
                    seat_pos = {x=0,y=0,z=0}
                end
                if not self._seats_rot then
                    self._passengers_base[i]:set_attach(self.object,bone,seat_pos,{x=0,y=0,z=0})
                else
                    self._passengers_base[i]:set_attach(self.object,bone,seat_pos,{x=0,y=self._seats_rot[i],z=0})
                end
            end

            self.driver_seat = self._passengers_base[1] --sets pilot seat reference
            self.passenger_seat = self._passengers_base[2] --sets copilot seat reference
        end
    end
end

-- attach player
function wartoys_lib.attach_driver(self, player)
    local name = player:get_player_name()
    self.driver_name = name

    self.object:set_bone_override("hatch", {rotation = { vec = {x=math.rad(175),y=0,z=0}, interpolation = 3, absolute = false }})

    -- attach the driver
    player:set_attach(self.driver_seat, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    local eye_y = -4
    if wartoys_lib.detect_player_api(player) == 1 then
        eye_y = 2.5
    end
    eye_y = eye_y*self._vehicle_scale

    player:set_eye_offset({x = 0, y = eye_y, z = 0}, {x = 0, y = eye_y, z = -30})
    player_api.player_attached[name] = true

    -- Make the driver sit
    -- Minetest bug: Animation is not always applied on the client.
    -- So we try sending it twice.
    -- We call set_animation with a speed on the second call
    -- so set_animation will not do nothing.
    player_api.set_animation(player, "sit")

    core.after(0.2, function()
        player = core.get_player_by_name(name)
        if player then
            local speed = 30.01
            local mesh = player:get_properties().mesh
            if mesh then
                local character = player_api.registered_models[mesh]
                if character and character.animation_speed then
                    speed = character.animation_speed + 0.01
                end
            end
            player_api.set_animation(player, "sit", speed)
            if emote then emote.start(player:get_player_name(), "sit") end
        end
    end)
end

function wartoys_lib.dettach_driver(self, player)
    local name = self.driver_name

    --self._engine_running = false

    -- driver clicked the object => driver gets off the vehicle
    self.driver_name = nil

    if self._engine_running then
	    self._engine_running = false
    end
    -- sound and animation
    if self.sound_handle then
        core.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    -- detach the player
    if player.set_detach then
        --wartoys_lib.remove_hud(player)

        --player:set_properties({physical=true})
        player:set_detach()
        player_api.player_attached[name] = nil
        player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
        player_api.set_animation(player, "stand")
    end
    self.driver = nil
    self.object:set_bone_override("hatch", {rotation = { vec = {x=math.rad(0),y=0,z=0}, interpolation = 5, absolute = false }})
end

-- attach passenger
function wartoys_lib.attach_pax(self, player, onside)
    if player then return end --TODO provisory blocked

    local onside = onside or false
    local name = player:get_player_name()

    local eye_y = -4
    if wartoys_lib.detect_player_api(player) == 1 then
        eye_y = 2.5
    end
    eye_y = eye_y*self._vehicle_scale

    if self._passenger == nil then
        self._passenger = name

        -- attach the driver
        player:set_attach(self.passenger_seat, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player:set_eye_offset({x = 0, y = eye_y, z = 0}, {x = 0, y = eye_y, z = -30})
        player_api.player_attached[name] = true
        -- make the pax sit

        core.after(0.2, function()
            player = core.get_player_by_name(name)
            if player then
                local speed = 30.01
                local mesh = player:get_properties().mesh
                if mesh then
                    local character = player_api.registered_models[mesh]
                    if character and character.animation_speed then
                        speed = character.animation_speed + 0.01
                    end
                end
                player_api.set_animation(player, "sit", speed)
                if emote then emote.start(player:get_player_name(), "sit") end
            end
        end)
    else
        --randomize the seat
        local max_seats = table.getn(self._seat_pos) --driver and front passenger

        t = {}    -- new array
        for i=1, max_seats do --(the first are for the driver
            t[i] = i
        end

        for i = 1, #t*2 do
            local a = math.random(#t)
            local b = math.random(#t)
            t[a],t[b] = t[b],t[a]
        end

        for k,v in ipairs(t) do
            i = t[k]
            if self._passengers[i] == nil and i > 2 then
                --core.chat_send_all(self.driver_name)
                self._passengers[i] = name
                player:set_attach(self._passengers_base[i], "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
                player:set_eye_offset({x = 0, y = eye_y, z = 0}, {x = 0, y = 3, z = -30})
                player_api.player_attached[name] = true
                -- make the pax sit

                core.after(0.2, function()
                    player = core.get_player_by_name(name)
                    if player then
                        local speed = 30.01
                        local mesh = player:get_properties().mesh
                        if mesh then
                            local character = player_api.registered_models[mesh]
                            if character and character.animation_speed then
                                speed = character.animation_speed + 0.01
                            end
                        end
                        player_api.set_animation(player, "sit", speed)
                        if emote then emote.start(player:get_player_name(), "sit") end
                    end
                end)

                break
            end
        end

    end
end

function wartoys_lib.dettach_pax(self, player)
    if not player then return end
    local name = player:get_player_name() --self._passenger

    -- passenger clicked the object => driver gets off the vehicle
    if self._passenger == name then
        self._passenger = nil
        self._passengers[2] = nil
    else
        local max_seats = table.getn(self._seat_pos)
        for i = max_seats,1,-1
        do 
            if self._passengers[i] == name then
                self._passengers[i] = nil
                break
            end
        end
    end

    -- detach the player
    if player then
        local pos = player:get_pos()
        player:set_detach()

        player_api.player_attached[name] = nil
        player_api.set_animation(player, "stand")

        player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
        --remove_physics_override(player, {speed=1,gravity=1,jump=1})
    end
end

function wartoys_lib.get_gauge_angle(value, initial_angle)
    initial_angle = initial_angle or 90
    local angle = value * 18
    angle = angle - initial_angle
    angle = angle * -1
	return angle
end

function wartoys_lib.setText(self, vehicle_name)
    local properties = self.object:get_properties()
    local formatted = ""
    if self.hp_max then
        formatted = S(" Current hp: ") .. string.format(
           "%.2f", self.hp_max
        )
    end
    if properties then
        properties.infotext = S("Nice @1 of @2.@3", vehicle_name, self.owner, formatted)
        self.object:set_properties(properties)
    end
end

function wartoys_lib.get_xz_from_hipotenuse(orig_x, orig_z, yaw, distance)
    --cara, o minetest é bizarro, ele considera o eixo no sentido ANTI-HORÁRIO... Então pra equação funcionar, subtrair o angulo de 360 antes
    yaw = math.rad(360) - yaw
    local z = (math.cos(yaw)*distance) + orig_z
    local x = (math.sin(yaw)*distance) + orig_x
    return x, z
end

function wartoys_lib.remove_light(self)
    if self._light_old_pos then
        --force the remotion of the last light
        core.add_node(self._light_old_pos, {name="air"})
        self._light_old_pos = nil
    end
end

function wartoys_lib.swap_node(self, pos)
    local target_pos = pos
    local have_air = false
    local node = nil
    local count = 0
    while have_air == false and count <= 3 do
        node = core.get_node(target_pos)
        if node.name == "air" then
            have_air = true
            break
        end
        count = count + 1
        target_pos.y = target_pos.y + 1
    end

    if have_air then
        core.set_node(target_pos, {name='wartoys_lib:light'})
        wartoys_lib.remove_light(self)
        self._light_old_pos = target_pos
        --remove after one second
        --[[core.after(1,function(target_pos)
            local node = core.get_node_or_nil(target_pos)
            if node and node.name == "wartoys_lib:light" then
                core.swap_node(target_pos, {name="air"})
            end
        end, target_pos)]]--

        return true
    end
    return false
end

function wartoys_lib.put_light(self)
    local pos = self.object:get_pos()
    pos.y = pos.y + 1
    local yaw = self.object:get_yaw()
    local lx, lz = wartoys_lib.get_xz_from_hipotenuse(pos.x, pos.z, yaw, 10)
    local light_pos = {x=lx, y=pos.y, z=lz}

	local cast = core.raycast(pos, light_pos, false, false)
	local thing = cast:next()
    local was_set = false
	while thing do
		if thing.type == "node" then
            local ipos = thing.intersection_point
            if ipos then
                was_set = wartoys_lib.swap_node(self, ipos)
            end
        end
        thing = cast:next()
    end
    if was_set == false then
        local n = core.get_node_or_nil(light_pos)
        if n and n.name == 'air' then
            wartoys_lib.swap_node(self, light_pos)
        end
    end


    --[[local n = core.get_node_or_nil(light_pos)
    --core.chat_send_player(name, n.name)
    if n and n.name == 'air' then
        core.set_node(pos, {name='wartoys_lib:light'})
        --local timer = core.get_node_timer(pos)
        --timer:set(10, 0)
        core.after(0.3,function(pos)
            local node = core.get_node_or_nil(pos)
            if node and node.name == "wartoys_lib:light" then
                core.swap_node(pos, {name="air"})
            end
        end, pos)
    end]]--

end

function wartoys_lib.seats_destroy(self)
    local max_seats = table.getn(self._passengers_base)
    for i=1, max_seats do
        if self._passengers_base[i] then self._passengers_base[i]:remove() end
    end
end

function wartoys_lib.destroy(self, puncher)
    wartoys_lib.remove_light(self)
    if self.sound_handle then
        core.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self.driver_name then
        -- detach the driver first (puncher must be driver)
        if puncher then
            puncher:set_detach()
            puncher:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            if core.global_exists("player_api") then
                player_api.player_attached[self.driver_name] = nil
                -- player should stand again
                player_api.set_animation(puncher, "stand")
            end
        end
        self.driver_name = nil
    end

    local pos = self.object:get_pos()

    if self.front_suspension then self.front_suspension:remove() end
    if self.lf_track then self.lf_track:remove() end
    if self.rf_track then self.rf_track:remove() end
    if self.steering then self.steering:remove() end
    if self.steering_axis then self.steering_axis:remove() end
    if self.driver_seat then self.driver_seat:remove() end
    if self.passenger_seat then self.passenger_seat:remove() end
    if self.fuel_gauge then self.fuel_gauge:remove() end
    if self.lights then self.lights:remove() end

    wartoys_lib.seats_destroy(self)
    wartoys_lib.destroy_inventory(self)

    pos.y=pos.y+2

    if wartoys_lib.can_collect_car == false then
        --core.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'wartoys_lib:engine')
    else
        local lua_ent = self.object:get_luaentity()
        local staticdata = lua_ent:get_staticdata(self)
        local obj_name = lua_ent.name
        local player = puncher

        local stack = ItemStack(obj_name)
        local stack_meta = stack:get_meta()
        stack_meta:set_string("staticdata", staticdata)

        if player then
            local inv = player:get_inventory()
            if inv then
                if inv:room_for_item("main", stack) then
                    inv:add_item("main", stack)
                else
                    core.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5}, stack)
                end
            end
        else
            core.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5}, stack)
        end
    end

    self.object:remove()
end

function wartoys_lib.engine_set_sound_and_animation(self, _longit_speed)
    --core.chat_send_all('test1 ' .. dump(self._engine_running) )
    local abs_curr_long_speed = math.abs(self._longit_speed)
    local abs_long_speed = math.abs(_longit_speed)
    local scale = self._vehicle_power_scale
    local range_spacing = 0.01
    if self.sound_handle then
        if (abs_curr_long_speed*scale > (abs_long_speed + range_spacing)*scale)
            or ((abs_curr_long_speed + range_spacing)*scale < abs_long_speed*scale) then
            --core.chat_send_all('test2')
            wartoys_lib.engineSoundPlay(self)
        end
    end
end

function wartoys_lib.engineSoundPlay(self)
    --sound
    if self.sound_handle then core.sound_stop(self.sound_handle) end
    if self.object then
        local base_pitch = 1
        if self._base_pitch then base_pitch = self._base_pitch end

        local divisor = 6 --3 states, so 6 to make it more smooth
        local multiplier = self._transmission_state or 1
        local snd_pitch = base_pitch + ((base_pitch/divisor)*multiplier) + ((self._longit_speed/10)/2)
        if self._transmission_state == 1 then
            snd_pitch = base_pitch + (self._longit_speed/10)
        end

        self.sound_handle = core.sound_play({name = self._engine_sound},
            {object = self.object, gain = 4,
                pitch = snd_pitch,
                max_hear_distance = 15,
                loop = true,})
    end
end

core.register_node("wartoys_lib:light", {
	drawtype = "airlike",
	--tile_images = {"wartoys_light.png"},
	inventory_image = core.inventorycube("wartoys_light.png"),
	paramtype = "light",
	walkable = false,
	is_ground_content = true,
	light_propagates = true,
	sunlight_propagates = true,
	light_source = 14,
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
})

function wartoys_lib.set_paint(self, puncher, itmstck)
    local is_admin = false
    is_admin = core.check_player_privs(puncher, {server=true})
    if not (self.owner == puncher:get_player_name() or is_admin == true) then
        return
    end

    local item_name = ""
    if itmstck then item_name = itmstck:get_name() end

    if item_name == "bike:painter" then
        --painting with bike painter
        local meta = itmstck:get_meta()
	    local colstr = meta:get_string("paint_color")
        wartoys_lib.paint(self, colstr)
        return true
    else
        --painting with dyes
        local split = string.split(item_name, ":")
        local color, indx, _
        if split[1] then _,indx = split[1]:find('dye') end
        if indx then
            --[[for clr,_ in pairs(wartoys_lib.colors) do
                local _,x = split[2]:find(clr)
                if x then color = clr end
            end]]--
            --lets paint!!!!
	        local color = (item_name:sub(indx+1)):gsub(":", "")
	        local colstr = wartoys_lib.colors[color]
            --core.chat_send_all(color ..' '.. dump(colstr))
	        if colstr then
                wartoys_lib.paint(self, colstr)
		        itmstck:set_count(itmstck:get_count()-1)
		        puncher:set_wielded_item(itmstck)
                return true
	        end
            -- end painting
        end
    end
    return false
end

--painting
function wartoys_lib.paint(self, colstr, painting_textures)
    painting_textures = painting_textures or {}
    target_textures = {"wartoys_painting.png", "wartoys_painting2.png" }
    names = {'John', 'Joe'}
    for i = 1, #painting_textures do
        table.insert(target_textures, painting_textures[i])
    end
    
    --core.chat_send_all(dump(second_painting_texture))
    if colstr then
        self._color = colstr
        local l_textures = self.initial_properties.textures
        for _, texture in ipairs(l_textures) do
            for i, target in ipairs(target_textures) do
                local indx = texture:find(target)
                if indx then
                    l_textures[_] = target.."^[multiply:".. colstr
                    --core.chat_send_all(dump(l_textures[_]))
                end
            end
        end
	    self.object:set_properties({textures=l_textures})
    end
end

function wartoys_lib.paint_with_mask(self, colstr, mask_colstr, target_texture, mask_texture)
    --"("..steampunk_blimp.canvas_texture.."^[mask:steampunk_blimp_rotor_mask2.png)^(default_wood.png^[mask:steampunk_blimp_rotor_mask.png)"

    target_texture = target_texture or "wartoys_painting.png"
    if colstr then
        self._color = colstr
        self._det_color = mask_colstr
        local l_textures = self.initial_properties.textures
        for _, texture in ipairs(l_textures) do
            local indx = texture:find(target_texture)
            if indx then
                --"("..target_texture.."^[mask:"..mask_texture..")"
                l_textures[_] = "("..target_texture.."^[multiply:".. colstr..")^("..target_texture.."^[multiply:".. mask_colstr.."^[mask:"..mask_texture..")"
            end
        end
	    self.object:set_properties({textures=l_textures})
    end
end

-- very basic transmission emulation for the car
function wartoys_lib.get_transmission_state(self, curr_speed, max_speed)
    local retVal = 1
    max_speed = max_speed or 100
    max_speed = max_speed*self._vehicle_scale
    curr_speed = curr_speed*self._vehicle_scale
    if curr_speed >= (max_speed/4) then retVal = 2 end
    if curr_speed >= (max_speed/2) then retVal = 3 end
    return retVal
end

dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "destruction.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "physics_lib.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "custom_physics.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "control.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "fuel_management.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "ground_detection.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "inventory_management.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "formspecs.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "entities.lua")
dofile(core.get_modpath("wartoys_lib") .. DIR_DELIM .. "shells.lua")

local direct_impact_damage = 30
local speed = 100
local radius = 3
wartoys_lib.register_shell("wartoys_lib:shell1", "wartoys_shell_ico.png", "wartoys_box_texture.png", "Tank Shell", direct_impact_damage, radius, speed)

-- engine



local old_entities = {
    "wartoys_none:noneyet",
}
for _,entity_name in ipairs(old_entities) do
    core.register_entity(":"..entity_name, {
        on_activate = function(self, staticdata)
            self.object:remove()
        end,
    })
end
