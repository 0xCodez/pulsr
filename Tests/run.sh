#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
# Build each Foundation-only suite separately so feature PRs can merge independently.
for suite in Tests/*/; do
  set --
  while IFS= read -r source; do
    set -- "$@" "$source"
  done < "$suite/sources.txt"
  swiftc -swift-version 5 -parse-as-library "$@" Tests/TestSupport.swift "$suite"*.swift -o "$test_dir/core-checks"
  "$test_dir/core-checks"
done
