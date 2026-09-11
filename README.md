# Webitel Semantic Conventions

Semantic Conventions for Webitel services, including spans, metrics,
and events.

This repository extends the
[OpenTelemetry Semantic Conventions](https://github.com/open-telemetry/semantic-conventions)
with Webitel-specific conventions, using
[Weaver](https://github.com/open-telemetry/weaver) to manage dependencies
on the core semantic conventions.

## Schema URL

`https://webitel.github.io/opentelemetry-semantic-conventions/schemas/0.1.1`

The Schema URL allows telemetry producers and consumers to explicitly communicate
which schema version is being used and provides a mechanism for translating
telemetry between different schema versions. Schema files define the transformations
required when semantic conventions evolve, for example when an attribute is
renamed. This allows services and telemetry backends to adopt different
semantic convention versions without requiring a simultaneous migration.

The schema can be used with the OpenTelemetry Collector
[Schema Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/schemaprocessor)
to automatically transform incoming telemetry to a target schema version.
For more information, see the
[OpenTelemetry Telemetry Schemas specification](https://opentelemetry.io/docs/specs/otel/schemas/)
and the
[Schema File Format](https://opentelemetry.io/docs/specs/otel/schemas/file_format_v1.0.0/).

## Read the docs

The human-readable version of the semantic conventions resides in the
[docs](docs/) folder. Read it to wire up a dashboard or
an alert.

Major parts of these Markdown documents are generated
from the YAML definitions located in the [model](model/) folder.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).
