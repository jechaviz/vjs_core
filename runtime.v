module vjs_core

struct Scope {
mut:
	values map[string]Value
}

pub struct Runtime {
pub:
	policy RuntimePolicy
	dom    DomSnapshot
mut:
	steps int
	ops   []DomOp
	scope Scope
}

pub fn new_runtime(policy RuntimePolicy, dom DomSnapshot) !Runtime {
	if dom.nodes.len > policy.max_dom_nodes {
		return error('dom exceeds policy max_dom_nodes=${policy.max_dom_nodes}')
	}
	return Runtime{
		policy: policy
		dom:    dom
		scope:  Scope{
			values: {
				'document':   object_value({
					'title': string_value(dom.title)
				})
				'window':     object_value({})
				'globalThis': object_value({})
				'null':       null_value()
				'true':       bool_value(true)
				'false':      bool_value(false)
			}
		}
	}
}

pub fn run(source string, dom DomSnapshot, policy RuntimePolicy) RunResult {
	policy.validate_source(source) or {
		return error_result(err.msg(), ['vjs.phase=policy'])
	}
	program := parse(source) or { return error_result(err.msg(), ['vjs.phase=parse']) }
	mut runtime := new_runtime(policy, dom) or {
		return error_result(err.msg(), ['vjs.phase=runtime'])
	}
	value := runtime.eval_program(program) or {
		return error_result(err.msg(), runtime.diagnostics('runtime'))
	}
	return ok_result(value, runtime.ops, runtime.diagnostics('ok'))
}

fn (mut runtime Runtime) eval_program(program Program) !Value {
	mut last := null_value()
	for stmt in program.stmts {
		runtime.tick()!
		last = runtime.eval_stmt(stmt)!
	}
	return last
}

fn (mut runtime Runtime) eval_stmt(stmt Stmt) !Value {
	return match stmt.kind {
		.expr {
			runtime.eval_expr(stmt.value)!
		}
		.var_decl {
			value := runtime.eval_expr(stmt.value)!
			runtime.scope.values[stmt.name] = value
			value
		}
		.assign {
			runtime.assign(stmt.target, runtime.eval_expr(stmt.value)!)!
		}
		.block {
			mut last := null_value()
			for child in stmt.body {
				last = runtime.eval_stmt(child)!
			}
			last
		}
	}
}

fn (mut runtime Runtime) eval_expr(expr Expr) !Value {
	runtime.tick()!
	return match expr.kind {
		.empty { null_value() }
		.literal { literal_value(expr.value) }
		.identifier { runtime.scope.values[expr.value] or { error('undefined name ${expr.value}') } }
		.member { runtime.member(expr)! }
		.call { runtime.call(expr)! }
		.object { runtime.object(expr)! }
		.array { runtime.array(expr)! }
		.binary { runtime.binary(expr)! }
	}
}

fn literal_value(value string) Value {
	if value == 'true' {
		return bool_value(true)
	}
	if value == 'false' {
		return bool_value(false)
	}
	if value == 'null' {
		return null_value()
	}
	if value.len > 0 && value[0].is_digit() {
		return number_value(value.f64())
	}
	return string_value(value)
}

fn (mut runtime Runtime) member(expr Expr) !Value {
	base := runtime.eval_expr(expr.args[0])!
	return match base.kind {
		.object {
			base.fields[expr.value] or { null_value() }
		}
		.dom_node {
			match expr.value {
				'textContent' {
					node := runtime.dom.find(base.selector) or { return null_value() }
					string_value(node.text)
				}
				'classList' {
					class_list_value(base.selector)
				}
				else {
					null_value()
				}
			}
		}
		else {
			null_value()
		}
	}
}

fn (mut runtime Runtime) call(expr Expr) !Value {
	if expr.args.len == 0 {
		return error('call target missing')
	}
	target := expr.args[0]
	if target.kind == .member {
		return runtime.call_member(target, expr.args[1..])!
	}
	if target.kind == .identifier && target.value == 'setTimeout' {
		return runtime.call_set_timeout(expr.args[1..])!
	}
	return error('unsupported call')
}

fn (mut runtime Runtime) call_member(target Expr, args []Expr) !Value {
	if target.args.len == 0 {
		return error('member call target missing')
	}
	base := runtime.eval_expr(target.args[0])!
	if base.kind == .object && target.args[0].kind == .identifier
		&& target.args[0].value == 'document' {
		if target.value == 'querySelector' {
			selector := runtime.eval_expr(args[0])!.display()
			if _ := runtime.dom.find(selector) {
				return dom_node_value(selector)
			}
			return null_value()
		}
	}
	if base.kind == .class_list {
		name := runtime.eval_expr(args[0])!.display()
		match target.value {
			'add' { runtime.ops << dom_op(.add_class, base.selector, 'class', name, 0) }
			'remove' { runtime.ops << dom_op(.remove_class, base.selector, 'class', name, 0) }
			'toggle' { runtime.ops << dom_op(.add_class, base.selector, 'class', name, 0) }
			else { return error('unsupported classList.${target.value}') }
		}

		return null_value()
	}
	if base.kind == .dom_node && target.value == 'addEventListener' {
		if !runtime.policy.allow_events {
			return error('events blocked by policy')
		}
		event_name := runtime.eval_expr(args[0])!.display()
		runtime.ops << dom_op(.add_event, base.selector, event_name, 'callback', 0)
		return null_value()
	}
	return error('unsupported member call ${target.value}')
}

fn (mut runtime Runtime) call_set_timeout(args []Expr) !Value {
	if !runtime.policy.allow_timers {
		return error('timers blocked by policy')
	}
	delay := if args.len > 1 { int(runtime.eval_expr(args[1])!.number) } else { 0 }
	runtime.ops << dom_op(.timer, '', 'setTimeout', 'callback', delay)
	return number_value(0)
}

fn (mut runtime Runtime) assign(target Expr, value Value) !Value {
	if target.kind == .member && target.args.len > 0 {
		base := runtime.eval_expr(target.args[0])!
		if target.args[0].kind == .identifier && target.args[0].value == 'document'
			&& target.value == 'title' {
			runtime.ops << dom_op(.set_title, '', 'title', value.display(), 0)
			return value
		}
		if base.kind == .dom_node && target.value == 'textContent' {
			runtime.ops << dom_op(.set_text, base.selector, 'textContent', value.display(), 0)
			return value
		}
	}
	if target.kind == .identifier {
		runtime.scope.values[target.value] = value
		return value
	}
	return error('unsupported assignment target')
}

fn (mut runtime Runtime) object(expr Expr) !Value {
	mut fields := map[string]Value{}
	for index, key in expr.keys {
		fields[key] = runtime.eval_expr(expr.args[index])!
	}
	return object_value(fields)
}

fn (mut runtime Runtime) array(expr Expr) !Value {
	mut items := []Value{cap: expr.args.len}
	for item in expr.args {
		items << runtime.eval_expr(item)!
	}
	return array_value(items)
}

fn (mut runtime Runtime) binary(expr Expr) !Value {
	left := runtime.eval_expr(expr.args[0])!
	right := runtime.eval_expr(expr.args[1])!
	return match expr.value {
		'+' { string_value(left.display() + right.display()) }
		else { error('unsupported binary operator ${expr.value}') }
	}
}

fn (mut runtime Runtime) tick() ! {
	runtime.steps++
	if runtime.steps > runtime.policy.max_steps {
		return error('step limit exceeded')
	}
}

fn (runtime Runtime) diagnostics(phase string) []string {
	return [
		'vjs.phase=${phase}',
		'vjs.steps=${runtime.steps}',
		'vjs.max_steps=${runtime.policy.max_steps}',
		'vjs.max_source_bytes=${runtime.policy.max_source_bytes}',
		'vjs.dom_nodes=${runtime.dom.nodes.len}',
	]
}

fn dom_op(kind DomOpKind, selector string, name string, value string, delay_ms int) DomOp {
	return DomOp{
		kind:     kind
		selector: selector
		name:     name
		value:    value
		delay_ms: delay_ms
	}
}
