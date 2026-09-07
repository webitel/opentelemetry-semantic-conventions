SHELL := /bin/bash

PYTHON ?= python3

WEAVER_VERSION ?= v0.26.1
WEAVER_IMAGE ?= otel/weaver:$(WEAVER_VERSION)

PACKAGES_REPO_URL ?= https://github.com/open-telemetry/opentelemetry-weaver-packages.git
PACKAGES_REPO_REF ?= 587265869c37180940d3bae29d23ca385e6baa00

WEAVER := mkdir -p $(HOME)/.weaver && docker run --rm \
	-u $(shell id -u):$(shell id -g) \
	-v "$(CURDIR):/workspace" \
	-w /workspace \
	--env HOME=/tmp/weaver \
	--mount 'type=bind,source=$(HOME)/.weaver,target=/tmp/weaver/.weaver' \
	$(WEAVER_IMAGE)

POLICIES  := $(PACKAGES_REPO_URL)@$(PACKAGES_REPO_REF)[policies/check]
TEMPLATES := $(PACKAGES_REPO_URL)@$(PACKAGES_REPO_REF)[templates/docs]

SEMCONV_VERSION := $(shell grep -oE 'semantic-conventions\.git@v[0-9]+\.[0-9]+\.[0-9]+' model/manifest.yaml | sed 's/.*@//')

# The dependency's own schema_url, read from a manifest on stdin. The top-level
# schema_url of this registry appears earlier in the file, hence the guard on
# `dependencies:`. Used against both the working manifest and a tagged one.
DEP_SCHEMA_URL = awk '/^dependencies:/{d=1} d && /schema_url:/{print $$3; exit}'

DOCS_BASE_URL := https://github.com/webitel/opentelemetry-semantic-conventions/blob/main/docs

# Release version = last path segment of the top-level schema_url in
# model/manifest.yaml. E.g. `0.1.0` from `https://webitel.com/schemas/0.1.0`.
VERSION := $(shell awk '/^schema_url:/ { n = split($$2, parts, "/"); print parts[n]; exit }' model/manifest.yaml)

# Everything in the schema url before the version. The spec calls this the
# schema family identifier and requires it to stay constant across versions.
SCHEMA_FAMILY := $(shell awk '/^schema_url:/ { sub("/[^/]*$$", "", $$2); print $$2; exit }' model/manifest.yaml)
RESOLVED_SCHEMA_URI := https://github.com/webitel/opentelemetry-semantic-conventions/releases/download/v$(VERSION)/resolved.yaml
PACKAGE_OUTPUT := .build/package

.PHONY: check-policies schema-changes check-version check-upstream-version check-imports check-release-tools generate-docs generate-all package-dev release clean help

help:
	@echo "check-policies  validate the model against shared and local policies"
	@echo "check-version   the schema url parses, and README.md quotes it"
	@echo "check-upstream-version  .weaver.toml and model/manifest.yaml agree"
	@echo "check-imports   every imports.metrics entry actually resolved"
	@echo "generate-docs   regenerate docs/ from model/"
	@echo "generate-all    every regeneration this repo owns (what CI checks)"
	@echo "check-release-tools  the tools schema-changes and release need are present"
	@echo "schema-changes  print the rename block since the last released tag"
	@echo "package-dev     build the publication artifact for a release"
	@echo "release         BUMP=major|minor|patch  bump, tag and publish"
	@echo "clean           remove generated docs and .build/"

check-release-tools:
	@missing=""; \
	command -v curl >/dev/null || missing="$$missing\n  curl -- fetches the upstream schema named in model/manifest.yaml"; \
	if command -v $(PYTHON) >/dev/null; then \
	  $(PYTHON) -c 'import yaml' 2>/dev/null \
	    || missing="$$missing\n  PyYAML -- reads the upstream schema ($(PYTHON) -m pip install pyyaml)"; \
	else \
	  missing="$$missing\n  $(PYTHON) -- runs internal/scripts/schema-changes.py (override with PYTHON=)"; \
	fi; \
	command -v gh >/dev/null || missing="$$missing\n  gh -- creates the GitHub release"; \
	if [ -n "$$missing" ]; then \
		printf 'missing release tooling:%b\n' "$$missing" >&2; \
		exit 1; \
	fi
	@echo "release tooling present"

# Validate the model against the shared policies from opentelemetry-weaver-packages
# alongside the ones this repo owns.
check-policies:
	$(WEAVER) registry check \
		-r ./model \
		--v2 \
		--policy '$(POLICIES)' \
		--policy policies/check

# The upstream version lives in model/manifest.yaml, but the doc links live in
# .weaver.toml, which weaver reads itself so nothing can interpolate into it.
# Assert the two say the same thing rather than trusting a comment.
check-upstream-version:
	@toml_version="$$(grep -oE 'semantic-conventions/blob/v[0-9]+\.[0-9]+\.[0-9]+' .weaver.toml | head -n1 | sed 's|.*/||')"; \
	schema_version="$$(grep -oE 'schemas/[0-9]+\.[0-9]+\.[0-9]+' .weaver.toml | head -n1 | sed 's|.*/||')"; \
	if [ "$$toml_version" != "$(SEMCONV_VERSION)" ] || [ "v$$schema_version" != "$(SEMCONV_VERSION)" ]; then \
		echo "upstream version mismatch:" >&2; \
		echo "  model/manifest.yaml: $(SEMCONV_VERSION)" >&2; \
		echo "  .weaver.toml:        $$toml_version (schema url $$schema_version)" >&2; \
		exit 1; \
	fi
	@echo "upstream version $(SEMCONV_VERSION) consistent"

# Regenerate the reference under docs/: an index plus one directory per
# namespace, each with a page per signal type.
generate-docs: check-version check-upstream-version
	rm -rf docs
	$(WEAVER) registry generate \
		-r ./model \
		--v2 \
		-t '$(TEMPLATES)' \
		--param registry_base_url=$(DOCS_BASE_URL) \
		markdown \
		./docs

# A name misspelled under `imports.metrics` does not fail `registry check` --
# the metric silently drops out of the resolved registry.
check-imports: generate-docs
	@missing=""; \
	while read -r name; do \
		grep -qrF "\`$$name\`" docs || missing="$$missing $$name"; \
	done < <(awk '/^  metrics:/{f=1;next} f&&/^    - /{print $$2;next} f&&/^[^ #]/{f=0}' model/imports.yaml); \
	if [ -n "$$missing" ]; then \
		echo "these imports.metrics entries in model/imports.yaml did not resolve:" >&2; \
		for n in $$missing; do echo "  $$n" >&2; done; \
		echo "check them against the upstream version pinned in model/manifest.yaml" >&2; \
		exit 1; \
	fi

	@echo "every imports.metrics entry reached the docs"

generate-all: generate-docs check-imports

# The telemetry-schema change block for a release: what a collector must do to
# convert telemetry from BASELINE_VERSION to the version being cut. Empty output
# means nothing needs converting.
#
# Two sources feed it, because neither sees both halves. `weaver registry diff`
# reports renames of what this registry *defines*, derived from the
# `deprecated: {reason: renamed, renamed_to: ...}` declarations -- but it
# compares only `registry.attributes`, so a convention we merely `ref:` from
# upstream is invisible to it, and an imported metric shows up as an unrelated
# removal plus addition. Upstream publishes that mapping itself, so its schema
# file supplies the second half, narrowed by
# internal/scripts/schema-changes.py to the names we referenced at the
# baseline. `registry diff` has no `--param`, so the narrowing could not have
# happened inside a diff template either.
#
# The baseline is the model as it stood at that release's tag, extracted with
# `git archive` -- weaver 0.26.1 ignores the `[subfolder]` suffix on
# --baseline-registry for local paths, so pointing it at a repo root and asking
# for `model` silently yields an empty baseline and reports every convention as
# added.
BASELINE_VERSION ?= $(VERSION)

schema-changes: check-release-tools
	@git rev-parse -q --verify "refs/tags/v$(BASELINE_VERSION)" >/dev/null || { \
		echo "no tag v$(BASELINE_VERSION) to diff against; the previous release must be tagged" >&2; \
		exit 1; \
	}
	@rm -rf $(PACKAGE_OUTPUT)/baseline $(PACKAGE_OUTPUT)/upstream
	@mkdir -p $(PACKAGE_OUTPUT)/baseline $(PACKAGE_OUTPUT)/upstream
	@git archive "v$(BASELINE_VERSION)" model | tar -x -C $(PACKAGE_OUTPUT)/baseline

# Half one: what this registry defines. Weaver derives these from the
# `deprecated: {reason: renamed, renamed_to: ...}` declarations in the model.
	@$(WEAVER) registry diff \
		-r ./model \
		--baseline-registry $(PACKAGE_OUTPUT)/baseline/model \
		--diff-format json \
		--output $(PACKAGE_OUTPUT) >/dev/null

# Every upstream name the baseline referenced: the `ref:`s of upstream
# attributes, plus the imported metrics. An upstream rename of anything outside
# this set changes no telemetry we emit, so it must not reach our schema file.
	@{ grep -rhoE '^[[:space:]]*-[[:space:]]*ref:[[:space:]]*[^[:space:]]+' \
	     $(PACKAGE_OUTPUT)/baseline/model --include='*.yaml' \
	   | sed 's/.*ref:[[:space:]]*//' | grep -v '^webitel\.'; \
	   awk '/^  metrics:/{f=1;next} f&&/^    - /{print $$2;next} f&&/^[^ #]/{f=0}' \
	     $(PACKAGE_OUTPUT)/baseline/model/imports.yaml; \
	 } | sort -u > $(PACKAGE_OUTPUT)/baseline-refs.txt

# Half two: what upstream renamed under us, which only upstream can say. Its
# published schema is fetched rather than diffing the two pinned registries
# with weaver: both give the same answer, but this is a file in the format
# being written here, the spec requires the url to be retrievable, and a
# version's url never changes what it serves.
#
# When the pin has not moved there is nothing upstream could have renamed, so
# no file is fetched and the script is told to skip that half.
	@head_url="$$($(DEP_SCHEMA_URL) model/manifest.yaml)"; \
	base_url="$$(git show "v$(BASELINE_VERSION):model/manifest.yaml" | $(DEP_SCHEMA_URL))"; \
	schema=""; baseline_version=""; \
	if [ -n "$$base_url" ] && [ "$$base_url" != "$$head_url" ]; then \
		schema="$(PACKAGE_OUTPUT)/upstream/schema.yaml"; \
		baseline_version="$${base_url##*/}"; \
		curl -sfL "$$head_url" -o "$$schema" || { \
			echo "cannot fetch the upstream schema at $$head_url" >&2; \
			exit 1; \
		}; \
	fi; \
	$(PYTHON) internal/scripts/schema-changes.py \
		$(PACKAGE_OUTPUT)/diff.json \
		"$$schema" \
		"$$baseline_version" \
		$(PACKAGE_OUTPUT)/baseline-refs.txt > $(PACKAGE_OUTPUT)/changes.yaml
	@cat $(PACKAGE_OUTPUT)/changes.yaml

# Package the registry into a publication artifact. The version comes from
# model/manifest.yaml's schema_url; bump it there to cut a new release.
package-dev:
	@mkdir -p .build
	rm -rf $(PACKAGE_OUTPUT)
	$(WEAVER) registry package \
		-r ./model \
		--v2 \
		--resolved-registry-uri '$(RESOLVED_SCHEMA_URI)' \
		-o ./$(PACKAGE_OUTPUT)
	@echo "Packaged version $(VERSION) -> $(PACKAGE_OUTPUT)"

# Cut a release. The version is the last segment of model/manifest.yaml's
# schema_url and nothing else -- BUMP says how to move it.
#
#   make release BUMP=patch
#
# Everything before the commit is local and reversible; the push and the
# release are not, so it stops and shows the plan first. CONFIRM=yes skips the
# prompt for automation.
#
# schemas/<next> is the previous file with one entry prepended. The change
# block belongs under the version being cut, not under the one it is diffed
# against: the format defines a version's entry as the transformations that
# happened since the version preceding it, so a collector converting 0.1.0 data
# to 0.2.0 applies the 0.2.0 entry.
release: check-release-tools
	@case "$(BUMP)" in \
	  major|minor|patch) ;; \
	  *) echo "BUMP must be major, minor or patch (got '$(BUMP)')" >&2; exit 1 ;; \
	esac

	@test -z "$$(git status --porcelain)" || { echo "working tree is not clean; commit or stash first" >&2; git status --short >&2; exit 1; }
	@branch="$$(git rev-parse --abbrev-ref HEAD)"; \
	default="$$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')"; \
	default="$${default:-main}"; \
	test "$$branch" = "$$default" || { echo "on '$$branch'; releases are cut from '$$default'" >&2; exit 1; }

	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { \
		echo "no tag v$(VERSION); the current release must be tagged before cutting the next" >&2; \
		echo "the schema changes for this release are diffed against it" >&2; \
		exit 1; \
	}
	@git fetch --quiet origin
	@test -z "$$(git rev-list HEAD..@{u} 2>/dev/null)" || { echo "branch is behind its upstream; pull first" >&2; exit 1; }
	@cur="$(VERSION)"; \
	next="$$(awk -v v="$$cur" -v b="$(BUMP)" 'BEGIN { \
	    n=split(v,p,"."); if (n!=3) { print "unparseable version: " v > "/dev/stderr"; exit 1 } \
	    if (b=="major") { print (p[1]+1) ".0.0" } \
	    else if (b=="minor") { print p[1] "." (p[2]+1) ".0" } \
	    else { print p[1] "." p[2] "." (p[3]+1) } }')"; \
	test -n "$$next" || exit 1; \
	git rev-parse -q --verify "refs/tags/v$$next" >/dev/null && { echo "tag v$$next already exists" >&2; exit 1; }; \
	test -z "$$(git ls-remote --tags origin "refs/tags/v$$next")" || { echo "tag v$$next already exists on origin" >&2; exit 1; }; \
	echo "release plan:"; \
	echo "  version   $$cur -> $$next"; \
	echo "  rewrite   model/manifest.yaml, README.md"; \
	echo "  write     schemas/$$next, changes diffed against v$$cur"; \
	echo "  regen     docs/ and re-run every check"; \
	echo "  commit    on $$(git rev-parse --abbrev-ref HEAD), then tag v$$next"; \
	echo "  push      commit and tag to origin"; \
	echo "  publish   gh release create v$$next with resolved.yaml"; \
	if [ "$(CONFIRM)" != "yes" ]; then \
	  printf "proceed? [y/N] "; read -r a; case "$$a" in y|Y) ;; *) echo aborted; exit 1 ;; esac; \
	fi; \
	sed -i.bak "s|/schemas/$$cur|/schemas/$$next|g" model/manifest.yaml README.md && rm -f model/manifest.yaml.bak README.md.bak; \
	$(MAKE) --no-print-directory generate-all check-policies || { git checkout -- model/manifest.yaml README.md; exit 1; }; \
	$(MAKE) --no-print-directory package-dev || { git checkout -- model/manifest.yaml README.md; exit 1; }; \
	$(MAKE) --no-print-directory schema-changes BASELINE_VERSION="$$cur" >/dev/null || { git checkout -- model/manifest.yaml README.md; exit 1; }; \
	{ echo "file_format: 1.1.0"; \
	  echo "schema_url: $(SCHEMA_FAMILY)/$$next"; \
	  echo "versions:"; \
	  echo "  $$next:"; \
	  if grep -q '[^[:space:]]' $(PACKAGE_OUTPUT)/changes.yaml 2>/dev/null; then \
	    sed -e '/^[[:space:]]*$$/d' -e 's/^/    /' $(PACKAGE_OUTPUT)/changes.yaml; \
	  fi; \
	  if [ -f "schemas/$$cur" ]; then \
	    sed -n '/^versions:/,$$p' "schemas/$$cur" | tail -n +2; \
	  fi; \
	} > "schemas/$$next"; \
	git add -A model/manifest.yaml README.md docs schemas \
	  && git commit -qm "chore: release v$$next" \
	  && git tag -a "v$$next" -m "v$$next" \
	  && git push --quiet origin HEAD "refs/tags/v$$next" \
	  && gh release create "v$$next" \
	       --title "v$$next" \
	       --generate-notes \
	       "$(PACKAGE_OUTPUT)/resolved.yaml#resolved.yaml" \
	       "$(PACKAGE_OUTPUT)/manifest.yaml#manifest.yaml" \
	  && echo "released v$$next" \
	  || { echo "release failed after v$$next was tagged; see RELEASING.md to finish or unwind" >&2; exit 1; }

clean:
	rm -rf docs .build
