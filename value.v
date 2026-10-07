module vjs_core

pub enum ValueKind {
	null
	boolean
	number
	str
	object
	array
	dom_node
	class_list
}

pub struct Value {
pub:
	kind     ValueKind
	text     string
	number   f64
	boolean  bool
	fields   map[string]Value
	items    []Value
	selector string
}

pub fn null_value() Value {
	return Value{}
}

pub fn bool_value(value bool) Value {
	return Value{
		kind:    .boolean
		boolean: value
	}
}

pub fn number_value(value f64) Value {
	return Value{
		kind:   .number
		number: value
		text:   trim_number(value)
	}
}

pub fn string_value(value string) Value {
	return Value{
		kind: .str
		text: value
	}
}

pub fn object_value(fields map[string]Value) Value {
	return Value{
		kind:   .object
		fields: fields.clone()
	}
}

pub fn array_value(items []Value) Value {
	return Value{
		kind:  .array
		items: items.clone()
	}
}

pub fn dom_node_value(selector string) Value {
	return Value{
		kind:     .dom_node
		selector: selector
	}
}

pub fn class_list_value(selector string) Value {
	return Value{
		kind:     .class_list
		selector: selector
	}
}

pub fn (value Value) truthy() bool {
	return match value.kind {
		.null { false }
		.boolean { value.boolean }
		.number { value.number != 0 }
		.str { value.text != '' }
		else { true }
	}
}

pub fn (value Value) display() string {
	return match value.kind {
		.null {
			'null'
		}
		.boolean {
			if value.boolean {
				'true'
			} else {
				'false'
			}
		}
		.number {
			value.text
		}
		.str {
			value.text
		}
		.object {
			'[object Object]'
		}
		.array {
			value.items.map(it.display()).join(',')
		}
		.dom_node {
			'[dom ${value.selector}]'
		}
		.class_list {
			'[classList ${value.selector}]'
		}
	}
}

fn trim_number(value f64) string {
	text := value.str()
	if text.ends_with('.0') {
		return text[..text.len - 2]
	}
	return text
}
