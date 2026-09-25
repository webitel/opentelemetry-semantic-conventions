# Upstream-first, namespacing, stability, deprecation and renames

> Distilled from OpenTelemetry sources on 2026-09-24 (semconv v1.43.0, Weaver v0.26.1, spec v1.58.0).
> `(KEY §section)` at the end of a line points to the source; see `sources.md` for the key.
> **[observed]** = what upstream YAML does, not a stated rule. **[not stated]** = OpenTelemetry does not say this.

## 7. Upstream-first (import/ref vs define) and namespacing

- Consult existing conventions first. Reuse attributes, and use attributes from other namespaces. (NAM §Recommendations for application developers; HOW §Defining attributes; MET §General guidelines)
- Align instruments "with the `OpenTelemetry Semantic Conventions`, rather than inventing your own semantics." (SUP §Semantic convention)
- Misusing an upstream attribute is worse than creating a custom one: "if an OpenTelemetry semantic convention exists and the semantics match your use case, use it". "Misusing semantic conventions is worse than creating custom attributes". Bad examples: `db.collection.name` for a file name, and `http.request.method` for a business action. (B-ATT §Start with semantic conventions)
- For names you define yourself, prefix them per NAM §Recommendations for application developers (reverse domain or unique application name). Do not use an existing OTel namespace as the prefix, and never use `otel.*`. (NAM)
- Do not put the service name, environment, version, instance or tech stack in metric names. `service.name` and similar resource attributes carry that context. (B-MET §The core anti-pattern, §Common pitfalls) This is compatible with the NAM prefix rule: NAM's prefix identifies the *owner of the convention* (company or app), whereas B-MET forbids putting the *emitting service instance* into the name. **[not stated by OTel]** OpenTelemetry does not reconcile the two texts explicitly.
- T-shaped design: define the broad signals first (RED metrics, high-level spans), then deep system-specific ones. (TSS §Recommendations)
- Prototype in real instrumentation before stabilizing. "Conventions that are not used by instrumentations MUST NOT be declared stable". (HOW §Prototyping, §Stabilizing)

Weaver mechanics for a dependent registry:
- `manifest.yaml`:
  ```yaml
  name: acme
  description: ...
  schema_url: https://acme.com/schemas/0.1.0
  dependencies:
    - schema_url: https://opentelemetry.io/schemas/1.40.0
      registry_path: https://github.com/open-telemetry/semantic-conventions@v1.40.0[model]
  ```
  A dependency's `schema_url` "is required". Weaver allows "a maximum of 10 registry levels without circular dependencies". Local overrides go under `[resolve.schema_url_overrides]` in `.weaver.toml`. (WOWN §manifest.yaml, §Overriding dependency schema URLs)
  - The blog uses a `registry_manifest.yaml` with `semconv_version` and says "only two levels are supported". Both are outdated relative to v0.26.1. WOWN calls `schema_base_url` + `semconv_version` "Legacy". (B-WVR vs WOWN)
- Attributes of a dependency are used with `ref:` in your groups, and `requirement_level` can be redefined locally. Signals (metrics, events, entities, spans) and attribute groups are pulled in with `imports` wildcards. (WOWN §Semantic conventions files; WSX §Syntax `imports`)
  ```yaml
  imports:
    metrics: [db.*]
    entities: [gcp.*]
    events: [session.start]
  ```
  In WV2, `attribute_groups` and `spans` wildcards are also listed. (WV2 §imports definition)
- `extends:` inherits all attributes of another group. (WSX §Semantic Convention)
- Upstream structure policies that are worth adopting in a company registry:
  - Define attributes only in `attribute_group`s whose id starts with `registry.`. Registry groups cannot `ref`, and signal groups cannot define attributes inline. (POL:registry; MOD)
  - Put definitions in `model/{root-namespace}/registry.yaml` and signals in `*{signal}.yaml`. Deprecated items go in `model/{root-namespace}/deprecated/`. (CON §Code structure)
  - B-WVR's example defines attributes inline (`- id: todo.priority`) inside a metric group. Weaver syntax accepts this, but upstream POL:registry rejects it. **[not stated]** Whether a company registry must follow upstream Rego policies is its own choice. Upstream only enforces them on its own registry.
- `annotations.dependency_resolution.exclude: true` hides an item from dependent registries. (WV2 §Dependency Resolution Annotations)

---

## 8. Stability, deprecation and renames (Weaver syntax)

- Stability values: `stable | development | alpha | beta | release_candidate`. (WSX §Syntax; GRP §Group stability) **[observed]** Some upstream k8s items still use the legacy `experimental`, which POL:group_stability ranks the same as `development`.
- `stability` is required on attributes, enum members and every group type except `attribute_group`. "If stability level is not specified, it's assumed to be `development`". (WSX; GRP; POL:registry)
- "New conventions SHOULD be defined with `development` stability level." (HOW §Defining new conventions)
- "Group stability MUST NOT change from `stable` to any other level." "Semantic convention group of any stability level MUST NOT be removed". "When group is renamed or no longer recommended, it SHOULD be deprecated." (GRP §Group stability)
- Stable groups MAY add or remove refs to unstable attributes only at `opt_in`, and "MUST NOT remove references to stable attributes". (GRP §Groups with mixed stability)
- Compatibility checks against the previous release (POL:compatibility):
  - Attributes, metrics, events and enum members cannot be removed.
  - Stable items cannot become unstable.
  - Stable attributes cannot change type.
  - Stable metrics cannot change unit or instrument.
  - Stable metrics cannot add or remove required/recommended attributes.
  - Enum values cannot change.
  - The blog phrases this as "No type or unit changes" and "Enum values may not be changed, once defined" (B-WVR, policy table).

Deprecated syntax:
- v1 grammar: `deprecated ::= renamed renamed_to [note] | obsoleted [note] | uncategorized [note]`. (WSX §Syntax)
- WV2 makes `note` "Required" and adds `unspecified` as a reason. (WV2 §Deprecated structure)
  ```yaml
  # rename (same semantics)
  - id: http.method
    type: string
    brief: 'Deprecated, use `http.request.method` instead.'
    stability: development
    deprecated:
      reason: renamed
      renamed_to: http.request.method
    examples: ["GET", "POST", "HEAD"]
  # obsoleted / split
  - id: http.target
    deprecated:
      reason: obsoleted
      note: Split to `url.path` and `url.query`.
  # anything else
  - id: http.request_content_length
    deprecated:
      reason: uncategorized
      note: Replaced by `http.request.header.content-length`.
  ```
  (Y:http/deprecated/registry-deprecated.yaml)
- Metric rename: the old metric group stays with `deprecated: {reason: renamed, renamed_to: db.client.connection.count}` and brief "Deprecated, use `db.client.connection.count` instead." (Y:db/deprecated/metrics-deprecated.yaml)
- "Renames should be used for trivial renames when the semantics ... remain unchanged. The rename reason MUST NOT be used when anything substantial about the attribute or signal has changed, which includes the unit or instrument type for metrics or the value format for attributes." (WV2 §Rename)
- **In this registry** a convention that is in any release tag is renamed only through a deprecated group plus the new definition. A convention added after the last tag is renamed in place. The release records `deprecated: {reason: renamed}` groups as `rename_metrics` / `rename_attributes` in `schemas/<version>`, and the OpenTelemetry schema processor uses them to translate telemetry that still carries the old name. (RELEASING.md)
- Policy checks on `renamed_to` (POL:deprecation):
  - The target must exist and not be deprecated. This applies to attributes, metrics, events and enum members; for an enum member, the target must be a member of the same enum.
  - The target attribute must have the same type. `string`→enum-of-strings, `int`→enum-of-ints and the reverse are allowed.
- Enum members can be deprecated individually. Deprecated members are excluded from the value-uniqueness check. (WSX §Enumeration; POL:registry)
- `annotations: code_generation: exclude: true` skips an item in codegen, for example a deprecated attribute. (WV2 §Code Generation Annotations)
