--
-- constants
--
light_tank={}
light_tank.gravity = wartoys_lib.gravity

light_tank.S = nil

if(minetest.get_translator ~= nil) then
    light_tank.S = minetest.get_translator(core.get_current_modname())

else
    light_tank.S = function ( s ) return s end

end

local S = light_tank.S

dofile(minetest.get_modpath("wartoys_lib") .. DIR_DELIM .. "custom_physics.lua")
dofile(minetest.get_modpath("wartoys_lib") .. DIR_DELIM .. "fuel_management.lua")
dofile(minetest.get_modpath("wartoys_lib") .. DIR_DELIM .. "ground_detection.lua")
dofile(minetest.get_modpath("wartoys_lib") .. DIR_DELIM .. "control.lua")
dofile(minetest.get_modpath("wartoys_light_tank") .. DIR_DELIM .. "forms.lua")
dofile(minetest.get_modpath("wartoys_light_tank") .. DIR_DELIM .. "entities.lua")
dofile(minetest.get_modpath("wartoys_light_tank") .. DIR_DELIM .. "crafts.lua")


