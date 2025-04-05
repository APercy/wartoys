core.register_node("wartoys_lib:debug_target", {
	tiles = {"wartoys_target.png"},
	use_texture_alpha = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-.55,-.55,-.55, .55,.55,.55},
		},
	},
	selection_box = {
		type = "regular",
	},
	paramtype = "light",
	groups = {dig_immediate = 3, not_in_creative_inventory = 1},
	drop = "",
})

core.register_entity("wartoys_lib:target", {
	physical = false,
	collisionbox = {0, 0, 0, 0, 0, 0},
	visual = "wielditem",
	-- wielditem seems to be scaled to 1.5 times original node size
	visual_size = {x = 0.67, y = 0.67},
	textures = {"wartoys_lib:debug_target"},
	timer = 0,
	glow = 10,

	on_step = function(self, dtime)

		self.timer = self.timer + dtime

		-- remove after set number of seconds
		if self.timer > 0.5 then
			self.object:remove()
		end
	end,
})

-- function to get nodes from inside an area box
-- yaw: curr rotation
-- pos: curr position
-- sizes: width, length, height of the box
local function get_nodes_in_area(yaw, pos, sizes)
	local ret_nodes = {}

	local sin_yaw = math.sin(yaw)
	local cos_yaw = math.cos(yaw)

	for z = -math.floor(sizes.z / 2), math.floor(sizes.z / 2) do
		for y = 0, sizes.y - 1 do
			for x = -math.floor(sizes.x / 2)+1, math.floor(sizes.x / 2) do
				local rotated_x = pos.x + (x * cos_yaw - z * sin_yaw)
				local rotated_y = pos.y + y
				local rotated_z = pos.z + (x * sin_yaw + z * cos_yaw)

				local node_pos = {x = math.floor(rotated_x), y = math.floor(rotated_y), z = math.floor(rotated_z)}
				table.insert(ret_nodes, node_pos)
			end
		end
	end

	return ret_nodes
end

function wartoys_lib.affect_entities(self, pos, radius, hp_damage)
	local radius_objects = core.get_objects_inside_radius({x = pos.x, y = pos.y, z = pos.z}, radius)
    local meta = minetest.get_meta(pos)
    
    for _, object in ipairs(radius_objects) do
        if object then
            local entity = object:get_luaentity()
            if entity and entity.hp then
                if entity.hp > 0 then
                    if entity.name ~= self.object:get_entity_name() then
                        entity.hp = entity.hp - hp_damage
                    end
                end
            end
        end
    end
end

local list_of_crusheable_nodes = {
    "glasslike", "glasslike_framed", "glasslike_framed_optional",
    "allfaces_optional", "torchlike", "signlike", "plantlike", "fencelike", 
}

function wartoys_lib.interact_ahead(curr_pos, yaw, wall_sizes, longit_speed, coll_debug)
    local nodes = get_nodes_in_area(yaw, curr_pos, wall_sizes)
    --core.chat_send_all("==========================")
    for _, node_pos in ipairs(nodes) do
	    local node = minetest.get_node(node_pos)
	    local node_def = minetest.registered_nodes[node.name]
	    if node_def and not node_def.walkable or node_def.drawtype ~= "normal" then
            for key,value in pairs(list_of_crusheable_nodes) 
            do
                if node_def.drawtype == value then
                    core.add_item({x=curr_pos.x+math.random()-0.5,y=curr_pos.y,z=curr_pos.z+math.random()-0.5},node.name)
                    core.remove_node(node_pos)
                end
            end
            if coll_debug then
                core.add_entity(node_pos, "wartoys_lib:target")
            end
	    end
    end
end
