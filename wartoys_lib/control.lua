--global constants

wartoys_lib.vector_up = vector.new(0, 1, 0)

function wartoys_lib.set_yaw_by_mouse(self, dir)
    local rotation = self.object:get_rotation()
    local rot_y = math.deg(rotation.y)
    local rot_x = math.deg(rotation.x)
    
    local total = math.abs(math.floor(rot_y/360))

    if rot_y < 0 then rot_y = rot_y + (360*total) end
    if rot_y > 360 then rot_y = rot_y - (360*total) end
    if rot_y >= 270 and dir <= 90 then dir = dir + 360 end
    if rot_y <= 90 and dir >= 270 then dir = dir - 360 end

    local intensity = 1
    local yaw = (rot_y - dir) * intensity

	return math.rad(yaw)
end

local function signum(number)
   if number > 0 then
      return 1
   elseif number < 0 then
      return -1
   else
      return 0
   end
end

function wartoys_lib.control(self, dtime, hull_direction, longit_speed, longit_drag, later_drag, accel, max_acc_factor, max_speed, steering_limit, steering_speed)
    self._last_time_command = self._last_time_command + dtime
    hull_direction = hull_direction or 0
    longit_speed = longit_speed or 0
    longit_drag = longit_drag or 0
    later_drag = later_drag or 0
    max_acc_factor = max_acc_factor or 0
    max_acc_factor = max_acc_factor

    max_speed = max_speed or 0
    max_speed = max_speed

    steering_limit = steering_limit or 0
    steering_speed = steering_speed or 0

    if self._last_time_command > 1 then self._last_time_command = 1 end

	local player = core.get_player_by_name(self.driver_name)
    local retval_accel = accel;
    local stop = false
    
	-- player control
	if player then
		local ctrl = player:get_player_control()
		
        local acc = 0
        if self._energy > 0 then
            if longit_speed < max_speed and ctrl.up then
                --get acceleration factor
                acc = max_acc_factor
                --core.chat_send_all('engineacc: '.. engineacc)
                if acc > 1 and acc < max_acc_factor and longit_speed > 0 then
                    --improper road will reduce speed
                    acc = -1
                end
            end


            --reversing
	        if ctrl.sneak and longit_speed <= 1.0 and longit_speed > -1.0 then
                acc = -2
	        end
        end

        --break
        if ctrl.down or ctrl.jump then
            --[[if math.abs(longit_speed) > 0 then
                acc = -5 / (longit_speed / 2) -- lets set a brake efficience based on speed
            end]]--
        
            --total stop
            --wheel break
            if longit_speed > 0 then
                acc = -5
                --[[if (longit_speed + acc) < 0 then
                    acc = longit_speed * -1
                end]]--
            end
            if longit_speed < 0 then
                acc = 5
                if (longit_speed + acc) > 0 then
                    acc = longit_speed * -1
                end
            end
            if math.abs(longit_speed) < 1 then
                stop = true
            end
        end

        if acc then retval_accel=vector.add(accel,vector.multiply(hull_direction,acc)) end

		if ctrl.aux1 then
		    local rot_y = math.deg(player:get_look_horizontal())
            local rot_x = -player:get_look_vertical()/2
            self._turret_pitch = rot_x
            if self._turret_pitch < math.rad(self._cannon_min_angle) then self._turret_pitch = math.rad(self._cannon_min_angle) end
            if self._turret_pitch > math.rad(self._cannon_max_angle) then self._turret_pitch = math.rad(self._cannon_max_angle) end
            self._turret_yaw = wartoys_lib.set_yaw_by_mouse(self, rot_y)
		end

		-- yaw
        local yaw_cmd = 0

	    -- steering
	    if ctrl.right then
		    self._steering_angle = math.max(self._steering_angle-steering_speed*dtime,-steering_limit)
	    elseif ctrl.left then
		    self._steering_angle = math.min(self._steering_angle+steering_speed*dtime,steering_limit)
        else
            --center steering
            if longit_speed > 0 then
                local factor = 1
                if self._steering_angle > 0 then factor = -1 end
                local correction = (steering_limit*(longit_speed/75)) * factor
                local before_correction = self._steering_angle
                self._steering_angle = self._steering_angle + correction
                if math.sign(before_correction) ~= math.sign(self._steering_angle) then self._steering_angle = 0 end
            end
	    end

        local angle_factor = self._steering_angle / 60
        if angle_factor < 0 then angle_factor = angle_factor * -1 end
        local deacc_on_curve = longit_speed * angle_factor
        deacc_on_curve = deacc_on_curve * -1
        if deacc_on_curve then retval_accel=vector.add(retval_accel,vector.multiply(hull_direction,deacc_on_curve)) end
    
	end

    return retval_accel, stop
end


