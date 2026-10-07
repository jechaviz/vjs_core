module vjs_core

fn test_plan_runs_supported_dom_subset() {
	request := EvalRequest{
		source: 'document.title = "Demo";'
	}
	result := plan(request, strict_policy())
	assert result.decision == .run
	assert result.backend == .vjs
}

fn test_plan_denies_host_capabilities_without_fallback() {
	request := EvalRequest{
		source: 'fetch("https://example.test")'
	}
	result := plan(request, strict_policy())
	assert result.decision == .deny
	assert result.reason.contains('capability')
}

fn test_plan_requests_fallback_for_unsupported_compat_syntax() {
	request := EvalRequest{
		source: 'const fn = () => document.title;'
	}
	result := plan(request, strict_policy())
	assert result.decision == .fallback
	assert result.backend == .quickjs
}
