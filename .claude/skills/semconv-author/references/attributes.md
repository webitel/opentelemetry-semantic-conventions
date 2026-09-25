# Attributes — types, enums, requirement levels, error.type, refs

> Distilled from OpenTelemetry sources on 2026-09-24 (semconv v1.43.0, Weaver v0.26.1, spec v1.58.0).
> `(KEY §section)` at the end of a line points to the source; see `sources.md` for the key.
> **[observed]** = what upstream YAML does, not a stated rule. **[not stated]** = OpenTelemetry does not say this.

## 5. Attributes

### 5.1 When to add and how to define (HOW §Defining attributes)
- "Reuse existing attributes when possible." Authors "are encouraged to use attributes from different namespaces."
- Add a new attribute only if all of these hold: it gives clear user benefit, there is a plan to use it in signal definitions, and there is a plan for how instrumentations will use it.
- Types:
  - Short open or closed value set: use an enum.
  - Timestamps: "record it as a string in ISO 8601 format".
  - Arrays of primitives: use array types. "Avoid recording arrays as a single string." Arrays must be homogeneous (`geo.lat` + `geo.lon`, not one array).
  - Dynamic keys: "Use the template type ... (only the last segment of the name should be dynamic)", for example headers.
  - "Represent complex values as a set of flat attributes whenever possible." Complex attributes can be referenced on events and spans only.
- "Define new attributes with `development` stability." "Provide realistic examples".
- Avoid unbounded values ("strings longer than 1 KB or arrays with more than 1,000 elements"). Put them in the log or event body instead.
- Prefer extensibility, for example a `foo.status_code` attribute instead of a success boolean. For broad attributes, base them on existing standards.
- PII: "explicitly call this out in the `note`" with:
  ```yaml
  note: |
    > [!WARNING]
    >
    > This attribute contains sensitive (PII) information.
  ```
- Weaver types: `string | int | double | boolean | string[] | int[] | double[] | boolean[] | any | template[<primitive or array>]`, or an enum (`type: {members: [...]}`). "`examples` ... are required only for string and string array attributes." (WSX §Attributes, §Type)
- Upstream policy: `any` / `template[any]` types "are only allowed on events and spans". (POL:attribute_types) Complex attributes: "Semantic conventions will assume complex attributes are not indexed and will avoid using them on metrics". "When possible, stick to primitive values." (B-CPX)
- Metric attributes must be low-cardinality. "Metric attributes that may have high cardinality can only be defined with `Opt-In` level." (ARL intro) The SDK's default cardinality limit is 2000 combinations per stream, and on overflow all measurement attributes are lost. Raw URLs, request IDs, session IDs and unbounded error messages "usually should not be metric attributes". (B-CRD)

### 5.2 Enums (HOW §Defining enum attribute members; WSX §Enumeration)
- There are three categories:
  - **Complete enums** document all values (`cpu.mode`). Metrics like `system.cpu.time` depend on having every value.
  - **Open enums** (`error.type`) let conventions and instrumentations add values.
  - **System identifier enums** (`db.system.name`) "don't need to list every possible system". "Only define new system identifiers when you also document how conventions apply to that system."
- A member has `id`, `value` (string, int or boolean), optional `brief` ("defaults to the value of `id`"), optional `note`, required `stability` ("Attributes marked non-stable cannot have stable members"), and optional `deprecated`. (WSX §Enumeration)
- Upstream policies: member ids and values must be unique within an attribute, excluding deprecated members for the value check. Generated constant names must not collide. (POL:registry) Once added, enum members cannot be removed, and a stable member's value cannot change. (POL:compatibility)
- Fallback member idiom: `id: other`, `value: "_OTHER"`, brief "A fallback error value to be used when the instrumentation doesn't define a custom value." (Y:error/registry.yaml). For HTTP methods: "If the HTTP request method is not known to instrumentation, it MUST set the `http.request.method` attribute to `_OTHER`." (Y:http/registry.yaml)

### 5.3 Requirement levels (ARL; WSX)
- Levels: Required, Conditionally Required, Recommended, Opt-In.
  - **Required**: "All instrumentations MUST populate the attribute." Only for attributes that are essential and always available. (ARL §Required; HOW §Attributes)
  - **Conditionally Required**: "MUST clarify the condition under which the attribute is to be populated." If the condition is not met and no instructions are given, the instrumentation "SHOULD use the `Opt-In` requirement level". (ARL §Conditionally Required)
  - **Recommended**: "SHOULD add the attribute by default if it's readily available and can be efficiently populated". (ARL §Recommended)
  - **Opt-In**: "SHOULD populate the attribute if and only if the user configures the instrumentation to do so." This level suits expensive, sensitive or verbose attributes. (ARL §Opt-In; HOW §Attributes)
- "A semantic convention that refers to an attribute from another semantic convention MAY modify the requirement level within its own scope." (ARL intro)
- YAML forms (WSX §Syntax; Y:http/spans.yaml, Y:http/metrics.yaml):
  ```yaml
  requirement_level: required
  requirement_level:
    conditionally_required: If and only if it's different than `http.request.method`.
  requirement_level:
    recommended: If `network.peer.address` is set.   # condition optional; recommended is the default
  requirement_level: opt_in
  ```
- Upstream policy: "Only attribute references can set requirement_level". Definitions in `registry.*` groups must not set it. (POL:registry)
- Signal-level requirement (metrics, spans, events, entities) is only `recommended` or `opt_in`. (SRL; WV2 §Signal requirement levels)
- `sampling_relevant: true` marks attributes that must be known at span start. Specify head-sampling relevance on span attribute references. (WSX §Attributes; HOW §Attributes)

### 5.4 `error.type` (ERR; Y:error/registry.yaml)
- Brief: "Describes a class of error the operation ended with." It is an open enum with the `other`/`_OTHER` member.
- Note (normative):
  - "The `error.type` SHOULD be predictable, and SHOULD have low cardinality."
  - Use the canonical class name for exception types.
  - "Instrumentations SHOULD document the list of errors they report."
  - "If the operation has completed successfully, instrumentations SHOULD NOT set `error.type`."
  - For domain error codes, "Use a domain-specific attribute" and also "Set `error.type` to capture all errors".
- The duration histogram of an operation "SHOULD include the `error.type` attribute". Successful operations "SHOULD NOT include" it. Include it on other applicable metrics, for example `messaging.client.sent.messages`. (ERR §Recording errors on metrics)
- Span and metric for the same operation "SHOULD have the same `error.type` value". (ERR §Recording errors on metrics)
- "Errors that were retried or handled ... SHOULD NOT be recorded on spans or metrics that describe this operation." (ERR §What constitutes an error)
- Conventions with domain status codes "SHOULD specify which status codes should be reported as errors". (ERR §What constitutes an error)
- Span definitions: include `error.type` plus a domain error-code attribute when one exists. Include `server.address`/`server.port` on client spans, `network.*` on network calls, and an operation-name attribute. (HOW §Attributes)
- Events that represent a failure or an outcome: "Include `error.type`". (EVT §Attributes)
- ERR's example uses an app-prefixed metric `acme.resource.create.duration`, an event `acme.resource.create.exception`, and an outcome attribute `acme.resource.create.status`. (ERR §Recording exceptions)

### 5.5 Reusing upstream attributes (`ref`)
- "`ref` MUST have an id of an existing attribute. When it is set, `id`, `type`, `stability`, and `deprecation` MUST NOT be present." The reference inherits `brief`, `note` and `examples`, and any of these present locally override the inherited values. (WSX §Ref)
- "Update the brief and note to tailor the attribute definition to that operation." For example, a ref to `server.address` on `http.server.active_requests` gets the brief "Name of the local HTTP server that received the request." (HOW §Attributes; Y:http/metrics.yaml)
- On events, reuse attributes used on related spans and metrics. Do not copy every span attribute. (EVT §Attributes)
- Stability rule: "A group SHOULD NOT reference attributes with a lower maturity level than the group itself, unless the requirement level of that attribute is `opt_in`." (GRP §Group stability; enforced by POL:group_stability)
