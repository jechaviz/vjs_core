module vjs_core

struct Parser {
	tokens []Token
mut:
	index int
}

pub fn parse(source string) !Program {
	return parse_tokens(lex(source)!)
}

pub fn parse_tokens(tokens []Token) !Program {
	mut parser := Parser{
		tokens: tokens
	}
	mut stmts := []Stmt{}
	for !parser.check(.eof) {
		if parser.match_kind(.semicolon) {
			continue
		}
		stmts << parser.parse_stmt()!
		parser.match_kind(.semicolon)
	}
	return Program{
		stmts: stmts
	}
}

fn (mut p Parser) parse_stmt() !Stmt {
	if p.match_name('const') || p.match_name('let') || p.match_name('var') {
		name := p.consume(.name, 'variable name')!.lit
		p.consume(.assign, '=')!
		return Stmt{
			kind:  .var_decl
			name:  name
			value: p.parse_expr()!
		}
	}
	expr := p.parse_expr()!
	if p.match_kind(.assign) {
		return Stmt{
			kind:   .assign
			target: expr
			value:  p.parse_expr()!
		}
	}
	return Stmt{
		kind:  .expr
		value: expr
	}
}

fn (mut p Parser) parse_expr() !Expr {
	mut expr := p.parse_primary()!
	for p.match_kind(.plus) {
		right := p.parse_primary()!
		expr = Expr{
			kind:  .binary
			value: '+'
			args:  [expr, right]
		}
	}
	return expr
}

fn (mut p Parser) parse_primary() !Expr {
	mut expr := Expr{}
	if p.match_kind(.str) {
		expr = literal(p.previous().lit)
	} else if p.match_kind(.number) {
		expr = literal(p.previous().lit)
	} else if p.match_kind(.lbrace) {
		expr = p.parse_object()!
	} else if p.match_kind(.lbracket) {
		expr = p.parse_array()!
	} else if p.match_name('function') {
		expr = p.parse_function_body()!
	} else if p.match_kind(.name) {
		expr = identifier(p.previous().lit)
	} else if p.match_kind(.lparen) {
		expr = p.parse_expr()!
		p.consume(.rparen, ')')!
	} else {
		return error('expected expression at ${p.peek().pos}')
	}
	return p.parse_postfix(expr)!
}

fn (mut p Parser) parse_postfix(base Expr) !Expr {
	mut expr := base
	for {
		if p.match_kind(.dot) {
			name := p.consume(.name, 'member name')!.lit
			expr = Expr{
				kind:  .member
				value: name
				args:  [expr]
			}
			continue
		}
		if p.match_kind(.lparen) {
			args := p.parse_args()!
			mut call_args := [expr]
			call_args << args
			expr = Expr{
				kind: .call
				args: call_args
			}
			continue
		}
		break
	}
	return expr
}

fn (mut p Parser) parse_args() ![]Expr {
	mut args := []Expr{}
	if p.match_kind(.rparen) {
		return args
	}
	for {
		args << p.parse_expr()!
		if p.match_kind(.rparen) {
			break
		}
		p.consume(.comma, ',')!
	}
	return args
}

fn (mut p Parser) parse_object() !Expr {
	mut keys := []string{}
	mut values := []Expr{}
	if p.match_kind(.rbrace) {
		return Expr{
			kind: .object
		}
	}
	for {
		key := if p.match_kind(.str) {
			p.previous().lit
		} else {
			p.consume(.name, 'object key')!.lit
		}
		p.consume(.colon, ':')!
		keys << key
		values << p.parse_expr()!
		if p.match_kind(.rbrace) {
			break
		}
		p.consume(.comma, ',')!
	}
	return Expr{
		kind: .object
		keys: keys
		args: values
	}
}

fn (mut p Parser) parse_array() !Expr {
	mut values := []Expr{}
	if p.match_kind(.rbracket) {
		return Expr{
			kind: .array
		}
	}
	for {
		values << p.parse_expr()!
		if p.match_kind(.rbracket) {
			break
		}
		p.consume(.comma, ',')!
	}
	return Expr{
		kind: .array
		args: values
	}
}

fn (mut p Parser) parse_function_body() !Expr {
	p.consume(.lparen, '(')!
	mut depth := 1
	for depth > 0 && !p.check(.eof) {
		if p.match_kind(.lparen) {
			depth++
		} else if p.match_kind(.rparen) {
			depth--
		} else {
			p.advance()
		}
	}
	p.consume(.lbrace, '{')!
	mut chunks := []string{}
	for !p.check(.rbrace) && !p.check(.eof) {
		chunks << p.advance().lit
	}
	p.consume(.rbrace, '}')!
	return Expr{
		kind:  .literal
		value: '__function__'
		keys:  chunks
	}
}

fn (mut p Parser) match_name(name string) bool {
	if p.check(.name) && p.peek().lit == name {
		p.advance()
		return true
	}
	return false
}

fn (mut p Parser) match_kind(kind TokenKind) bool {
	if p.check(kind) {
		p.advance()
		return true
	}
	return false
}

fn (p Parser) check(kind TokenKind) bool {
	return p.peek().kind == kind
}

fn (p Parser) peek() Token {
	if p.index >= p.tokens.len {
		return token(.eof, '', 0)
	}
	return p.tokens[p.index]
}

fn (p Parser) previous() Token {
	return p.tokens[p.index - 1]
}

fn (mut p Parser) advance() Token {
	if !p.check(.eof) {
		p.index++
	}
	return p.previous()
}

fn (mut p Parser) consume(kind TokenKind, expected string) !Token {
	if p.check(kind) {
		return p.advance()
	}
	return error('expected ${expected} at ${p.peek().pos}')
}
