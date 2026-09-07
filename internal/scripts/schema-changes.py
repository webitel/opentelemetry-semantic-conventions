#!/usr/bin/env python3
"""Assemble the telemetry-schema change block for a release.

Renames come from two sources, because neither sees both halves:

  * conventions this registry defines -- `weaver registry diff` of the model
    against the previous release's tag reports them as `renamed`, derived from
    the `deprecated: {reason: renamed, renamed_to: ...}` declarations.

  * conventions referenced from upstream -- that same diff cannot supply these.
    For a referenced attribute it reports nothing at all, since `registry diff`
    compares only what a registry defines; for an imported metric it reports an
    unrelated removal plus addition, because the rename was declared upstream,
    not here, and pairing those back up would be guesswork.

    Upstream states the mapping itself, in its published telemetry schema, in
    the very format this block is written in -- so it is read rather than
    re-derived. `weaver registry diff` of the two upstream pins yields the same
    answer (verified on 1.38->1.39 and 1.40->1.43), but at the cost of two repo
    clones and a dependency on the shape of weaver's diff JSON, which no spec
    covers.

Only the upstream versions between the two pins apply, and only the names this
registry referenced at the baseline: upstream renames dozens of conventions per
release and almost none reach our telemetry. Claiming a conversion we do not
perform is worse than claiming none.

Emits nothing when nothing needs converting, so the caller can test the output
for content.
"""

import json
import sys
from pathlib import Path

USAGE = (
    "usage: schema-changes.py OWN_DIFF.json UPSTREAM_SCHEMA BASELINE_UPSTREAM_VERSION REFS\n"
    "  UPSTREAM_SCHEMA may be absent when the upstream pin did not move."
)


def die(message):
    sys.exit(f"schema-changes.py: {message}")


def version_key(v):
    try:
        return tuple(int(part) for part in v.split("."))
    except ValueError:
        die(f"unparseable version {v!r}")


def own_renames(diff_path):
    """(attributes, metrics) rename maps from a `weaver registry diff` report."""
    doc = json.loads(Path(diff_path).read_text())
    if "changes" not in doc:
        # Weaver's diff JSON is not a specified format. If a weaver bump
        # reshapes it, say so instead of silently recording no renames.
        die(f"{diff_path} has no `changes` key; weaver's diff format has moved")
    changes = doc["changes"] or {}

    def bucket(name):
        return {
            e["old_name"]: e["new_name"]
            for e in (changes.get(name) or [])
            if e.get("type") == "renamed" and e.get("old_name") and e.get("new_name")
        }

    return bucket("registry_attributes"), bucket("metrics")


def upstream_renames(schema_path, baseline_version):
    """(attributes, metrics) renamed in (baseline_version, head] of a schema file.

    A version's entry lists what changed since the version preceding it, so the
    baseline's own entry describes a transition that predates this release and
    is excluded.
    """
    if not schema_path or not Path(schema_path).is_file():
        return {}, {}
    try:
        import yaml
    except ImportError:
        die("PyYAML is required to read upstream's schema file (pip install pyyaml)")

    doc = yaml.safe_load(Path(schema_path).read_text()) or {}
    head = str(doc.get("schema_url", "")).rsplit("/", 1)[-1]
    if not head:
        die(f"{schema_path} declares no schema_url")
    lo, hi = version_key(baseline_version), version_key(head)
    if lo > hi:
        die(f"baseline upstream version {baseline_version} is newer than {head}")

    attrs, metrics = {}, {}
    for version, entry in (doc.get("versions") or {}).items():
        if not entry or not lo < version_key(str(version)) <= hi:
            continue
        for change in (entry.get("all") or {}).get("changes", []):
            attrs.update(change.get("rename_attributes", {}).get("attribute_map", {}))
        for change in (entry.get("metrics") or {}).get("changes", []):
            metrics.update(change.get("rename_metrics", {}))
    return attrs, metrics


def render(attrs, metrics):
    out = []
    # An attribute rename applies to every signal carrying it, which the
    # telemetry schema expresses with `all` rather than a per-signal section.
    if attrs:
        out += ["all:", "  changes:", "    - rename_attributes:", "        attribute_map:"]
        out += [f"          {old}: {new}" for old, new in sorted(attrs.items())]
    if metrics:
        out += ["metrics:", "  changes:", "    - rename_metrics:"]
        out += [f"        {old}: {new}" for old, new in sorted(metrics.items())]
    return out


def main(argv):
    if len(argv) != 5:
        sys.exit(USAGE)
    own_diff, upstream_schema, baseline_upstream, refs_file = argv[1:5]

    referenced = {
        line.strip()
        for line in Path(refs_file).read_text().splitlines()
        if line.strip()
    }

    attrs, metrics = own_renames(own_diff)
    up_attrs, up_metrics = upstream_renames(upstream_schema, baseline_upstream)
    attrs.update((o, n) for o, n in up_attrs.items() if o in referenced)
    metrics.update((o, n) for o, n in up_metrics.items() if o in referenced)

    out = render(attrs, metrics)
    if out:
        print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv)
