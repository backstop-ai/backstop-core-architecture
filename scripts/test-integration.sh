#!/bin/sh
set -eu

root=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)
analyzer=${GO_ARCH_LINT:-go-arch-lint}
config="$root/testdata/integration/architecture.yml"
converter="$root/scripts/go-arch-lint-to-sarif.sh"

if ! command -v "$analyzer" >/dev/null 2>&1; then
  printf '%s\n' "go-arch-lint is required; install github.com/fe3dback/go-arch-lint@v1.16.0" >&2
  exit 1
fi

run_analyzer() {
  project=$1
  set +e
  analyzer_output=$("$analyzer" check --output-type json --max-warnings 10000 --arch-file "$config" --project-path "$project")
  analyzer_status=$?
  set -e
}

run_analyzer "$root/testdata/integration/allowed"
if [ "$analyzer_status" -ne 0 ]; then
  printf '%s\n' "allowed dependency fixture failed go-arch-lint" >&2
  exit 1
fi
allowed_sarif=$(printf '%s' "$analyzer_output" | sh "$converter")
printf '%s' "$allowed_sarif" | jq -e '(.runs[0].results | length) == 0' >/dev/null

run_analyzer "$root/testdata/integration/forbidden"
if [ "$analyzer_status" -ne 1 ]; then
  printf '%s\n' "forbidden dependency fixture returned status $analyzer_status, want 1" >&2
  exit 1
fi
forbidden_sarif=$(printf '%s' "$analyzer_output" | sh "$converter")
printf '%s' "$forbidden_sarif" | jq -e '
  (.runs[0].results | length) == 1 and
  .runs[0].results[0].ruleId == "package-boundaries" and
  .runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "pkg/gate/gate.go" and
  .runs[0].results[0].properties.source_component == "gate" and
  .runs[0].results[0].properties.target_import == "example.com/architecture-fixture/pkg/pack/distribution"
' >/dev/null

run_analyzer "$root/testdata/integration/unclassified"
if [ "$analyzer_status" -ne 1 ]; then
  printf '%s\n' "unclassified source fixture returned status $analyzer_status, want 1" >&2
  exit 1
fi
unclassified_sarif=$(printf '%s' "$analyzer_output" | sh "$converter")
printf '%s' "$unclassified_sarif" | jq -e '
  (.runs[0].results | length) == 1 and
  .runs[0].results[0].ruleId == "unclassified-package" and
  .runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "pkg/rogue/rogue.go"
' >/dev/null

printf '%s\n' "go-arch-lint integration fixtures passed"
