# Releasing

```sh
make release BUMP=patch    # 0.1.0 -> 0.1.1
make release BUMP=minor    # 0.1.0 -> 0.2.0
make release BUMP=major    # 0.1.0 -> 1.0.0
```

The version is the last path segment of `schema_url` in
[model/manifest.yaml](./model/manifest.yaml) — there is no `VERSION` file. The
tag, the release name and the schema file name all follow from it.

## Before cutting one

- Clean working tree, on the default branch, not behind `origin`.
- The current release must already be tagged; the new schema entry is diffed
  against that tag.
- `make schema-changes` prints what the release will record. No output means
  nothing needs converting, which is normal.

`make release` checks all of this and stops before touching anything, then
prints the plan and waits for `y`. Pass `CONFIRM=yes` to skip the prompt.

## What it does

1. rewrites `schema_url` in `model/manifest.yaml` and `README.md`
2. runs `generate-all`, `check-policies` and `package-dev` — any failure rolls
   those two files back and stops
3. writes `schemas/<version>`
4. commits, tags `v<version>`, pushes both
5. `gh release create` with `resolved.yaml` and `manifest.yaml` attached

Only steps 4 and 5 leave anything behind.

## Renaming something this registry defines

Add the new definition, and mark the old one on the way out:

```yaml
  - id: metric.webitel.health.check.state
    type: metric
    metric_name: webitel.health.check.state
    stability: development
    deprecated:
      reason: renamed
      renamed_to: webitel.health.check.up
```

That is all; the next release records it. Keep the deprecated definition for a
deprecation period — it will not be recorded a second time.

Only attribute and metric renames can be recorded. Deleting a convention
outright leaves anyone still emitting it with no conversion, so deprecate and
rename instead of deleting.

## Renaming something referenced from upstream

When upstream renames an attribute this registry `ref:`s, `make check-policies`
fails and names the replacement:

```
metrics references upstream attribute peer.service, which upstream has renamed
to service.peer.name; switch the ref and record the change
```

Switch the `ref:` — or the `model/imports.yaml` entry, for a metric — to the new
name, in the same commit as the upstream bump. Nothing else to do: the release
reads the mapping from upstream's own published schema and records it.

## Bumping the upstream pin

Two files, and they have to agree:

- `model/manifest.yaml` — the git tag and the `schema_url` in `dependencies`
- `.weaver.toml` — the `upstream_docs` key and the version in its doc link

`make check-upstream-version` fails if they drift apart. Then run
`make generate-all check-policies` and fix what it reports: a bump can change
briefs, stability or examples of every referenced attribute, so read the `docs/`
diff rather than skimming it.

## Schema files

`schemas/<version>` is what the `schema_url` resolves to.
[pages.yml](./.github/workflows/pages.yml) publishes the directory to GitHub
Pages on every push to `main` that touches it.

Pages has to be enabled once, by hand: **Settings → Pages → Source: "GitHub
Actions"** — not a branch. Until it is, the schema url 404s.

Each entry lists what changed since the version below it, so the block under
`0.2.0` converts 0.1.0 telemetry to 0.2.0:

```yaml
file_format: 1.1.0
schema_url: https://webitel.github.io/opentelemetry-semantic-conventions/schemas/0.2.0
versions:
  0.2.0:
    metrics:
      changes:
        - rename_metrics:
            webitel.health.check.state: webitel.health.check.up
  0.1.0:
```

## If it fails after the tag

The tag exists and the release does not. Finish it by hand:

```sh
gh release create v<version> --title v<version> --generate-notes \
  .build/package/resolved.yaml#resolved.yaml \
  .build/package/manifest.yaml#manifest.yaml
```

Or unwind and start over:

```sh
git push --delete origin v<version>
git tag -d v<version>
git reset --hard HEAD~1
```

Unwinding is only safe while nobody has pinned the tag. Once a consumer has, cut
a new patch instead.
