extends Node

func spawn_units(mission_data: Resource):
	var party_data = CampaignManager.current_party
	for i in range(mission_data.units.size()):
		var unit_data = mission_data.units[i]
		if i < party_data.size():
			unit_data = party_data[i]
		var spawn_points = get_tree().get_nodes_in_group("spawn_points")
		if spawn_points.size() == 0: return
		var spawn_point = spawn_points[i % spawn_points.size()]
		var unit = unit_data.scene.instantiate()
		get_tree().current_scene.add_child(unit)
		unit.global_position = spawn_point.global_position
		if unit.has_method("setup_unit"):
			unit.setup_unit(unit_data)