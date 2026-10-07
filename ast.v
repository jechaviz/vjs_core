module vjs_core

pub enum ExprKind {
	empty
	literal
	identifier
	member
	call
	object
	array
	binary
}

pub enum StmtKind {
	expr
	assign
	var_decl
	block
}

pub struct Expr {
pub:
	kind  ExprKind
	value string
	left  int = -1
	right int = -1
	args  []Expr
	keys  []string
}

pub struct Stmt {
pub:
	kind   StmtKind
	name   string
	target Expr
	value  Expr
	body   []Stmt
}

pub struct Program {
pub:
	stmts []Stmt
}

pub fn literal(value string) Expr {
	return Expr{
		kind:  .literal
		value: value
	}
}

pub fn identifier(name string) Expr {
	return Expr{
		kind:  .identifier
		value: name
	}
}
