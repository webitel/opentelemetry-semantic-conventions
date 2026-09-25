# Instruments, units and status metrics

> Distilled from OpenTelemetry sources on 2026-09-24 (semconv v1.43.0, Weaver v0.26.1, spec v1.58.0).
> `(KEY §section)` at the end of a line points to the source; see `sources.md` for the key.
> **[observed]** = what upstream YAML does, not a stated rule. **[not stated]** = OpenTelemetry does not say this.

## 2. Choosing an instrument

Decision procedure (SUP §Instrument selection, verbatim structure):
- "I want to **count** something (by recording a delta value)": if the value is monotonic, use a Counter. If not ("the delta value can be positive, negative or zero"), use an UpDownCounter.
- "I want to **record** or **time** something, and the **statistics** about this thing are likely to be meaningful": use a Histogram.
- "I want to **measure** something (by reporting an absolute value)": if the values are non-additive, use an Asynchronous Gauge. If they are additive and monotonic, use an Asynchronous Counter. If they are additive and not monotonic, use an Asynchronous UpDownCounter.

Additivity (SUP §Additive property):
- Counter, UpDownCounter and their asynchronous forms are additive. Gauge is non-additive. Histogram is mixed: bucket counts and sum are additive, but min and max are not.
- Example: use an UpDownCounter rather than a Gauge for process heap size, because this makes "it explicit that the consumer can add up the numbers across all processes". Server temperature is non-additive, so it is a Gauge. (SUP §Instrument selection, §Additive property)
- Gauge: records "non-additive value(s) (e.g. the background noise level ...)". "If the values are additive (e.g. the process heap size ...), use UpDownCounter." (MAPI §Gauge)
- UpDownCounter examples: "the number of active requests", "the number of items in a queue". "if the value is monotonically increasing, use Counter instead." (MAPI §UpDownCounter)

In semconv YAML (MET §Instrument types; WSX §Metric semantic convention):
- `instrument:` is one of `counter | updowncounter | gauge | histogram`. Conventions "must be written using the names of the synchronous instrument types". "compliant implementations MAY use the asynchronous equivalent instead". The choice between sync and async "is considered to be an implementation detail".
- **[observed]** Upstream sets `annotations: code_generation: metric_value_type: int|double` on every metric (Y:http/metrics.yaml). WV2 describes it as "Specify the exact type for generated code" (WV2 §Code Generation Annotations).

Upstream examples of the mapping (Y:http, db, messaging, system, k8s metrics.yaml):

| Kind of value | Instrument | Examples |
|---|---|---|
| Operation latency | histogram, `s` | `http.server.request.duration`, `db.client.operation.duration`, `db.client.connection.wait_time` |
| Payload size per op | histogram, `By` | `http.server.request.body.size` |
| Per-op count distribution | histogram, `{row}` | `db.client.response.returned_rows` |
| In-flight / current count | updowncounter | `db.client.connection.count` `{connection}` (+ `.state`), older style `http.server.active_requests` `{request}` |
| Configured limit/capacity | updowncounter | `db.client.connection.max`, `system.filesystem.limit`, `k8s.node.cpu.allocatable` |
| Amount used, split by state | updowncounter | `system.memory.usage`, `system.filesystem.usage` |
| Monotonic totals | counter | `messaging.client.sent.messages`, `system.cpu.time`, `system.network.io`, `db.client.connection.timeouts` |
| Ratio | gauge, `1` | `system.cpu.utilization`, `system.filesystem.utilization` |
| Non-additive instantaneous value | gauge | `system.uptime` `s`, `system.cpu.frequency` `Hz`, `k8s.pod.memory.usage` `By` |
| State (0/1 per state) | updowncounter | `k8s.pod.status.phase`, `k8s.container.status.state` (see §4) |

Related rules:
- Consistent UpDownCounter timeseries: "the same attribute values used to record an increment SHOULD be used to record any associated decrement". Attributes that are not available at increment time should not be used on the decrement. (MET §Consistent UpDownCounter timeseries)
- "It's RECOMMENDED to report one metric that includes successes and failures as opposed to reporting two (or more) metrics depending on the operation status." (ERR §Recording errors on metrics)
- "Defining metrics" in HOW is literally "TBD". No further metric-design guide exists at v1.43.0. (HOW §Defining metrics)

---

## 3. Units

- "Units should follow the Unified Code for Units of Measure" (UCUM). (MET §Instrument units)
- Utilization metrics "are dimensionless and SHOULD use the default unit `1`". (MET §Instrument units)
- Curly-brace annotations "need to match the grammatical number of the quantity": `{request}`, not `{requests}`. (MET §Instrument units)
- "Instruments that measure an integer count of something SHOULD only use annotations with curly braces to give additional meaning *without* the leading default unit (`1`). For example, use `{packet}`, `{error}`, `{fault}`". (MET §Instrument units)
- Units other than `1` and annotations "SHOULD be specified using the UCUM case sensitive ("c/s") variant", for example `Cel`. (MET §Instrument units)
- "Instruments SHOULD use non-prefixed units (i.e. `By` instead of `MiBy`) unless there is good technical reason". (MET §Instrument units)
- "When instruments are measuring durations, seconds (i.e. `s`) SHOULD be used." (MET §Instrument units)
- Metrics with unit metadata "SHOULD NOT include the units in the metric name. Units may be included when it provides additional meaning ... Metrics MUST, above all, be understandable and usable." (MET §Units)
- In the API, a unit is a case-sensitive ASCII string of at most 63 characters. (MAPI §Instrument unit)
- Upstream units in use: `s`, `By`, `1`, `Hz`, `{request}`, `{connection}`, `{message}`, `{operation}`, `{packet}`, `{error}`, `{fault}`, `{process}`, `{cpu}`, `{pod}`, `{node}`, `{container}`, `{row}`, `{timeout}`, `{page}`, `{inode}`, `{lock}`. (Y:*/metrics.yaml)

Prometheus translation. Write names and units so that they translate cleanly. (PROM §OTLP Metric points to Prometheus)
- Characters outside `[a-zA-Z_:]([a-zA-Z0-9_:])*` "SHOULD be replaced with the `_` character", so dots become underscores. Consecutive `_` collapse into one. Attribute keys go through the same process into label names. Colliding keys have their values joined with `;`. (§Metric Metadata, §Metric Attributes)
- A UCUM unit "MUST be converted ... to the equivalent unit word" (`s`→`seconds`, `By`→`bytes`, `ms`→`milliseconds`, ...). "Portions of the Unit within brackets (e.g. {packet}) MUST be dropped." Rate units become words (`m/s`→`meters_per_second`). "A suffix to the metric name SHOULD be added unless the metric name already ends with the unit". The unit suffix comes before type suffixes. (§Metric Metadata)
- A monotonic cumulative Sum becomes a Prometheus Counter. "If the metric name for monotonic Sum metric points does not end in a suffix of `_total` a suffix of `_total` SHOULD be added". A non-monotonic sum (UpDownCounter) becomes a Gauge. (§Sums)
- Therefore `http.server.request.duration` (s, histogram) is exported as `http_server_request_duration_seconds_bucket`, and `messaging.client.sent.messages` (`{message}`, counter) as `messaging_client_sent_messages_total`. This is why NAM forbids `_total` and MET discourages units in names. (Derived from PROM + NAM §Do not use `total`.)
- Resource attributes go into `target_info`. `service.namespace`/`service.name` becomes `job` and `service.instance.id` becomes `instance`. (PROM §Resource Attributes)

---

## 4. Status/state metrics (recommended design)

"a "status metric" is a metric used to represent something being in a particular state at a given time from a closed set of distinct possible state values." (STM §Definition)

Template (verbatim, STM §Design):
```yaml
id: metric.example.status
type: metric
metric_name: example.status
stability: development
brief: "The current state."
note: |
  A timeseries is produced for every possible value of `example.state`. The
  value of this metric is 1 for a state if it is currently in said state, and
  is 0 for all other states.
instrument: updowncounter
unit: "1"
attributes:
- ref: example.state
```
- Instrument: use an `UpDownCounter`, not a `Gauge`. "This is a deliberate choice, as it is a reasonable use case to count objects that are in a particular state." Because each value is 0 or 1, "you can do a simple sum aggregation to count instances of particular states." (STM §Instrument)
- The state may also be a descriptive (not identifying) entity attribute, but "it is still recommended to also define a status metric". (STM §Should it be an Entity Attribute?)
- Naming: if the domain already has a word such as k8s `phase` or `status`, "those words should always be chosen". Otherwise "use the word "state" for the attribute and "status" for the metric" ("What **state** is X in?" / "What is the **current status** of X?"). (STM §Naming)
- Attribute: a complete closed enum (see §5.2, complete enums). (HOW §Defining enum attribute members)
- **[observed]** Upstream instances use a count-annotation unit rather than `"1"`:
  - `k8s.pod.status.phase` (updowncounter, `{pod}`). Brief: "Describes number of K8s Pods that are currently in a given phase." Note: "All possible pod phases will be reported at each time interval to avoid missing metrics. Only the value corresponding to the current phase will be non-zero." Attribute `k8s.pod.status.phase` is `required`. (Y:k8s/metrics.yaml)
  - `k8s.container.status.state` (updowncounter, `{container}`). Brief: "Describes the number of K8s containers that are currently in a given state." (Y:k8s/metrics.yaml)
  - `k8s.node.condition.status` (`{node}`), with two required attributes (`k8s.node.condition.type`, `k8s.node.condition.status`). Note: "All possible node condition pairs (type and status) will be reported at each time interval to avoid missing metrics." (Y:k8s/metrics.yaml)
- A related pattern (per-state counts over many objects, not 0/1): `db.client.connection.count` (updowncounter, `{connection}`) with required `db.client.connection.state` (`idle|used`). Brief: "The number of connections that are currently in state described by the `state` attribute." `system.memory.usage` and `system.filesystem.usage` split an amount by a `*.state` enum, and the sum over states SHOULD equal the limit. (Y:db/metrics.yaml, Y:system/metrics.yaml; NAM §Instrument naming)
