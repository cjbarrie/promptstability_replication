#!/usr/bin/env python3
"""Copy current data and plots into replication_pipeline for a self-contained bundle."""

import argparse
import os
import shutil
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_ROOT = PROJECT_ROOT / "replication_pipeline"
SOURCES = {
    "data": PROJECT_ROOT / "data",
    "plots": PROJECT_ROOT / "plots",
}


def should_copy(src: Path, dest: Path, mode: str) -> bool:
    if not dest.exists():
        return True
    if mode == "overwrite":
        return True
    if mode == "skip-existing":
        return False
    src_stat = src.stat()
    dest_stat = dest.stat()
    if src_stat.st_size != dest_stat.st_size:
        return True
    return src_stat.st_mtime > dest_stat.st_mtime


def copy_tree(src_root: Path, dest_root: Path, mode: str) -> tuple[int, int]:
    copied = 0
    skipped = 0
    for src in src_root.rglob("*"):
        rel = src.relative_to(src_root)
        dest = dest_root / rel

        if "__pycache__" in src.parts or src.name == ".DS_Store":
            continue

        if src.is_dir():
            dest.mkdir(parents=True, exist_ok=True)
            continue

        dest.parent.mkdir(parents=True, exist_ok=True)
        if should_copy(src, dest, mode):
            shutil.copy2(src, dest)
            copied += 1
        else:
            skipped += 1
    return copied, skipped


def write_manifest(results: dict[str, tuple[int, int]], mode: str) -> None:
    manifest_path = BUNDLE_ROOT / "ARTIFACT_BUNDLE_MANIFEST.md"
    lines = [
        "# Replication Artifact Bundle Manifest",
        "",
        f"Bundle mode: `{mode}`",
        "",
        "This bundle mirrors the current repository-level `data/` and `plots/` trees into `replication_pipeline/` so the replication pipeline directory is self-contained.",
        "",
        "## Contents",
        "",
        "- `replication_pipeline/data/`",
        "- `replication_pipeline/plots/`",
        "",
        "## Copy summary",
        "",
        "| tree | files copied | files skipped |",
        "| --- | ---: | ---: |",
    ]
    for tree_name, (copied, skipped) in results.items():
        lines.append(f"| {tree_name} | {copied} | {skipped} |")
    manifest_path.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Bundle current data and plot artifacts into replication_pipeline/.")
    parser.add_argument(
        "--mode",
        choices=["only-changed", "skip-existing", "overwrite"],
        default="only-changed",
        help="How to handle existing bundled files.",
    )
    args = parser.parse_args()

    results = {}
    for tree_name, src_root in SOURCES.items():
        dest_root = BUNDLE_ROOT / tree_name
        print(f"Bundling {src_root} -> {dest_root} ({args.mode})")
        copied, skipped = copy_tree(src_root, dest_root, args.mode)
        results[tree_name] = (copied, skipped)
        print(f"Finished {tree_name}: copied {copied}, skipped {skipped}")

    write_manifest(results, args.mode)
    print(f"Wrote {BUNDLE_ROOT / 'ARTIFACT_BUNDLE_MANIFEST.md'}")


if __name__ == "__main__":
    main()
