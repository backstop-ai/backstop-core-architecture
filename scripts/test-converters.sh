#!/bin/sh
set -eu

root=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)
converter="$root/scripts/go-arch-lint-to-sarif.sh"

dependency_sarif=$(sh "$converter" < "$root/testdata/captured/dependency-violation.json")
printf '%s' "$dependency_sarif" | jq -e '
  .version == "2.1.0" and
  .["$schema"] == "https://json.schemastore.org/sarif-2.1.0.json" and
  .runs[0].tool.driver.name == "go-arch-lint" and
  (.runs[0].tool.driver.rules | map(.id) == ["package-boundaries", "unclassified-package"]) and
  (.runs[0].results | length) == 1 and
  .runs[0].results[0].ruleId == "package-boundaries" and
  .runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "pkg/gate/gate.go" and
  .runs[0].results[0].locations[0].physicalLocation.region.startLine == 5 and
  .runs[0].results[0].properties.source_component == "gate" and
  .runs[0].results[0].properties.evidence_kind == "direct-project-import" and
  .runs[0].results[0].partialFingerprints["backstop-core-architecture/edge/v1"] == "gate|example.com/architecture-fixture/pkg/pack/distribution"
' >/dev/null

unclassified_sarif=$(sh "$converter" < "$root/testdata/captured/unclassified-source.json")
printf '%s' "$unclassified_sarif" | jq -e '
  (.runs[0].results | length) == 1 and
  .runs[0].results[0].ruleId == "unclassified-package" and
  .runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri == "pkg/rogue/rogue.go" and
  .runs[0].results[0].properties.evidence_kind == "unclassified-production-source" and
  .runs[0].results[0].partialFingerprints["backstop-core-architecture/unclassified/v1"] == "pkg/rogue/rogue.go"
' >/dev/null

clean_sarif=$(sh "$converter" < "$root/testdata/captured/clean.json")
printf '%s' "$clean_sarif" | jq -e '
  .version == "2.1.0" and
  .runs[0].tool.driver.name == "go-arch-lint" and
  (.runs[0].results | length) == 0
' >/dev/null

if printf '{' | sh "$converter" >/dev/null 2>&1; then
  printf '%s\n' "converter accepted malformed analyzer JSON" >&2
  exit 1
fi

if printf '{}' | sh "$converter" >/dev/null 2>&1; then
  printf '%s\n' "converter accepted an unrecognized analyzer payload" >&2
  exit 1
fi

if jq '.Payload.OmittedCount = 1' "$root/testdata/captured/clean.json" | sh "$converter" >/dev/null 2>&1; then
  printf '%s\n' "converter accepted truncated analyzer output" >&2
  exit 1
fi

printf '%s\n' "converter fixtures passed"
