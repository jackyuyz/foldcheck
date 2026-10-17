#!/bin/bash
set -euo pipefail

# Each package has its own SwiftPM build directory. No cleanup/deletion is required.
for manifest in Packages/*/Package.swift; do
  package_directory="${manifest%/Package.swift}"
  swift test --package-path "$package_directory"
done
