@tool
extends Resource
class_name Matrix

var values : Array = []

func _init(matrix : Array = [], size : int = 0) -> void:
	values = matrix

func insert_row(row : Array, index : int = values.size()) -> void:
	if rows() != 0:
		assert(row.size() == columns()) #,"the row size must match matrix row size")
	values.insert(index, row)

func update_row(row : Array, index : int) -> void:
	assert(rows() > index) #,"the row size must match matrix row size")
	values[index] = row

func remove_row(index: int) -> void:
	assert(rows() > index) #,"the row size must match matrix row size")
	values.remove_at(index)

func insert_column(column : Array, index : int = values[0].size()) -> void:
	if columns() != 0:
		assert(column.size() == rows()) #,"the column size must match matrix column size")
	for row_idx in column.size():
		values[row_idx].insert(index, column[row_idx])

func update_column(column : Array, index : int) -> void:
	assert(columns() > index) #,"the column size must match matrix column size")
	for row_idx in column.size():
		values[row_idx][index] = column[row_idx]

func remove_column(index: int) -> void:
	assert(columns() > index) #,"the column index must be at least equals to the rows count")
	for row in get_rows():
		row.remove(index)

func resize(rows: int, columns: int) -> void:
	for row in range(rows):
		var row_column: Array = []
		row_column.resize(columns)
		values.append(row_column)

func to_array() -> Array:
	return values.duplicate(true)

func get_size() -> Vector2:
	return Vector2(rows(), columns())

func rows() -> int:
	return values.size()

func columns() -> int:
	return values[0].size() if rows() != 0 else 0

func value(row: int, column: int) -> float:
	return values[row][column]

func set_value(value: float, row: int, column: int) -> void:
	values[row][column] = value

func get_column(column : int) -> Array:
	assert(column < columns()) #,"index of the column requested (%s) exceedes matrix columns (%s)"%[column, columns()])
	var column_array : Array = []
	for row in values: 
		column_array.append(row[column])
	return column_array

func get_columns(from : int = 0, to : int = columns()-1) -> Array:
	var values : Array = []
	for column in range(from, to):
		values.append(get_column(column))
	return values
#    return MatrixGenerator.from_array(values)

func get_row(row : int) -> Array:
	assert(row < rows()) #,"index of the row requested (%s) exceedes matrix rows (%s)"%[row, rows()])
	return values[row]

func get_rows(from : int = 0, to : int = rows()-1) -> Array:
	return values.slice(from, to)
#    return MatrixGenerator.from_array(values)    

func is_empty() -> bool:
	return rows() == 0 and columns() == 0


func is_square() -> bool:
	return columns() == rows()


func is_diagonal() -> bool:
	if not is_square():
		return false
	
	for i in rows():
		for j in columns():
			if i != j and values[i][j] != 0:
				return false
	
	return true


func is_upper_triangular() -> bool:
	if not is_square():
		return false
	
	for i in rows():
		for j in columns():
			if i > j and values[i][j] != 0:
				return false
	
	return true


func is_lower_triangular() -> bool:
	if not is_square():
		return false
	
	for i in rows():
		for j in columns():
			if i < j and values[i][j] != 0:
				return false
	
	return true


func is_triangular() -> bool:
	return is_upper_triangular() or is_lower_triangular()


func is_identity() -> bool:
	if not is_diagonal():
		return false
	
	for i in rows():
		if values[i][i] != 1:
			return false
	
	return true

func _to_string() -> String:
	var last_string_len : int
	for row in values:
		for column in row:
			var string_len : int = str(column).length()
			last_string_len = string_len if string_len > last_string_len else last_string_len
	var string : String = "\n"
	for row_i in values.size():
		for column_i in values[row_i].size():
			string+="%*s" % [last_string_len+1 if column_i!=0 else last_string_len, values[row_i][column_i]]
		string+="\n"
	return string

# ----
func set(position: StringName, value: Variant) -> void:
	var t_pos: Array = position.split(",")
	values[t_pos[0]][t_pos[1]] = value

# --------------
func _get(_property : StringName):
	# ":" --> Columns 
	if ":" in _property:
		var property : PackedStringArray = _property.split(":") 
		var from : PackedStringArray = property[0].split(",")
		var to : PackedStringArray = property[1].split(",")
	elif "," in _property:
		var property : PackedStringArray = _property.split(",")
		if property.size() == 2:
			return get_row(property[0] as int)[property[1] as int]
	else:
		if (_property as String).is_valid_int():
			return get_row(int(_property))
