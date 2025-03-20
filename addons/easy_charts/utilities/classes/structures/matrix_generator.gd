@tool
extends RefCounted
class_name MatrixGenerator

static func zeros(rows: int, columns: int) -> Matrix:
	var zeros: Array = []
	var t_rows: Array = []
	t_rows.resize(columns)
	t_rows.fill(0.0)
	for row in rows:
		zeros.append(t_rows.duplicate())
	return Matrix.new(zeros)

# Generates a Matrix with random values between [from; to] with a given @size (rows, columns)
static func random_float_range(from : float, to : float, size : Vector2, _seed : int = 1234) -> Matrix:
	seed(_seed)
	randomize()
	var array : Array = []
	for row in range(size.x):
		var matrix_row : Array = []
		for column in range(size.y): matrix_row.append(randf_range(from,to))
		array.append(matrix_row)
	return Matrix.new(array)

# Generates a Matrix giving an Array (Array must by Array[Array])
static func from_array(array : Array = []) -> Matrix:
	var matrix : Array = []
	matrix.append(array)
	return Matrix.new(matrix)

# Generates a sub-Matrix giving a Matrix, a @from Array [row_i, column_i] and a @to Array [row_j, column_j]
static func sub_matrix(_matrix : Matrix, from : PackedInt32Array, to : PackedInt32Array) -> Matrix:
	assert( not (to[0] > _matrix.rows() or to[1] > _matrix.columns()), 
		"%s is not an acceptable size for the submatrix, giving a matrix of size %s"%[to, _matrix.get_size()])
	var array : Array = []
	var rows : Array = _matrix.get_rows(from[0], to[0])
	for row in rows:
		array.append(row.slice(from[1], to[1]))
	return Matrix.new(array)

# Duplicates a given Matrix
static func duplicate(_matrix : Matrix) -> Matrix:
	return Matrix.new(_matrix.to_array().duplicate())

# Calculate the determinant of a matrix
static func determinant(matrix: Matrix) -> float:
	assert(matrix.is_square()) #,"Expected square matrix")
	
	var determinant: float = 0.0
	
	if matrix.rows() == 2 :
		determinant = (matrix.value(0, 0) * matrix.value(1, 1)) - (matrix.value(0, 1) * matrix.value(1, 0))
	elif matrix.is_diagonal() or matrix.is_triangular() :
		for i in matrix.rows():
			determinant *= matrix.value(i, i)
	elif matrix.is_identity() :
		determinant = 1.0
	else:
		# Laplace expansion
		var multiplier: float = -1.0
		var submatrix: Matrix = sub_matrix(matrix, [1, 0], [matrix.rows(), matrix.columns()])
		for j in matrix.columns() :
			var cofactor: Matrix = copy(submatrix)
			cofactor.remove_column(j)
			multiplier *= -1.0
			determinant += multiplier * matrix.value(0, j) * determinant(cofactor)
	
	return determinant


# Calculate the inverse of a Matrix
static func inverse(matrix: Matrix) -> Matrix:
	var inverse: Matrix
	
	# Minors and Cofactors
	var minors_cofactors: Matrix = zeros(matrix.rows(), matrix.columns())
	var multiplier: float = -1.0
	
	for i in minors_cofactors.rows():
		for j in minors_cofactors.columns():
			var t_minor: Matrix = copy(matrix)
			t_minor.remove_row(i)
			t_minor.remove_column(j)
			multiplier *= -1.0
			minors_cofactors.set_value(multiplier * determinant(t_minor), i, j)
	
	var transpose: Matrix = transpose(minors_cofactors)
	var determinant: float = determinant(matrix)
	
	inverse = multiply_float(transpose, 1 / determinant)
	
	return inverse

# Transpose a given Matrix
static func transpose(_matrix : Matrix) -> Matrix:
	var array : Array = []
	array.resize(_matrix.get_size().y)
	var row : Array = []
	row.resize(_matrix.get_size().x)
	for x in array.size():
		array[x] = row.duplicate()
	for i in range(_matrix.get_size().x):
		for j in range(_matrix.get_size().y):
			array[j][i] = (_matrix.to_array()[i][j])
	return Matrix.new(array)

# Calculates the dot product (A*B) matrix between two Matrixes
static func dot(_matrix1 : Matrix, _matrix2 : Matrix) -> Matrix:
	if _matrix1.get_size().y != _matrix2.get_size().x: 
		printerr("matrix1 number of columns: %s must be the same as matrix2 number of rows: %s"%[_matrix1.get_size().y, _matrix2.get_size().x])
		return Matrix.new()
	var array : Array = []
	for x in range(_matrix1.get_size().x):
		var row : Array = []
		for y in range(_matrix2.get_size().y):
			var sum : float
			for k in range(_matrix1.get_size().y):
				sum += (_matrix1.to_array()[x][k]*_matrix2.to_array()[k][y])
			row.append(sum)
		array.append(row)
	return Matrix.new(array)

# Calculates the hadamard (element-wise product) between two Matrixes
static func hadamard(_matrix1 : Matrix, _matrix2 : Matrix) -> Matrix:
	if _matrix1.get_size() != _matrix2.get_size(): 
		printerr("matrix1 size: %s must be the same as matrix2 size: %s"%[_matrix1.get_size(), _matrix2.get_size()])
		return Matrix.new()
	var array : Array = []
	for x in range(_matrix1.to_array().size()):
		var row : Array = []
		for y in range(_matrix1.to_array()[x].size()):
			assert(typeof(_matrix1.to_array()[x][y]) != TYPE_STRING and typeof(_matrix2.to_array()[x][y]) != TYPE_STRING) #,"can't apply operations over a Matrix of Strings")
			row.append(_matrix1.to_array()[x][y] * _matrix2.to_array()[x][y])
		array.append(row)
	return Matrix.new(array)

# Multiply a given Matrix for an int value
static func multiply_int(_matrix1 : Matrix, _int : int) -> Matrix:
	var array : Array = _matrix1.to_array().duplicate()
	for x in range(_matrix1.to_array().size()):
		for y in range(_matrix1.to_array()[x].size()):
			array[x][y]*=_int
			array[x][y] = int(array[x][y])
	return Matrix.new(array)

# Multiply a given Matrix for a float value
static func multiply_float(_matrix1 : Matrix, _float : float) -> Matrix:
	var array : Array = _matrix1.to_array().duplicate()
	for x in range(_matrix1.to_array().size()):
		for y in range(_matrix1.to_array()[x].size()):
			array[x][y]*=_float
	return Matrix.new(array)


static func copy(matrix: Matrix) -> Matrix:
	return Matrix.new(matrix.values.duplicate(true))

# ------------------------------------------------------------
static func get_letter_index(index : int) -> String:
	return "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z".split(" ")[index]
