module vjs_core

pub enum ScriptBackend {
	strict_literal
	vjs
	quickjs
}

pub enum EvalDecision {
	run
	deny
	fallback
}

pub struct EvalRequest {
pub:
	source string
	url    string = 'about:blank'
	origin string
	module bool
	dom    DomSnapshot
}

pub struct EvalPlan {
pub:
	decision    EvalDecision
	backend     ScriptBackend
	reason      string
	diagnostics []string
}

pub fn plan(request EvalRequest, policy RuntimePolicy) EvalPlan {
	source := request.source.trim_space()
	if source == '' {
		return eval_plan(.deny, .vjs, 'empty script', ['vjs.plan=deny'])
	}
	if source.len > policy.max_source_bytes {
		return eval_plan(.deny, .vjs, 'source budget exceeded', [
			'vjs.plan=deny',
		])
	}
	lower := source.to_lower()
	if lower.contains('fetch(') || lower.contains('xmlhttprequest') || lower.contains('filesystem')
		|| lower.contains('fs.') {
		return eval_plan(.deny, .vjs, 'host capability denied', [
			'vjs.plan=deny',
		])
	}
	if contains_fallback_syntax(lower) {
		return eval_plan(.fallback, .quickjs, 'unsupported syntax for VJS', [
			'vjs.plan=fallback',
		])
	}
	return eval_plan(.run, .vjs, 'supported VJS subset', [
		'vjs.plan=run',
	])
}

pub fn eval(request EvalRequest, policy RuntimePolicy) RunResult {
	eval_plan_result := plan(request, policy)
	if eval_plan_result.decision == .deny {
		return error_result(eval_plan_result.reason, eval_plan_result.diagnostics)
	}
	if eval_plan_result.decision == .fallback {
		return error_result('fallback required: ${eval_plan_result.reason}',
			eval_plan_result.diagnostics)
	}
	return run(request.source, request.dom, policy)
}

fn contains_fallback_syntax(lower string) bool {
	needles := [
		'=>',
		' async ',
		' await ',
		' import ',
		' export ',
		' class ',
		' new ',
		' promise',
		' eval(',
		' function*',
		' yield ',
		' for ',
		' while ',
	]
	for needle in needles {
		if lower.contains(needle) {
			return true
		}
	}
	return false
}

fn eval_plan(decision EvalDecision, backend ScriptBackend, reason string, diagnostics []string) EvalPlan {
	return EvalPlan{
		decision:    decision
		backend:     backend
		reason:      reason
		diagnostics: diagnostics.clone()
	}
}
