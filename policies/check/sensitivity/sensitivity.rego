package after_resolution

import rego.v1

# `annotations.webitel.sensitivity` marks an attribute whose value must never
# reach telemetry as is. webitel-go-kit generates a map of the marked
# attributes, and its log processor redacts them by name: `pii` becomes a keyed
# pseudonym, `secret` only records whether a value is present.
#
# A value outside the two classes generates nothing and redacts nothing, so it
# is rejected here rather than silently ignored.
#
# Sensitivity belongs to the value, not to the signal that carries it, so it is
# set on the attribute definition. A `ref` inherits it; a `ref` that sets its
# own is rejected, because the generated map is built from definitions only and
# that marking would protect nothing.

sensitivity_classes := {"pii", "secret"}

sensitivity(attr) := object.get(attr, ["annotations", "webitel", "sensitivity"], null)

defined_sensitivity(key) := sensitivity(attr) if {
	some attr in input.registry.attributes
	attr.key == key
}

defined_sensitivity(key) := null if {
	not key in {attr.key | some attr in input.registry.attributes}
}

deny contains finding if {
	some attr in input.registry.attributes
	startswith(attr.provenance.path, "./model/")
	class := sensitivity(attr)
	class != null
	not class in sensitivity_classes

	finding := {
		"id": "sensitivity_class",
		"level": "violation",
		"message": sprintf(
			"attribute %s has sensitivity %v; use one of %v; see %s",
			[attr.key, class, sensitivity_classes, attr.provenance.path],
		),
	}
}

deny contains finding if {
	some signal_kind, signals in input.refinements
	some signal in signals
	some attr in signal.attributes
	class := sensitivity(attr)
	class != null
	class != defined_sensitivity(attr.key)

	finding := {
		"id": "sensitivity_on_ref",
		"level": "violation",
		"signal_type": signal_kind,
		"message": sprintf(
			"%s %s sets sensitivity %v on its ref to %s; set it on the attribute definition instead",
			[signal_kind, signal.id, class, attr.key],
		),
	}
}
