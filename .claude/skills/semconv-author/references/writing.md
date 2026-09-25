# Writing `brief` and `note`

> Distilled from OpenTelemetry sources on 2026-09-24 (semconv v1.43.0, Weaver v0.26.1, spec v1.58.0).
> `(KEY §section)` at the end of a line points to the source; see `sources.md` for the key.
> **[observed]** = what upstream YAML does, not a stated rule. **[not stated]** = OpenTelemetry does not say this.

## 6. Writing `brief` and `note`

### 6.1 Stated rules
- `brief` and `note` "provide human-readable description of the convention". (GRP)
- `brief` is "a brief description". `note` is "a more elaborate description". (WSX §Semantic Convention)
- For attributes, "Provide descriptive `brief` and `note` sections to clearly explain what the attribute represents". "always link to concepts defined in RFCs or other standards". Call out PII in `note`. (HOW §Defining attributes)
- Upstream policies:
  - "Attributes must have a brief."
  - "Groups must have a brief" (all types except `attribute_group`).
  - "Non-empty metric brief ... must end with a period (.)." (POL:yaml_schema, POL:metric_brief_format)
- A `deprecated` description "MUST specify why it's deprecated and/or what to use instead." (WSX §Semantic Convention)
- **[not stated]** OpenTelemetry publishes no style guide for wording, length, tense, or what must not appear in brief/note. It also has no period rule for attribute or enum briefs. Upstream is inconsistent there: "The state of a connection in the pool" and "The memory state" have no trailing period.

### 6.2 Observed style: metric `brief` (Y:*/metrics.yaml) [observed]
The brief is a noun phrase naming the measured quantity. It starts with "Duration of", "Number of", "Size of", "The number of", "The maximum number of", "The time ..." or "Total ...". It ends with a period. It rarely restates the unit or instrument.
1. `http.server.request.duration`: "Duration of HTTP server requests."
2. `db.client.operation.duration`: "Duration of database client operations."
3. `messaging.process.duration`: "Duration of processing operation."
4. `http.server.request.body.size`: "Size of HTTP server request bodies."
5. `http.server.active_requests`: "Number of active HTTP server requests."
6. `http.client.open_connections`: "Number of outbound HTTP connections that are currently active or idle on the client."
7. `messaging.client.sent.messages`: "Number of messages producer attempted to send to the broker."
8. `messaging.client.consumed.messages`: "Number of messages that were delivered to the application."
9. `db.client.connection.count`: "The number of connections that are currently in state described by the `state` attribute."
10. `db.client.connection.max`: "The maximum number of open connections allowed."
11. `db.client.connection.timeouts`: "The number of connection timeouts that have occurred trying to obtain a connection from the pool."
12. `db.client.connection.wait_time`: "The time it took to obtain an open connection from the pool."
13. `db.client.connection.use_time`: "The time between borrowing a connection and returning it to the pool."
14. `system.filesystem.limit`: "The total storage capacity of the filesystem."
15. `system.filesystem.utilization`: "Fraction of filesystem bytes used."
16. `system.uptime`: "The time the system has been running."
17. `system.cpu.time`: "Seconds each logical CPU spent on each mode."
18. `system.network.packet.dropped`: "Count of packets that are dropped or discarded even though there was no error."
19. `system.filesystem.usage`: "Reports a filesystem's space usage across different states."
20. `k8s.pod.status.phase`: "Describes number of K8s Pods that are currently in a given phase."

Counter-examples, not to copy: `system.memory.utilization` says "Percentage of memory bytes in use." but its unit is `1` (a fraction). `system.cpu.utilization` puts the calculation method into the brief.

### 6.3 Observed style: metric `note` [observed]
The note holds (a) normative MUST/SHOULD rules for instrumentations, (b) exact measurement semantics and sum invariants, (c) OS/platform data sources, and (d) cardinality or security warnings. It does not repeat the brief.
- "Batch operations SHOULD be recorded as a single operation." (`db.client.operation.duration`)
- "This metric MUST NOT count messages that were created but haven't yet been sent." (`messaging.client.sent.messages`)
- "This metric SHOULD NOT be used to report processing duration - processing duration is reported in `messaging.process.duration` metric." (`messaging.client.operation.duration`)
- "This metric MUST be reported for operations with `messaging.operation.type` that matches `process`." (`messaging.process.duration`)
- "The metric SHOULD be reported once per message delivery. ..." (`messaging.client.consumed.messages`)
- "Instrumentations SHOULD use a gauge with type `double` and measure uptime in seconds as a floating point number with the highest precision available." (`system.uptime`)
- "The sum of all `system.filesystem.usage` values over the different `system.filesystem.state` attributes SHOULD equal the total storage capacity of the filesystem, that is `system.filesystem.limit`." (`system.filesystem.usage`)
- "All possible pod phases will be reported at each time interval to avoid missing metrics. Only the value corresponding to the current phase will be non-zero." (`k8s.pod.status.phase`)
- A definition with a standards link: "The size of the request payload body in bytes. This is the number of bytes transferred excluding headers and is often, but not always, present as the [Content-Length](https://www.rfc-editor.org/rfc/rfc9110.html#field.content-length) header. For requests using transport encoding, this should be the compressed size." (`http.server.request.body.size`)
- Data source: "Measured as: - Linux: the `drop` column in `/proc/net/dev` ... - Windows: `InDiscards`/`OutDiscards` from `GetIfEntry2`". (`system.network.packet.dropped`)
- Warning on an attribute ref: "> [!WARNING] > Since this attribute is based on HTTP headers, opting in to it may allow an attacker > to trigger cardinality limits, degrading the usefulness of the metric." (`server.address` ref in Y:http/metrics.yaml)

### 6.4 Observed style: attribute `brief` [observed] (Y:*/registry.yaml)
The brief is a short definition of the value, usually "The name of ...", "The number of ...", "The size of ... in bytes." or "A boolean that is true if ...". It sometimes carries a MUST (for example `http.route`).
- `http.request.method`: "HTTP request method."
- `http.response.status_code`: "[HTTP response status code](https://tools.ietf.org/html/rfc7231#section-6)."
- `error.type`: "Describes a class of error the operation ended with."
- `db.collection.name`: "The name of a collection (table, container) within the database."
- `db.namespace`: "The name of the database, fully qualified within the server address and port."
- `db.query.summary`: "Low cardinality summary of a database query."
- `db.operation.batch.size`: "The number of database operations included in a batch operation."
- `db.response.status_code`: "Database response status code."
- `messaging.consumer.group.name`: "The name of the consumer group with which a consumer is associated."
- `messaging.message.body.size`: "The size of the message body in bytes."
- `messaging.destination.temporary`: "A boolean that is true if the message destination is temporary and might not exist anymore after messages are processed."
- `messaging.kafka.offset`: "The offset of a record in the corresponding Kafka partition."
- `http.connection.state`: "State of the HTTP connection in the HTTP connection pool."
- `db.client.connection.state`: "The state of a connection in the pool" (no period).
- `http.route`: "The matched route template for the request. This MUST be low-cardinality and include all static path segments, with dynamic path segments represented with placeholders."
- Template type: `http.request.header`: "HTTP request headers, `<key>` being the normalized HTTP Header name (lowercase), the value being the header values."
- `db.system.name`: "The database management system (DBMS) product as identified by the client instrumentation."

### 6.5 Observed style: attribute `note` [observed]
The note holds normative population rules, cardinality constraints, normalization, fallbacks, configuration and security.
- "Instrumentations SHOULD require an explicit configuration of which headers are to be captured." (`http.request.header`)
- "MUST NOT be populated when this is not supported by the HTTP server framework as the route attribute should have low-cardinality and the URI path can NOT substitute it." (`http.route`)
- "It is RECOMMENDED to capture the value as provided by the application without attempting to do any case normalization." (`db.collection.name`, `db.operation.name`)
- "If a custom value is used, it MUST be of low cardinality." (`messaging.operation.type`)
- "Destination name SHOULD uniquely identify a specific queue, topic or other entity within the broker." (`messaging.destination.name`)
- "Instrumentations SHOULD NOT set `messaging.batch.message_count` on spans that operate with a single message." (`messaging.batch.message_count`)
- "This can refer to both the compressed or uncompressed body size. If both sizes are known, the uncompressed body size should be used." (`messaging.message.body.size`)
- The `error.type` note (§5.4) is the reference example of a normative note.

### 6.6 Observed style: enum member `brief` [observed]
Enum member briefs are optional, and many upstream members have none (for example the members of `system.memory.state` and `system.filesystem.state`). When present, they are short.
- `http.request.method` members: "GET method.", "CONNECT method."
- `error.type` `other`: "A fallback error value to be used when the instrumentation doesn't define a custom value."
- `db.system.name` `other_sql`: "Some other SQL database. Fallback only." Vendor members are a link only: "[Amazon DynamoDB](https://aws.amazon.com/pm/dynamodb/)".
- `messaging.operation.type` `process`: "One or more messages are processed by a consumer." `create`: "A message is created. "Create" spans always refer to a single message and are used to provide a unique creation context for messages in batch sending scenarios."
- `k8s.container.status.state`: "The container has terminated.", "The container is running.", "The container is waiting."
- `system.memory.state` `used`: "Actual used virtual memory in bytes."
- `messaging.servicebus.disposition_status`: "Message is completed", "Message is sent to dead letter queue" (no period).

### 6.7 Observed style: group / span / event / deprecated briefs [observed]
- Registry attribute group briefs (with `display_name`):
  - "This document defines semantic convention attributes in the HTTP namespace." (display_name "HTTP Attributes")
  - "This group defines the attributes used to describe telemetry in the context of databases."
  - "This group describes attributes specific to Apache Kafka." (display_name "Kafka Attributes")
  - "This document defines the shared attributes used to report an error."
  - "Describes System Memory attributes".
- Metric attribute groups: "HTTP server attributes", "HTTP client experimental attributes".
- Spans: "This span represents an outbound HTTP request." The span note carries normative lines such as "**Span kind** MUST be `CLIENT`." and links for span name and status. (Y:http/spans.yaml)
- Events: "This event represents an exception that occurred during an HTTP client request, such as network failures, timeouts, or other errors that prevent the request from completing successfully." Note: "This event SHOULD be recorded when an exception occurs during HTTP client operations. Instrumentations SHOULD set the severity to WARN (severity number 13) when recording this event." (Y:http/events.yaml)
- Deprecated items: "Deprecated, use `http.request.method` instead." / "Deprecated, use `url.path` and `url.query` instead." / "Removed, no replacement at this time." (Y:http/deprecated/registry-deprecated.yaml; WV2 §Obsolete)

### 6.8 What not to put there
- Stated: an Opt-In attribute's sensitivity or cost is documented, not hidden. PII MUST be called out in `note` (HOW). Event conventions must not define severity text or a body value other than a display message (EVT). Neither is a rule about brief/note wording.
- **[observed, not a stated rule]**
  - Metric briefs do not name the unit or instrument (unit and instrument are fields).
  - Briefs do not contain normative MUST/SHOULD, except a few such as `http.route`. Normative rules go in `note`.
  - Notes do not repeat the brief.
  - Neither field contains implementation code, the service or team name, or dynamic example values. Examples go in `examples`.
