#!/usr/bin/env python3
"""Compare the webitel.* names a service emits with the names this registry defines.

usage: compare-names.py <service source path>... [--prefix webitel.kb]

Scans the given files and directories for string literals that look like
`webitel.*` names, reads every metric, attribute, span and event name defined
under model/, and prints what is only in the code and what is only in the model.
Run it from anywhere inside this repository.
"""

import argparse
import pathlib
import re
import subprocess
import sys

NAME = re.compile(r"""["'`](webitel\.[a-z0-9_]+(?:\.[a-z0-9_]+)+)["'`]""")
DEFINED = re.compile(r"^\s*(?:- )?(?:id|metric_name|name):\s*['\"]?(webitel\.[a-z0-9_.]+)")
SOURCE_SUFFIXES = {".go", ".py", ".ts", ".js", ".java", ".kt", ".rs", ".cs", ".rb", ".php"}


def model_names(root: pathlib.Path) -> set[str]:
    names = set()
    for path in (root / "model").rglob("*.yaml"):
        for line in path.read_text().splitlines():
            match = DEFINED.match(line)
            if match:
                names.add(match.group(1).rstrip("."))
    return names


def code_names(paths: list[pathlib.Path]) -> set[str]:
    names = set()
    for base in paths:
        files = [base] if base.is_file() else [p for p in base.rglob("*") if p.suffix in SOURCE_SUFFIXES]
        for path in files:
            if any(part in {".git", "node_modules", "vendor", ".venv"} for part in path.parts):
                continue
            try:
                names.update(NAME.findall(path.read_text(errors="ignore")))
            except OSError:
                continue
    return names


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="+", type=pathlib.Path)
    parser.add_argument("--prefix", default="webitel.", help="only compare names under this prefix")
    args = parser.parse_args()

    root = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    defined = {n for n in model_names(root) if n.startswith(args.prefix)}
    used = {n for n in code_names(args.paths) if n.startswith(args.prefix)}

    only_code = sorted(used - defined)
    only_model = sorted(defined - used)
    print(f"in both: {len(used & defined)}")
    print("only in code (emitted but not defined here):")
    print("\n".join(f"  {n}" for n in only_code) or "  (none)")
    print("only in model (defined but not found in the given code):")
    print("\n".join(f"  {n}" for n in only_model) or "  (none)")

    return 1 if only_code else 0


if __name__ == "__main__":
    sys.exit(main())
