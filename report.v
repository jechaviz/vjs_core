module vjs_core

pub struct RunResult {
pub:
	ok          bool
	value       Value
	error       string
	ops         []DomOp
	diagnostics []string
}

pub fn ok_result(value Value, ops []DomOp, diagnostics []string) RunResult {
	return RunResult{
		ok:          true
		value:       value
		ops:         ops.clone()
		diagnostics: diagnostics.clone()
	}
}

pub fn error_result(message string, diagnostics []string) RunResult {
	return RunResult{
		error:       message
		diagnostics: diagnostics.clone()
	}
}

pub fn (result RunResult) report() string {
	mut lines := [
		'vjs.ok=${result.ok}',
		'vjs.value=${result.value.display()}',
		'vjs.error=${result.error}',
		'vjs.ops=${result.ops.len}',
	]
	lines << result.diagnostics
	return lines.join('\n')
}
