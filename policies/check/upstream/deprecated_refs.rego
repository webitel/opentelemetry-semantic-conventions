package after_resolution

import rego.v1

# Fails when this registry references an upstream convention that upstream has
# deprecated, and names the replacement.
#
# Nothing else catches it. The shared policies pass, `registry diff` compares
# only what this registry defines and never looks at referenced attributes, and
# the docs template excludes deprecated definitions -- so the attribute quietly
# disappears from our own reference while services keep emitting it.
#
# Referenced attributes reach the resolved registry through the refinement of
# the signal that uses them, not through `registry.attributes`, which is why
# this walks `refinements`.

renamed_note(dep) := sprintf("renamed to %s", [dep.renamed_to]) if dep.renamed_to
renamed_note(dep) := sprintf("deprecated: %s", [dep.reason]) if not dep.renamed_to

deny contains finding if {
	some signal_kind, signals in input.refinements
	some signal in signals
	some attr in signal.attributes
	attr.deprecated

	name := object.get(attr, "key", object.get(attr, "name", "<unknown>"))
	not startswith(name, "webitel.")

	finding := {
		"id": "deprecated_upstream_ref",
		"level": "violation",
		"signal_type": signal_kind,
		"message": sprintf(
			"%s references upstream attribute %s, which upstream has %s; switch the ref and record the change",
			[signal_kind, name, renamed_note(attr.deprecated)],
		),
	}
}
