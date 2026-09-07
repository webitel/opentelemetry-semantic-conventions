# Contributing

Thanks for helping shape the conventions Webitel services emit. Before you
start, it is worth skimming the OpenTelemetry
[Semantic Convention YAML Language](https://github.com/open-telemetry/weaver/blob/main/schemas/semconv-syntax.md)
— the model files here are written in it. The
[naming guidance](https://opentelemetry.io/docs/specs/semconv/general/naming/#recommendations-for-application-developers)
is the other document worth having open.

## Prerequisites

- **GNU Make**
- **Docker** (or Podman aliased as `docker`).
- Only for `make release` and `make schema-changes` — see
  [RELEASING.md](./RELEASING.md):
  - **`gh`**, to create the GitHub release
  - **`curl`**, to fetch the upstream schema named in `model/manifest.yaml`
  - **python3 with PyYAML**, to read it. Override the interpreter with
    `PYTHON=`.

Nothing is vendored. Weaver fetches the shared check policies and the markdown
templates from
[opentelemetry-weaver-packages](https://github.com/open-telemetry/opentelemetry-weaver-packages)
at the commit pinned in the `Makefile`, and the upstream registry at the tag
pinned in `model/manifest.yaml`. All three are bumped by hand: Dependabot has no
ecosystem that reads them.

## Code structure

```
model/
  manifest.yaml          registry identity and the pinned upstream dependency
  imports.yaml           whole upstream definitions this registry pulls in
  webitel/               the webitel namespace
    health/
      registry.yaml      attributes
      metrics.yaml       metrics
docs/                    generated — do not edit
schemas/                 telemetry schema files, served on Pages
internal/scripts/        release tooling; see schema-changes.py
policies/check/          policies this repo owns, on top of the shared ones
```

The first level under `model/` is the namespace, the second is an area within
it, and inside that the files are named for the signal they define. Upstream
stops at the namespace level, with one `registry.yaml` per namespace holding
every `registry.<area>` group; the extra level here keeps each area's
attributes next to the signals that use them.

**Directory layout is a human convention only.** Weaver scans `model/`
recursively, and neither the generated docs nor the Go binding change if you
move a group between files. What they do follow is the namespace — the first
dotted segment of a name — so everything under `webitel.` lands in one
`docs/webitel/` page and one `webitelconv` Go package regardless of which
directory it was written in.

## Making a change

### 1. Modify the YAML model

See the sections below for what an attribute, a metric or an imported
convention looks like.

Refer to the
[Semantic Convention YAML Language](https://github.com/open-telemetry/weaver/blob/main/schemas/semconv-syntax.md)
to learn about the YAML file syntax.

### 2. Regenerate

After updating the YAML, run:

```sh
make generate-all
```

This regenerates the attribute registry pages under `docs/`,
refreshes the generated tables embedded in the hand-written docs under
and regenerates the status reports.

CI fails if `docs/` does not match the model, so commit the regenerated pages
together with the model change.

### 3. Validate

```sh
make check-policies
```

This runs the shared OpenTelemetry policies — naming conventions, collisions,
backwards compatibility — alongside the ones in `policies/check/`: that every
convention defined here is under `webitel.`, and that nothing here references an
upstream convention upstream has deprecated.

## Adding an attribute

Attributes go in `model/<namespace>/<area>/registry.yaml`. Adding an area means a
new directory with a `registry.yaml` in it.

```yaml
      - id: webitel.queue.name
        type: string
        stability: development
        brief: The name of the queue.
        examples: ["support", "sales"]
```

Every name must start with `webitel.`, and a policy in
[policies/check/](./policies/check) enforces it. The naming guidance recommends
an application prefix and warns against reusing an existing upstream namespace,
so `db.*` or `health.*` on their own are not options here. Conventions
*referenced* from upstream are exempt — the policy tells them apart by where
they were defined, not by their name.

Requirement levels do not belong on the definition — they belong to the metric
or span that references the attribute, because the same attribute can be
required for one signal and optional for another.

## Adding a metric

Metrics go in `model/<namespace>/<area>/metrics.yaml`.

```yaml
  - id: metric.webitel.health.check.duration
    type: metric
    metric_name: webitel.health.check.duration
    stability: development
    brief: Elapsed time of a check's last completed run.
    instrument: gauge
    unit: s
    attributes:
      - ref: webitel.health.check.name
        requirement_level: required
```

`instrument: gauge` is all semconv says, and all it needs to say. Whether a
binding exposes the metric as a synchronous or an observable instrument is the
binding's decision, made at its call sites — nothing about it belongs here, and
it never reaches the generated documentation or the wire.

## Documenting something we emit but do not define

Upstream conventions that Webitel services emit belong here too, so the
reference is complete for whoever configures a collector.

Attributes are referenced from the signal that carries them — a `type: span` or
`type: metric` group — not from a bare `attribute_group`. The generated page
then links each one to the upstream registry instead of copying upstream prose.
A misspelled `ref` fails `make check-policies`.

```yaml
  - id: span.webitel.pgx.client
    type: span
    span_kind: client
    stability: development
    brief: PostgreSQL client span emitted by the pgx instrumentation.
    attributes:
      - ref: db.query.text
      - ref: db.system.name
        note: Always `postgresql`.
```

Whole upstream metrics cannot be referenced that way, so they go in
`model/imports.yaml` under `imports.metrics` by name. A name misspelled *there*
does **not** fail `make check-policies` — the metric silently drops out of the
resolved registry — so check it against the pinned upstream version.

Only list what is actually emitted. The point of generating this reference is
that it cannot drift from the code; adding a convention nothing emits breaks
that on purpose.

## Keep PRs small

A change that touches one namespace and its generated pages reviews in minutes.
One that renames things across several namespaces does not. Split mechanical
regeneration from substantive convention changes where you can — a reviewer who
can see the whole model diff on one screen will catch things a reviewer
scrolling through regenerated tables will not.
