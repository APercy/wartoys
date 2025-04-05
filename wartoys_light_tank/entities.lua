-- destroy the beetle
function light_tank.destroy(self, puncher)
    wartoys_lib.remove_light(self)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self.driver_name then
        -- detach the driver first (puncher must be driver)
        if puncher then
            puncher:set_detach()
            puncher:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            if minetest.global_exists("player_api") then
                player_api.player_attached[self.driver_name] = nil
                -- player should stand again
                player_api.set_animation(puncher, "stand")
            end
        end
        self.driver_name = nil
    end

    local pos = self.object:get_pos()

    if self.front_suspension then self.front_suspension:remove() end
    if self.lf_wheel then self.lf_wheel:remove() end
    if self.rf_wheel then self.rf_wheel:remove() end
    if self.rear_suspension then self.rear_suspension:remove() end
    if self.lr_wheel then self.lr_wheel:remove() end
    if self.rr_wheel then self.rr_wheel:remove() end
    if self.fuel_gauge then self.fuel_gauge:remove() end
    if self.lights then self.lights:remove() end
    if self.r_lights then self.r_lights:remove() end
    if self.reverse_lights then self.reverse_lights:remove() end
    if self.turn_l_light then self.turn_l_light:remove() end
    if self.turn_r_light then self.turn_r_light:remove() end
    if self.back_seat then self.back_seat:remove() end

    wartoys_lib.seats_destroy(self)

    wartoys_lib.destroy_inventory(self)
    self.object:remove()

    pos.y=pos.y+2
end
--
-- entity
--

minetest.register_entity('wartoys_light_tank:track',{
initial_properties = {
	physical = true,
	collide_with_objects=true,
	pointable=false,
	visual = "mesh",
	mesh = "tank_track.b3d",
    --backface_culling = false,
    textures = {
            "wartoys_painting2.png", --struct
            "wartoys_painting2.png", --struct
            "wartoys_painting2.png", -- struct
            "tank_track.png", --track
            "wartoys_painting2.png",
            "tank_wheel_texture.png",
            },
	},
    _color = "#000000",
	
    on_activate = function(self,std)
	    self.sdata = minetest.deserialize(std) or {}
        self.object:set_armor_groups({immortal=1})
	    if self.sdata.remove then self.object:remove() end
    end,
	    
    get_staticdata=function(self)
      self.sdata.remove=true
      return minetest.serialize(self.sdata)
    end,
	
})

light_tank.vehicle_properties1 = {
	initial_properties = {
	    physical = true,
        collide_with_objects = true,
	    collisionbox = {-0.1, 0, -0.1, 0.1, 2.6, 0.1},
	    selectionbox = {-2.0, 0.0, -2.0, 2.0, 2.6, 2.0},
        stepheight = 1.5,
	    visual = "mesh",
	    mesh = "tank_body.b3d",
        backface_culling = false,
        textures = {
            "tank_texture.png", --body
            "tank_texture.png", --paralamas
            "tank_texture.png", -- turret
            "wartoys_black.png", --bancos
            "wartoys_metal.png", --banco traseiro
            "automobiles_red.png", --banco traseiro
            },
    },
    textures = {},
	driver_name = nil,
	sound_handle = nil,
    owner = "",
    static_save = true,
    infotext = "Light Tank!",
    hp = 50,
    buoyancy = 2,
    physics = wartoys_lib.physics,
    lastvelocity = vector.new(),
    time_total = 0,
    _painting_textures = {"tank_texture.png", "tank_wheel_texture.png"},
    _passenger = nil,
    _color = "#99a500",
    _steering_angle = 0,
    _engine_running = false,
    _last_checkpoint = "",
    _total_laps = -1,
    _race_id = "",
    _energy = 1,
    _last_time_collision_snd = 0,
    _last_time_drift_snd = 0,
    _last_time_command = 0,
    _roll = math.rad(0),
    _pitch = 0,
    _longit_speed = 0,
    _show_lights = false,
    _light_old_pos = nil,
    _last_ground_check = 0,
    _last_light_move = 0,
    _last_engine_sound_update = 0,
    _turn_light_timer = 0,
    _inv = nil,
    _inv_id = "",
    _change_color = wartoys_lib.paint,
    _car_gravity = -wartoys_lib.gravity,
    _is_flying = 0,
    _trunk_slots = 12,
    _engine_sound = "beetle_engine",
    _base_pitch = 0.7,
    _max_fuel = 10,

    _vehicle_name = "Light Tank",
    _drive_wheel_pos = {x=-4.42, y=7.00, z=21},
    _drive_wheel_angle = 12,
    _seat_pos = {'turret',}, --{x=-4.0,y=2,z=13.8},{x=4.0,y=2,z=13.8}},

    _track_frames = {x=1, y=20},
    _track_xpos = 10.5,
    _track_ent = "wartoys_light_tank:track",
    _track_length = 15,
    _run_over_damage = 60,

    _cannon_min_angle = -15,
    _cannon_max_angle = 18,
    _cannon_base_y = 1.9,

    _fuel_gauge_pos = {x=0,y=8.70,z=18},
    _transmission_state = 1,

    _LONGIT_DRAG_FACTOR = 0.12*0.12,
    _LATER_DRAG_FACTOR = 6.0,
    _max_acc_factor = 3,
    _max_speed = 10,
    _min_later_speed = 10,
    _consumption_divisor = 60000,
    

    get_staticdata = wartoys_lib.get_staticdata,

	on_deactivate = function(self)
        wartoys_lib.save_inventory(self)
	end,

    on_activate = wartoys_lib.on_activate,

	on_step = wartoys_lib.on_step,

	on_punch = wartoys_lib.on_punch,
	on_rightclick = wartoys_lib.on_rightclick,
}

minetest.register_entity("wartoys_light_tank:tank", light_tank.vehicle_properties1)



