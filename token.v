module vjs_core

pub enum TokenKind {
	eof
	name
	number
	str
	lparen
	rparen
	lbrace
	rbrace
	lbracket
	rbracket
	dot
	comma
	colon
	semicolon
	assign
	plus
	minus
	star
	slash
}

pub struct Token {
pub:
	kind TokenKind
	lit  string
	pos  int
}

pub fn token(kind TokenKind, lit string, pos int) Token {
	return Token{
		kind: kind
		lit:  lit
		pos:  pos
	}
}
