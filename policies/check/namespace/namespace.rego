package after_resolution

import rego.v1

# Conventions defined in this registry must live under `webitel.`. The
# OpenTelemetry naming guidance recommends an application prefix and warns
# against reusing an existing upstream namespace, so a bare `db.*` or `queue.*`
# here would be a name clash waiting to happen.

defined_here(signal) if startswith(signal.provenance.path, "./model/")

deny contains finding if {
	some attr in input.registry.attributes
	defined_here(attr)
	not startswith(attr.key, "webitel.")

	finding := {
		"id": "namespace_prefix",
		"level": "violation",
		"message": sprintf("attribute %s is defined here but not under `webitel.`; see %s", [attr.key, attr.provenance.path]),
	}
}

deny contains finding if {
	some metric in input.registry.metrics
	defined_here(metric)
	not startswith(metric.name, "webitel.")

	finding := {
		"id": "namespace_prefix",
		"level": "violation",
		"signal_type": "metric",
		"signal_name": metric.name,
		"message": sprintf("metric %s is defined here but not under `webitel.`; see %s", [metric.name, metric.provenance.path]),
	}
}

deny contains finding if {
	some span in input.registry.spans
	defined_here(span)
	not startswith(span.type, "webitel.")

	finding := {
		"id": "namespace_prefix",
		"level": "violation",
		"signal_type": "span",
		"signal_name": span.type,
		"message": sprintf("span %s is defined here but not under `webitel.`; see %s", [span.type, span.provenance.path]),
	}
}
