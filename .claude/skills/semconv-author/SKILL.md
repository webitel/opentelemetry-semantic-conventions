---
name: semconv-author
description: Author Webitel's OpenTelemetry semantic conventions in this repository — add, rename, restyle or review metrics, attributes, spans and events in the Weaver model under model/, following what the repo already defines and the OpenTelemetry semantic-convention rules (naming, instrument and unit choice, status metrics, upstream-first reuse, brief/note style), then validate and regenerate the docs. Use this whenever someone wants to add or change telemetry in the conventions, asks what a metric or attribute should be called, which instrument or unit to use, how to model a state, whether an upstream convention already covers something, how to word a brief or note, or wants a service's emitted metric names checked against the registry — even if they never say "semantic conventions" or "Weaver".
---

# Authoring Webitel semantic conventions

This repository is a Weaver registry that extends the upstream OpenTelemetry
semantic conventions. Whatever is defined here becomes a public contract: services
emit it, dashboards and alerts query it, and the generated `docs/` are what people
read. So the job is less "write some YAML" and more "pick names and semantics that
will still make sense to a stranger in a year", and the OpenTelemetry rules exist
precisely to make that happen.

## Before anything: read what is already here

Every decision below depends on the existing registry, so read it first — all of
`model/` (it is small), `model/manifest.yaml` (which upstream version is pinned),
`model/imports.yaml`, `CONTRIBUTING.md` and `RELEASING.md`.

Look for:
- **Vocabulary that already exists.** If an attribute already describes the thing
  (a state, a name, a provider), reference it instead of inventing a sibling. If a
  word already carries a meaning in the domain (`pending`, `failed`, `leader`),
  keep using it with that meaning. One word, one meaning across the registry.
- **The namespace and area** the new convention belongs to (`webitel.<area>.*`),
  and neighbours whose layout and wording to match.
- **How upstream is consumed** — the pinned core registry version, any other
  registry dependencies, and what is imported.

Treat `CONTRIBUTING.md` as the source for repository mechanics (file layout,
make targets, release flow). Its YAML snippets are illustrations of syntax; for
naming and wording, the OpenTelemetry rules in `references/` win.

## Workflow

### 1. Check upstream before defining anything

OpenTelemetry's first rule for application developers is to consult existing
conventions. A matching upstream convention is always better than a Webitel one,
and misusing an upstream one (stretching `http.request.method` to mean a business
action) is worse than defining your own.

```bash
.claude/skills/semconv-author/scripts/find-upstream.sh 'queue|dead.?letter'
.claude/skills/semconv-author/scripts/find-upstream.sh --genai 'embedding|rerank'
```

The script searches the core registry at the version pinned in the manifest (or
the GenAI registry with `--genai`; the GenAI conventions moved out of the core
repository). Then:
- an upstream **metric/event/span** that fits is pulled in through
  `model/imports.yaml`, not redefined;
- an upstream **attribute** that fits is used with `ref:` inside a Webitel signal,
  optionally with a tailored `brief`/`note` and its own requirement level;
- if the fitting convention lives in a registry this repo does not depend on yet
  (check `dependencies:` in the manifest), say so and ask before adding the
  dependency — it changes how the whole registry resolves;
- never reference an upstream convention marked deprecated; the local policy rejects it.

Details and Weaver mechanics: `references/upstream-and-lifecycle.md`.

### 2. Name it

Everything defined here lives under `webitel.` (a policy enforces it; this is the
application prefix OpenTelemetry recommends for company conventions). The name
describes *what is measured*, never *who emits it* — the service is already on
every data point as the `service.name` resource attribute, so a service or team
name in a metric name only breaks aggregation.

The rules that come up most (full list with sources in `references/naming.md`):
- dotted namespaces, snake_case inside a segment, lowercase;
- `{object}.{property}`: include the property (`queue.pending`, not `queue`);
- units never in the name, and never `_total` — Prometheus adds both on export;
- counters of discrete things are plural nouns with a `{thing}` unit; up-down
  counters are not pluralized; `.duration` only for histograms of an operation's
  duration;
- "how many right now" is an up-down counter `{object}.count` ("Number of … that
  are currently …"), not `….active` or `active_…`; if the things can be in several
  states, add a required `{object}.state` attribute instead of a metric per state
  (`db.client.connection.count` + `db.client.connection.state`). `.active` only
  mirrors an upstream metric that already has that shape;
- "how many happened" is a counter with a plural noun, or nothing at all when a
  `.duration` histogram of the same operation already exists: its count is the
  number of occurrences.

The segment after `webitel.` also names the Go package that webitel-go-kit
generates for the metrics: `webitel.call_center.*` becomes `callcenterconv`, with
`webitel.call_center` dropped from Go names. An abbreviation in a name (`kb`)
needs an entry in `acronyms` in go-kit's
`infra/otel/semconv/templates/registry/go/weaver.yaml`, or it comes out as `Kb`.

When two names are both defensible, show both with the rule behind each and let
the user pick — naming is where people care most.

### 3. Choose the instrument and unit

Ask two questions: is this a count of events, a distribution, or a reading of
current value? and would summing the readings of all instances be meaningful?
That gives counter / histogram / up-down counter / gauge (see the decision
procedure in `references/instruments-and-units.md`). Units are UCUM: `s` for time,
`By` for bytes, `{thing}` annotations for counts, `1` only for dimensionless ratios.

A metric that says which state something is in (healthy/unhealthy, leader/follower)
follows the upstream status-metric design: an up-down counter named `….status`,
unit `"1"`, one timeseries per value of a complete `….state` enum, 1 for the
current state and 0 for the others.

### 4. Define attributes

Registry attributes go in `model/webitel/<area>/registry.yaml`, signals reference
them with `ref:`. Requirement levels belong on the reference, not the definition.
Keep metric attributes low-cardinality (no IDs, raw URLs, free-form messages).
For failures use upstream `error.type` on the operation's own metric rather than a
separate failure metric, and document the values you report. Details:
`references/attributes.md`.

### 5. Write `brief` and `note`

This is where drafts usually go wrong, so read `references/writing.md` before
writing any text. The short version, from how upstream writes its own YAML:
- metric `brief`: a noun phrase ending with a period — "Duration of …",
  "Number of …", "The number of … that are currently in the state described by the
  `….state` attribute.";
- attribute `brief`: "The name of …", "The state of …";
- enum member `brief`: a short statement of that state;
- `note`: only what an instrumentation must know to emit the value correctly —
  normative MUST / SHOULD / MUST NOT rules, exact semantics, invariants.

Leave out rationale ("a gauge because…", "so that…"), history, comparisons with or
links to other metrics, and names of people, teams or services. A reader of the
generated docs should learn what the value is and how to produce it, nothing else.

### 6. Renames and removals

First find out whether the convention was ever released:
`git tag --contains $(git log --format=%h -S '<old name>' -- model | tail -n1)`.
Any tag in the output means it was released.

- **Released: always deprecate, never rename in place.** Keep the old group, add
  `deprecated: {reason: renamed, renamed_to: <new name>}` and the brief
  "Deprecated, use `<new name>` instead.", and add the new definition next to it
  (`RELEASING.md`). The release then records the rename in `schemas/`, so
  collectors can translate old telemetry. Whether anything emits the old name yet
  does not change this: a published schema version is a contract, and editing it
  in place leaves no conversion.
- **Added after the last tag: rename in place.** No release carries the old
  name, so there is nothing to deprecate.
- Weaver reserves `renamed` for trivial renames. If the unit, instrument or value
  format also changes, mark the old convention `obsoleted` with a note instead of
  `renamed`.
- Never delete a released convention. Deprecate it.

Then run `make schema-changes`. After a released rename it must list
`<old>: <new>`. Empty output means the deprecation is missing. See
`references/upstream-and-lifecycle.md`.

### 7. Validate and regenerate

```bash
make check-policies     # shared OpenTelemetry policies + policies/check/
make generate-all       # regenerates docs/; CI fails when docs/ is stale
make schema-changes     # after a rename: shows what the next release records
```

`generate-docs` deletes `docs/` before regenerating. The first run clones upstream
and can fail on a network error, leaving `docs/` deleted — restore it with
`git checkout -- docs` and run again. Commit `docs/` together with the model change.

To check the Go names, generate the binding from this checkout into
webitel-go-kit's git-ignored `dev/`:

```bash
make -C ../webitel-go-kit/infra/otel/semconv generate TAG=dev REGISTRY=$PWD/model
```

Deprecated conventions are not generated, so a deprecation removes the Go API
from the next version; say so when you deprecate something.

### 8. When service code is involved

If the user points at a service, compare what it emits with the model:

```bash
.claude/skills/semconv-author/scripts/compare-names.py ../some-service/src --prefix webitel.kb
```

Names only in the code are either missing from the registry or misspelled in the
service; say which you think it is. Remember that the service changes separately —
list what it has to change (names, instrument kind, attributes, per-state series)
rather than assuming the registry change is enough.

## Reporting back

End with a short summary:
- what was added or changed, per convention (name, instrument, unit, attributes);
- which upstream conventions were reused and which were considered and rejected;
- results of `check-policies` and `generate-all` (and `schema-changes` for renames);
- the Go names the change produces, if you generated them;
- decisions left to the user, and what services must change to match.

## Reference files

Read the one that matches the step you are on; each rule line ends with its source.
- `references/naming.md` — naming rules for attributes, metrics, spans, events
- `references/instruments-and-units.md` — instrument choice, units, Prometheus translation, status metrics
- `references/attributes.md` — types, enums, requirement levels, `error.type`, `ref`
- `references/writing.md` — `brief`/`note` style with upstream examples
- `references/upstream-and-lifecycle.md` — upstream-first, imports, dependencies, stability, deprecation, renames
- `references/sources.md` — source URLs and OpenTelemetry blog recommendations
