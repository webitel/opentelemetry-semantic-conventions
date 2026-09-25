# Naming — attributes, metrics, spans, events

> Distilled from OpenTelemetry sources on 2026-09-24 (semconv v1.43.0, Weaver v0.26.1, spec v1.58.0).
> `(KEY §section)` at the end of a line points to the source; see `sources.md` for the key.
> **[observed]** = what upstream YAML does, not a stated rule. **[not stated]** = OpenTelemetry does not say this.

## 1. Naming

### 1.1 General rules (attributes, metrics, events)

- The rules cover "attribute names (also known as the "attribute keys"), as well as Metric and Event names". (NAM §General naming considerations)
- "Every name MUST be a valid Unicode sequence." (NAM §General)
- "Names SHOULD be lowercase." (NAM §General)
- Use namespaces delimited by `.`, for example `service.version`. Namespaces can nest (`telemetry.sdk.name`). Use the `*{object}.{property}` pattern. "Avoid using underscore (`*{object}_{property}`) if this object could have other properties." (NAM §General)
- Multi-word components use snake_case, for example `http.response.status_code`. "Use underscore only when using dot (namespacing) does not make sense or changes the semantic meaning of the name. For example, use `rate_limiting` instead of `rate.limiting`." (NAM §General)
- Be precise and include the property name: `file.owner.name` rather than `file.owner`, and `system.network.packet.dropped` rather than `system.network.dropped`. Avoid names that could mean different things in different conventions: `security_rule` rather than `rule`. (NAM §General)
- Use shorter names when clarity does not suffer. For example, `vcs.change.id` is preferred over `vcs.repository.change.id`. (NAM §General)
- "Abbreviations MAY be used when they are widely recognized and commonly used" (examples: IP, DB, CPU, HTTP, URL, AWS, GCP, K8s). Domain-only abbreviations MAY be used when qualified by a namespace (`container.csi.*`). "Abbreviations SHOULD be avoided if they are ambiguous". (NAM §Name abbreviation guidelines)
- "Semantic conventions MUST limit names to printable Basic Latin characters" (U+0021..U+007E). Weaver tooling limits names further: lowercase Latin letters, digits, `_` and `.`. A name starts with a letter, ends with an alphanumeric character, and never contains two consecutive delimiters. (NAM §Recommendations for OpenTelemetry authors)
  - Regex that upstream enforces for attribute names, metric names, event names and enum member ids: `^[a-z][a-z0-9]*([._][a-z0-9]+)*$`. Attributes must also have a namespace: `^[a-z0-9_]+\.([a-z0-9._]+)+$`. (POL:yaml_schema)
- "All names that are part of OpenTelemetry semantic conventions SHOULD be part of a namespace." (NAM §Recommendations for OpenTelemetry authors)
- Kubernetes exception: when a name maps 1:1 to a K8s API object, use its single-word form: `k8s.replicaset.uid`, not `k8s.replica_set.uid`. (KEX)

### 1.2 Name reuse, removal, and the reserved namespace

- "Two attributes, two metrics, or two events MUST NOT share the same name. Different entities (attribute and metric, metric and event) MAY share the same name." (NAM §Name reuse prohibition)
- "Attributes, metrics, and events SHOULD NOT be removed from semantic conventions regardless of their maturity level. When the convention is renamed or no longer recommended, it SHOULD be deprecated." (NAM §Name reuse prohibition)
- "Any additions to the `otel.*` namespace MUST be approved as part of OpenTelemetry specification." (NAM §otel.* namespace)

### 1.3 Application / company names

This section is quoted closely because it decides how to prefix names in a company registry. (NAM §Recommendations for application developers)

- First "consult existing semantic conventions". Invent a new name only when none fits.
- If the name is company-specific and could be used outside the company: "it is recommended to prefix the new name by your company's reverse domain name, e.g. `com.acme.shopname`."
- If the name is application-specific and internal: follow any existing internal process. "Otherwise it is recommended to prefix the attribute name by your application name, provided that the application name is reasonably unique within your organization (e.g. `myuniquemapapp.longitude` is likely fine). Make sure the application name does not clash with an existing semantic convention namespace."
- "It is not recommended to use existing OpenTelemetry semantic convention namespace as a prefix for a new company- or application-specific attribute name. Doing so may result in a name clash in the future".
- If the name applies across the industry, consider proposing it upstream.

> **Conflict to note.** B-ATT (a 2025 blog post, non-normative) says "start with the domain or technology, never your company or application name". It recommends names such as `user.id`, `request.size`, `inventory.count` and `payment.method`, and lists `acme.inventory.count` and `myapp.request.size` as bad. NAM (normative, Stable) recommends a reverse-domain or application prefix and advises against reusing OTel namespaces as a prefix. `user.id` is already an upstream attribute. B-ATT also says "In rare cases, you might need company or application prefixes", for example to avoid conflicts in a distributed system or for proprietary technology. **For a registry, follow NAM.** (NAM §Recommendations for application developers; B-ATT §The golden rule, §The rare exception)

### 1.4 Attributes

- Pluralization: an attribute for a single entity SHOULD be singular (`host.name`, `container.id`). An attribute that can represent multiple entities "SHOULD be pluralized and the value type SHOULD be an array" (`process.command_args`). An attribute that represents a measurement follows the metric pluralization rules. (NAM §Attribute name pluralization guidelines)
- "Attributes that are unlikely to have any usage beyond a specific convention, SHOULD be added under that metric (event, etc) namespace." For example, `system.filesystem.mode` and `system.filesystem.mountpoint` for `system.filesystem.usage`. (NAM §Signal-specific attributes)
- Signals "are expected and encouraged to use applicable attributes from multiple namespaces". For example, `http.server.request.duration` uses `server.port` and `error.type`. (NAM §Signal-specific attributes)
- A system-name attribute follows `{area}.system|provider|protocol.name` (`db.system.name`). A system-specific attribute follows `{system_name}.*.{property}` (`cassandra.consistency.level`, `aws.s3.key`). "The value of the `*.system.name` (or similar) attribute MUST match the root namespace used in the system specific attribute being defined." (NAM §System-specific naming)
- System names SHOULD identify the product unambiguously (`gcp.pubsub`, `oracle.db`; not `pubsub` or `oracle`). Otherwise prefix with the company or cloud provider (`aws.dynamodb`, `azure.cosmosdb`). (NAM §Choosing a system name)
- Common attributes SHOULD be named consistently. (MET §General guidelines)

### 1.5 Metrics

- "Metric namespaces SHOULD NOT be pluralized." (NAM §Pluralization)
- "Metric names SHOULD NOT be pluralized, unless the value being recorded represents discrete instances of a countable quantity. Generally, the name SHOULD be pluralized only if the unit of the metric in question is a non-unit (like `{fault}` or `{operation}`)." Singular: `system.filesystem.utilization`, `http.server.request.duration`, `system.cpu.time`. Plural: `system.paging.faults`, `system.disk.operations`, `system.network.packets`. (NAM §Pluralization)
- "UpDownCounter names SHOULD NOT be pluralized." Use `system.process.count`, not `system.processes`. Use `cicd.pipeline.run.active`, not `cicd.pipeline.active_runs`. (NAM §Do not pluralize UpDownCounter names)
- "UpDownCounters SHOULD NOT use `_total` because then they will look like monotonic sums. Counters SHOULD NOT append `_total` either because then their meaning will be confusing in delta backends." (NAM §Do not use `total`)
- **`.count` suffix [not stated as a rule].** NAM uses `.count` only in the UpDownCounter example `system.process.count`. **[observed]** Upstream uses `.count` for UpDownCounters (`db.client.connection.count`, `system.network.connection.count`, `system.filesystem.lock.count`, `system.cpu.logical.count`). It also uses `.count` on at least one Counter (`system.network.packet.count`). Counters are more often plural nouns (`messaging.client.sent.messages`, `system.network.errors`, `system.paging.faults`, `db.client.connection.timeouts`). (Y:db/metrics.yaml, Y:system/metrics.yaml, Y:messaging/metrics.yaml)
- **"How many right now": `.count`, not `.active` [not stated as a rule].** **[observed]** For the current number of things, upstream uses two patterns. The older one puts "active" in the name (`http.server.active_requests`, `kestrel.active_connections`, `signalr.server.active_connections`, `cicd.pipeline.run.active`). The newer and more common one is an UpDownCounter `{object}.count`, with a required `{object}.state` attribute when the things can be in more than one state (`db.client.connection.count` + `db.client.connection.state`, `cicd.worker.count` + `cicd.worker.state`, `vcs.change.count` + `vcs.change.state`, `jvm.thread.count`, `go.goroutine.count`). **For this registry, use `.count`.** It is also what the repository already uses (`webitel.kb.article.index.count` + `webitel.kb.article.index.state`). A state attribute can be added later without renaming the metric, while `.active` would need a sibling metric for each new state. The instrument carries the "right now" meaning: an UpDownCounter reports the current number and a Counter the number of occurrences. So `.count` needs no `active` qualifier; the brief says "that are currently …". Use `.active` only to mirror an upstream metric that already has that shape. (Y:http/metrics.yaml, Y:kestrel/metrics.yaml, Y:signalr/metrics.yaml, Y:cicd/metrics.yaml, Y:db/metrics.yaml, Y:vcs/metrics.yaml, Y:jvm/metrics.yaml, Y:go/metrics.yaml)
- **Occurrences over time.** The number of things that happened (sessions started, messages dropped) is a Counter named after the thing in the plural (`db.client.connection.timeouts`, `messaging.client.consumed.messages`), not `.count`. If an operation or lifetime already has a `.duration` histogram, its count already gives the number of occurrences, so upstream defines no separate counter. HTTP requests are counted from `http.server.request.duration`, for example. (MET §General guidelines; ERR §Recording errors on metrics; Y:http/metrics.yaml)
- Instrument-naming vocabulary (NAM §Instrument naming, status Development):
  - **limit**: "the constant, known total amount of something should be called `entity.limit`" (`system.memory.limit`).
  - **usage**: "an amount used out of a known total (limit) amount should be called `entity.usage`" (`system.memory.usage` with `state = used | cached | free | ...`). "Where appropriate, the sum of usage over all attribute values SHOULD be equal to the limit." Consumption of an unlimited or unknowable resource is a different thing from usage.
  - **utilization**: "the fraction of usage out of its limit should be called `entity.utilization`". Values are a ratio, typically `[0, 1]`, and can exceed 1 when a soft limit is exceeded.
  - **time**: "passage of time should be called `entity.time`" (`system.cpu.time` with `state`). It need not be wall time. It is a special case of usage.
  - **duration**: "a histogram that measures operation duration should be called `{operation name}.duration`" (`http.server.request.duration`). `time` is "monotonically increasing total time", whereas `duration` captures "elapsed time of discrete operations".
  - **io**: "bidirectional data flow should be called `entity.io` and have attributes for direction" (`system.network.io`).
  - Other names are free-form (`system.paging.faults`). "Units do not need to be specified in the names ... but can be added if there is ambiguity."
- Client/server: network-call metrics "SHOULD include an indication of which side the metric is being recorded from". Use `{area}.{client|server}.{metric_name}` when the side is ambiguous, otherwise `{area}.{metric_name}` (`http.client.request.duration`, `messaging.process.duration`, `kestrel.connection.duration`). (NAM §Client and server metrics)
- A system-specific metric follows `{system_name}.*.{metric_name}` (`azure.cosmosdb.client.operation.request_charge`). The `*.system.name` value "MUST match system specific metric namespace". (NAM §System-specific metrics)
- "Associated metrics SHOULD be nested together in a hierarchy based on their usage." "As a rule of thumb, aggregations over all the attributes of a given metric SHOULD be meaningful" (quoting Prometheus). "Semantic ambiguity SHOULD be avoided. Use prefixed metric names in cases where similar metrics have significantly different implementations", for example `jvm.gc*` rather than `gc.*`. (MET §General guidelines)
- Metric ids: "Metric id must follow 'metric.{metric_name}' pattern". (POL:yaml_schema)
- API limits: an instrument name has at most 255 characters, starts with a letter, and may then contain alphanumerics, `_`, `.`, `-` and `/`. Instrument names are case-insensitive. (MAPI §Instrument name syntax)

### 1.6 Spans

- The span name "SHOULD be the most general string that identifies a (statistically) interesting class of Spans". `get_account` or `get_account/{accountId}` are good. `get_account/42` is too specific and `get` is too general. "Generality SHOULD be prioritized over human-readability." (TAPI §Span)
- Span names must have low cardinality and "usually follow the `{action} {target}` pattern. For example, `send orders_queue`." They should only include information that is also available as span attributes. Static text should not appear in the name except as a fallback (`GET /orders/{id}`, not `HTTP GET /orders/{id}`). Provide fallbacks for missing or high-cardinality parts. Define length limits and truncation when names can get long. (HOW §Naming pattern)
- "All span definitions MUST include a specific span kind ... One span definition can only mention one span kind." (HOW §Kind) Kinds are CLIENT/SERVER (request/response, outgoing/incoming), PRODUCER/CONSUMER (deferred execution) and INTERNAL (the default). "a single Span does not serve more than one purpose". (TAPI §SpanKind)
- Span group id: `span.*.{kind}`, for example `span.http.client`. (POL:yaml_schema)
- When to define a span: the operation is significant and has a duration, for example network calls. Do not define one for point-in-time occurrences (use events), for short in-process operations (serialization), or when an existing span already covers the operation. (HOW §Defining spans)
- A span definition is commonly accompanied by a duration metric and an exception event, for example `http.client.request.duration` and `http.client.request.exception`. (HOW §Defining spans)

### 1.7 Events

- "Semantic conventions MUST document the event name." "An event MUST have an event name that uniquely identifies the event structure." (EVT §Event name)
- "Event names SHOULD follow the Naming guidelines." "Event names MUST NOT include dynamic values." Use a fully qualified, domain-specific name (`http.client.request.exception`). Use a shared name only when one definition applies to all occurrences. (EVT §Event name)
- Event group `id` must be `event.{name}`. `event.name` must not be referenced as an attribute; set it in `name`. (POL:yaml_schema)
- Events MUST set `Timestamp` to the time of occurrence. Semconv "MUST NOT define a value for ObservedTimestamp". Semconv "SHOULD specify a default severity number" and "MUST NOT define a severity text". (EVT §Timestamps, §Severity)
- "Semantic conventions MUST NOT define a value for body except to represent a string display message of the event." (EVT §Body)
- When to define an event: a checkpoint, state change, point-in-time occurrence or outcome that does not need a new trace context. Use a span for operations with a duration, and a span attribute for whole-operation properties, especially sampling-relevant ones. (EVT §When to define events)
- New events should be log-based events. The Span Event API (`Span.AddEvent`, `Span.RecordException`) is being deprecated. (B-SEV)

### 1.8 Entities (resource)

- Entity group: `type: entity`, with `role: identifying|descriptive` on attributes. "Identifying attributes MUST NOT change during the lifespan of the entity." The identity should be the minimal sufficient set, for example `process.pid` + `process.creation.time`. Namespace an entity by its primary identification mechanism (`k8s`). (ENT)
- `entity_associations` on a signal references entities by name. A stable signal cannot associate with an unstable entity. (ENT §Declaring associations)
