extends NavigationRegion3D

func _ready():
	# Bake the navigation mesh
	bake_navigation_mesh()
	print("Navigation mesh baked successfully")
	
	# Update the character's start position and direction
	var character = get_parent().get_node("Character")
	if character:
		# Set initial movement along X axis
		character.direction = Vector3(1, 0, 0)
		character.patrol_distance = 10.0
		print("Character initialized for navigation")