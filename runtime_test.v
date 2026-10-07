module vjs_core

fn test_runtime_emits_title_operation() {
	result := run('document.title = "Demo";', empty_dom(), strict_policy())
	assert result.ok
	assert result.ops.len == 1
	assert result.ops[0].kind == .set_title
	assert result.ops[0].value == 'Demo'
}

fn test_runtime_query_selector_text_content() {
	dom := DomSnapshot{
		nodes: [
			DomNode{
				id:   'msg'
				tag:  'p'
				text: 'old'
			},
		]
	}
	result := run('let el = document.querySelector("#msg"); el.textContent = "Hola";', dom,
		strict_policy())
	assert result.ok
	assert result.ops.len == 1
	assert result.ops[0].kind == .set_text
	assert result.ops[0].selector == '#msg'
	assert result.ops[0].value == 'Hola'
}

fn test_runtime_class_list_event_and_timer_are_operations() {
	dom := DomSnapshot{
		nodes: [
			DomNode{
				id:      'btn'
				tag:     'button'
				classes: ['action']
			},
		]
	}
	source := 'let el = document.querySelector(".action"); el.classList.add("on"); el.addEventListener("click", function () { el.textContent = "clicked"; }); setTimeout(function () { document.title = "late"; }, 10);'
	result := run(source, dom, strict_policy())
	assert result.ok
	assert result.ops.len == 3
	assert result.ops[0].kind == .add_class
	assert result.ops[1].kind == .add_event
	assert result.ops[2].kind == .timer
	assert result.ops[2].delay_ms == 10
}

fn test_runtime_policy_blocks_timers() {
	result := run('setTimeout(function () {}, 1);', empty_dom(), tiny_policy())
	assert !result.ok
	assert result.error.contains('timers blocked')
}

fn test_runtime_step_limit_reports_error() {
	result := run('let a = "x"; let b = "y"; let c = a + b;', empty_dom(), RuntimePolicy{
		max_source_bytes: 2048
		max_steps:        2
		max_dom_nodes:    128
	})
	assert !result.ok
	assert result.error.contains('step limit')
}
