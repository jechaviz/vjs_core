module vjs_core

pub fn lex(source string) ![]Token {
	mut out := []Token{}
	mut i := 0
	for i < source.len {
		ch := source[i]
		if ch <= ` ` {
			i++
			continue
		}
		if is_name_start(ch) {
			start := i
			i++
			for i < source.len && is_name_part(source[i]) {
				i++
			}
			out << token(.name, source[start..i], start)
			continue
		}
		if ch >= `0` && ch <= `9` {
			start := i
			i++
			for i < source.len && source[i] >= `0` && source[i] <= `9` {
				i++
			}
			out << token(.number, source[start..i], start)
			continue
		}
		if ch == `"` || ch == `'` {
			lit, next := read_string(source, i)!
			out << token(.str, lit, i)
			i = next
			continue
		}
		match ch {
			`(` { out << token(.lparen, '(', i) }
			`)` { out << token(.rparen, ')', i) }
			`{` { out << token(.lbrace, '{', i) }
			`}` { out << token(.rbrace, '}', i) }
			`[` { out << token(.lbracket, '[', i) }
			`]` { out << token(.rbracket, ']', i) }
			`.` { out << token(.dot, '.', i) }
			`,` { out << token(.comma, ',', i) }
			`:` { out << token(.colon, ':', i) }
			`;` { out << token(.semicolon, ';', i) }
			`=` { out << token(.assign, '=', i) }
			`+` { out << token(.plus, '+', i) }
			`-` { out << token(.minus, '-', i) }
			`*` { out << token(.star, '*', i) }
			`/` { out << token(.slash, '/', i) }
			else { return error('unsupported character `${ch.ascii_str()}` at ${i}') }
		}

		i++
	}
	out << token(.eof, '', source.len)
	return out
}

fn read_string(source string, start int) !(string, int) {
	quote := source[start]
	mut i := start + 1
	mut bytes := []u8{}
	for i < source.len {
		ch := source[i]
		if ch == quote {
			return bytes.bytestr(), i + 1
		}
		if ch == `\\` && i + 1 < source.len {
			i++
			escaped := source[i]
			bytes << match escaped {
				`n` { `\n` }
				`t` { `\t` }
				`r` { `\r` }
				else { escaped }
			}

			i++
			continue
		}
		bytes << ch
		i++
	}
	return error('unterminated string at ${start}')
}

fn is_name_start(ch u8) bool {
	return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` || ch == `$`
}

fn is_name_part(ch u8) bool {
	return is_name_start(ch) || (ch >= `0` && ch <= `9`)
}
