module vjs_core

pub struct RuntimePolicy {
pub:
	max_source_bytes int  = 1024 * 1024
	max_steps        int  = 1_000_000
	max_dom_nodes    int  = 100_000
	allow_timers     bool = true
	allow_events     bool = true
	allow_host_fallback bool = true
}

pub fn open_policy() RuntimePolicy {
	return RuntimePolicy{}
}

pub fn strict_policy() RuntimePolicy {
	return RuntimePolicy{
		max_source_bytes: 8192
		max_steps: 4096
		max_dom_nodes: 512
		allow_timers: true
		allow_events: true
		allow_host_fallback: false
	}
}

pub fn tiny_policy() RuntimePolicy {
	return RuntimePolicy{
		max_source_bytes: 2048
		max_steps:        512
		max_dom_nodes:    128
		allow_timers:     false
		allow_events:     false
	}
}

pub fn (policy RuntimePolicy) validate_source(source string) ! {
	if source.len > policy.max_source_bytes {
		return error('source exceeds policy max_source_bytes=${policy.max_source_bytes}')
	}
}
