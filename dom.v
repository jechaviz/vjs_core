module vjs_core

pub struct DomNode {
pub:
	id      string
	tag     string
	text    string
	classes []string
	attrs   map[string]string
}

pub struct DomSnapshot {
pub:
	title string
	nodes []DomNode
}

pub enum DomOpKind {
	set_title
	set_text
	add_class
	remove_class
	set_attr
	add_event
	timer
}

pub struct DomOp {
pub:
	kind     DomOpKind
	selector string
	name     string
	value    string
	delay_ms int
}

pub fn empty_dom() DomSnapshot {
	return DomSnapshot{}
}

pub fn (dom DomSnapshot) with_title(title string) DomSnapshot {
	return DomSnapshot{
		...dom
		title: title
	}
}

pub fn (dom DomSnapshot) find(selector string) ?DomNode {
	clean := selector.trim_space()
	if clean == '' {
		return none
	}
	for node in dom.nodes {
		if selector_matches(node, clean) {
			return node
		}
	}
	return none
}

pub fn selector_matches(node DomNode, selector string) bool {
	if selector.starts_with('#') {
		return node.id == selector[1..]
	}
	if selector.starts_with('.') {
		return selector[1..] in node.classes
	}
	return node.tag == selector.to_lower()
}
