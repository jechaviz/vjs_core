module vjs_core

fn test_lexer_reads_dom_script_tokens() {
	tokens := lex('document.title = "Demo";') or { panic(err.msg()) }
	assert tokens[0].lit == 'document'
	assert tokens[1].kind == .dot
	assert tokens[2].lit == 'title'
	assert tokens[4].lit == 'Demo'
	assert tokens.last().kind == .eof
}

fn test_lexer_blocks_unknown_characters() {
	lex('a @ b') or {
		assert err.msg().contains('unsupported character')
		return
	}
	assert false
}
