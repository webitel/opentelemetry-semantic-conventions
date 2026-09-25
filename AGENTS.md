# AGENTS.md

A Weaver registry of Webitel's OpenTelemetry semantic conventions. It extends
the upstream registry pinned in `model/manifest.yaml`. `model/` is the source of
truth. Everything else is generated from it or describes how to release it.

To add, rename or reword a metric, attribute, span or event, use the
`semconv-author` skill in `.claude/skills/semconv-author/`. It covers naming,
instrument and unit choice, reuse of upstream conventions and the `brief` /
`note` style.

## Commands

Weaver runs from the `otel/weaver` image pinned in the `Makefile`, so Docker is
required. There is no local install.

```sh
make check-policies   # shared OpenTelemetry policies + policies/check/
make generate-all     # regenerate docs/ and check every import resolved
make schema-changes   # what the next release records (renames since the last tag)
```

- CI (`.github/workflows/validate.yml`) runs `check-policies` and fails when
  `docs/` differs from `make generate-all` output. Commit `docs/` together with
  the model change.
- `generate-docs` runs `rm -rf docs` first. Its first run clones upstream and
  can fail on a network error, leaving `docs/` deleted. Restore it with
  `git checkout -- docs` and run again.
- `schema-changes` and `release` also need `curl`, `gh` and python3 with PyYAML.
  Check with `make check-release-tools`.
- To see the Go binding a change produces before it is released, generate it
  from this checkout into webitel-go-kit's git-ignored `dev/`:

  ```sh
  make -C ../webitel-go-kit/infra/otel/semconv generate TAG=dev REGISTRY=$PWD/model
  ```

## Rules that are easy to break

- **`docs/` is generated.** Never edit it by hand.
- **Everything defined here is under `webitel.`**
  (`policies/check/namespace/`). Upstream conventions are reused, not
  redefined:
  - an attribute through `ref:` inside a Webitel signal;
  - a whole metric through `model/imports.yaml`.
- **A misspelled name in `imports.yaml` does not fail `check-policies`.** The
  metric just drops out. `make generate-all` catches it through
  `check-imports`.
- **Never `ref:` an upstream convention that upstream has deprecated.** The
  policy in `policies/check/upstream/` rejects it.
- **Requirement levels go on the `ref:`**, not on the attribute definition.
- **The upstream version is pinned in two places**: the `dependencies:` git
  tag and `schema_url` in `model/manifest.yaml`, and both upstream URLs in
  `.weaver.toml`. Bump them together; `make check-upstream-version` fails when
  they differ. The shared policies and templates are pinned separately, by
  `PACKAGES_REPO_REF` in the `Makefile`.
- **Renames depend on whether the convention was ever released.** Check with
  `git tag --contains $(git log --format=%h -S '<old name>' -- model | tail -n1)`.
  - **Released:** keep the old group with
    `deprecated: {reason: renamed, renamed_to: …}` and add the new one.
    `make schema-changes` must then list the rename.
  - **Added after the last tag:** rename in place.
  - **Never delete a released convention.**
  - Use `renamed` only when semantics, unit and instrument stay the same;
    otherwise use `obsoleted`.
- **List only telemetry a service actually emits.** The reference is meant to
  match the code.
- **The second segment of a name is a Go package.** `webitel.<area>.*` metrics
  go to `<area>conv` in webitel-go-kit, with underscores dropped
  (`webitel.call_center.*` → `callcenterconv`) and `webitel.<area>` dropped
  from Go names. An abbreviation in a name (`kb`) needs an entry in `acronyms`
  in go-kit's `infra/otel/semconv/templates/registry/go/weaver.yaml`, or it
  comes out as `Kb`.

## Releases

- Releases are cut from `main` with `make release BUMP=major|minor|patch` (see
  `RELEASING.md`). It commits, tags, pushes and publishes a GitHub release. Do
  not run it unless asked.
- The version is the last path segment of `schema_url` in
  `model/manifest.yaml`. There is no `VERSION` file.
- The part of that URL before the version is the schema family identifier.
  Telemetry already emitted carries it, so it must never change.
- `schemas/<version>` files are written only by `make release` and served by
  `.github/workflows/pages.yml`. Never edit a published one.
- Pushing a `v*` tag dispatches `generate-semconv.yml` in `webitel-go-kit`
  (`.github/workflows/go-binding.yml`), which opens a PR adding
  `infra/otel/semconv/vX.Y.Z`. Only `webitel.*` names are generated, and
  deprecated conventions are left out: deprecating one removes it from the
  next Go version.

## Layout

```
model/manifest.yaml            registry identity, schema_url, upstream dependency
model/imports.yaml             upstream metrics pulled in whole
model/webitel/<area>/          registry.yaml (attributes), metrics.yaml, spans.yaml, events.yaml
policies/check/                repository-owned Rego policies
internal/scripts/              schema-changes.py, used by make schema-changes / release
schemas/                       published telemetry schema files, one per version
docs/                          generated reference
```

The directory layout is for humans only. Weaver scans `model/` recursively. The
docs page follows the first dotted segment of a name, the Go package the second.

## Style

- YAML: 2-space indent, lines within 80 columns (`.editorconfig`,
  `.vscode/settings.json`).
- Commits follow Conventional Commits with an optional scope, for example
  `feat(kb): …`, `docs: …`, `ci: …`. Release commits are `chore: release vX.Y.Z`.
- Keep a PR to one namespace or area where possible. Put mechanical
  regeneration and substantive convention changes in separate commits.
