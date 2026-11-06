#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
swiftc -module-cache-path "$build_dir/cache" \
  "$project_dir/Models/ScannedMesh.swift" \
  "$project_dir/Services/OBJExportService.swift" \
  "$project_dir/Services/OBJImportService.swift" \
  "$project_dir/Tests/main.swift" -o "$build_dir/mesh-export-tests"
"$build_dir/mesh-export-tests"
