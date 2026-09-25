# Sources

## Source key

Every rule line ends with `(KEY §section)`.

| Key | Source |
|---|---|
| NAM | https://github.com/open-telemetry/semantic-conventions/blob/v1.43.0/docs/general/naming.md (web: https://opentelemetry.io/docs/specs/semconv/general/naming/) |
| MET | .../v1.43.0/docs/general/metrics.md (web: https://opentelemetry.io/docs/specs/semconv/general/metrics/) |
| ARL | .../v1.43.0/docs/general/attribute-requirement-level.md |
| SRL | .../v1.43.0/docs/general/signal-requirement-level.md |
| GRP | .../v1.43.0/docs/general/semantic-convention-groups.md |
| ERR | .../v1.43.0/docs/general/recording-errors.md |
| EVT | .../v1.43.0/docs/general/events.md |
| HOW | .../v1.43.0/docs/how-to-write-conventions/README.md |
| STM | .../v1.43.0/docs/how-to-write-conventions/status-metrics.md |
| TSS | .../v1.43.0/docs/how-to-write-conventions/t-shaped-signals.md |
| ENT | .../v1.43.0/docs/how-to-write-conventions/resource-and-entities.md |
| KEX | .../v1.43.0/docs/non-normative/naming-known-exceptions.md |
| MOD | .../v1.43.0/model/README.md |
| CON | .../v1.43.0/CONTRIBUTING.md |
| POL:x | .../v1.43.0/policies/x.rego (Rego policies that `make check-policies` runs upstream) |
| Y:path | .../v1.43.0/model/path (upstream YAML, used for the examples) |
| WSX | https://github.com/open-telemetry/weaver/blob/v0.26.1/schemas/semconv-syntax.md |
| WV2 | https://github.com/open-telemetry/weaver/blob/v0.26.1/schemas/semconv-syntax.v2.md (status: Alpha) |
| WOWN | https://github.com/open-telemetry/weaver/blob/v0.26.1/docs/define-your-own-telemetry-schema.md |
| SUP | https://github.com/open-telemetry/opentelemetry-specification/blob/v1.58.0/specification/metrics/supplementary-guidelines.md |
| MAPI | .../opentelemetry-specification/blob/v1.58.0/specification/metrics/api.md |
| TAPI | .../opentelemetry-specification/blob/v1.58.0/specification/trace/api.md |
| PROM | .../opentelemetry-specification/blob/v1.58.0/specification/compatibility/prometheus_and_openmetrics.md |
| B-SPN | https://opentelemetry.io/blog/2025/how-to-name-your-spans/ (2025-08-11) |
| B-ATT | https://opentelemetry.io/blog/2025/how-to-name-your-span-attributes/ (2025-08-27) |
| B-MET | https://opentelemetry.io/blog/2025/how-to-name-your-metrics/ (2025-09-11) |
| B-WVR | https://opentelemetry.io/blog/2025/otel-weaver/ (2025-07-02) |
| B-CPX | https://opentelemetry.io/blog/2025/complex-attribute-types/ (2025-11-05) |
| B-SEV | https://opentelemetry.io/blog/2026/deprecating-span-events/ (2026-03-17) |
| B-CRD | https://opentelemetry.io/blog/2026/cardinality-limits-in-opentelemetry/ (2026-08-06) |

Semconv v1.43.0 links spec v1.58.0, so the spec citations use that tag. MET and NAM are the same files that opentelemetry.io publishes. The "Semantic conventions" concept page (https://opentelemetry.io/docs/concepts/semantic-conventions/) contains only an index and no authoring rules.

## 9. Blog-post recommendations (non-normative)

- **How to Name Your Spans** (2025-08-11, J. Paixão Kröhling), https://opentelemetry.io/blog/2025/how-to-name-your-spans/
  - Name custom business spans `{verb} {object}` (`process payment`, `send invoice`, `calculate shipping`).
  - Keep IDs, users and campaigns out of the name and put them in attributes, because names must be low-cardinality.
  - Name the operation, not the outcome: `validate user_input`, not `validation_failed`. The outcome goes in span status.
  - The pattern mirrors semconv (`{method} {route}`, DB `{operation} {target}`).
- **How to Name Your Span Attributes** (2025-08-27), https://opentelemetry.io/blog/2025/how-to-name-your-span-attributes/
  - Use a semconv attribute when the semantics match. Do not stretch one to fit different semantics.
  - Use `{domain}.{component}.{property}` with dots for hierarchy and underscores within a component.
  - Never use `otel.*`.
  - Reuse the common property suffixes: `.name`, `.id`, `.version`, `.type`, `.address`, `.port`, `.size`, `.count`, `.duration`.
  - Its "domain first, never company first" advice conflicts with NAM (see §1.3). Prefixes are "rare exception" cases.
- **How to Name Your Metrics** (2025-09-11), https://opentelemetry.io/blog/2025/how-to-name-your-metrics/
  - Do not put the service name in metric names; use `service.name`. Queries then aggregate across services.
  - Keep units out of names (use UCUM unit metadata, prefer `By` over `MiBy`).
  - Avoid version, instance, environment or tech-stack names, and business-domain prefixes on infrastructure metrics (`ecommerce_cpu_usage`).
  - Follow semconv names so custom metrics line up with auto-instrumentation.
  - **Caveat:** several illustrative examples contradict MET or are not upstream definitions:
    - `auth.duration` with unit `ms` (MET: seconds SHOULD be used).
    - `transaction.count` with unit `1` (MET: counts use `{annotation}` without the `1`).
    - `http.server.request.rate` and `error.rate` (not metrics in the v1.43.0 HTTP model).
- **Observability by Design: OTel Weaver** (2025-07-02, L. Quérel, J. Blythe, J. Suereth, L. Molkova), https://opentelemetry.io/blog/2025/otel-weaver/
  - "treat telemetry like a public API".
  - Use `weaver registry check`, `diff --baseline-registry`, `live-check`, `emit` and `generate` in CI.
  - Custom registries extend OTel via dependency + `imports` + `ref` with local requirement-level overrides.
  - Custom Rego policies can enforce organization rules.
  - Some manifest details are outdated (see §7).
- **Announcing Support for Complex Attribute Types** (2025-11-05), https://opentelemetry.io/blog/2025/complex-attribute-types/
  - "When possible, stick to primitive values."
  - Semconv will avoid complex attributes on metrics. Use them only when flat attributes cannot express the data.
- **Deprecating Span Events API** (2026-03-17, L. Molkova, R. Pająk, T. Stalnaker), https://opentelemetry.io/blog/2026/deprecating-span-events/
  - New events go through the Logs API as log-based events correlated with the span.
  - Semconv moves from span events to log-based events in new major versions.
- **Metric cardinality limits in OpenTelemetry** (2026-08-06), https://opentelemetry.io/blog/2026/cardinality-limits-in-opentelemetry/
  - Default limit is 2000 combinations per stream. On overflow, all measurement attributes are removed from that data point.
  - Keep raw URLs, request IDs, session IDs and unbounded error messages off metrics. Prefer route templates, status codes and bounded error categories.
  - Use resource attributes for entity identity.
