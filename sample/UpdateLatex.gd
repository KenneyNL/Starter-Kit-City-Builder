extends TextEdit

@onready var Latex = get_parent().get_node("LaTeX")

func _on_text_changed():
	Latex.LatexExpression = self.text
	Latex.Render()

