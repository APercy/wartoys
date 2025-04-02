local S = wartoys_lib.S

function wartoys_lib.getVehicleFromPlayer(player, self)
    local seat = player:get_attach()
    if seat then
        local car = seat:get_attach()
        if car then
            return car
        else
            return seat
        end
    end
    return nil
end

function wartoys_lib.driver_formspec(name)
    local player = minetest.get_player_by_name(name)
    if player then
        local vehicle_obj = wartoys_lib.getVehicleFromPlayer(player)
        if vehicle_obj == nil then
            return
        end
        local ent = vehicle_obj:get_luaentity()

        if ent then
            local yaw = "false"
            if ent._yaw_by_mouse then yaw = "true" end

            local basic_form = table.concat({
                "formspec_version[3]",
                "size[6,7]",
	        }, "")

	        basic_form = basic_form.."button[1,1.0;4,1;go_out;" .. S("Go Offboard") .. "]"
            basic_form = basic_form.."button[1,2.5;4,1;lights;" .. S("Lights") .. "]"

            minetest.show_formspec(name, "wartoys_lib:driver_main", basic_form)
        end
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "wartoys_lib:driver_main" then
        local name = player:get_player_name()
        local car_obj = wartoys_lib.getVehicleFromPlayer(player)
        if car_obj then
            local ent = car_obj:get_luaentity()
            if ent then
		        if fields.go_out then
                    if ent._passenger then --any pax?
                        local pax_obj = minetest.get_player_by_name(ent._passenger)

                        local dettach_pax_f = wartoys_lib.dettach_pax
                        if ent._dettach_pax then dettach_pax_f = ent._dettach_pax end
                        dettach_pax_f(ent, pax_obj)                        
                    end
                    ent._is_flying = 0

                    local dettach_f = wartoys_lib.dettach_driver
                    if ent._dettach then dettach_f = ent._dettach end
                    dettach_f(ent, player) 
		        end
                if fields.lights then
                    if ent._show_lights == true then
                        ent._show_lights = false
                    else
                        ent._show_lights = true
                    end
                end
            end
        end
        minetest.close_formspec(name, "wartoys_lib:driver_main")
    end
end)
