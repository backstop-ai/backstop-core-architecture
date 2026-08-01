#!/bin/sh
set -eu

echo "backstop-core-architecture: converting go-arch-lint JSON to SARIF" >&2

jq '
def contract_error($message):
  error("go-arch-lint output contract: " + $message);

def relative_path:
  (.FileRelativePath // .Reference.File // .FileAbsolutePath // "")
  | gsub("\\\\"; "/")
  | sub("^\\./"; "")
  | sub("^/"; "");

if .Type != "models.Check" then
  contract_error("top-level Type must be models.Check")
elif (.Payload | type) != "object" then
  contract_error("Payload must be an object")
elif (.Payload.ArchWarningsDeps | type) != "array" then
  contract_error("Payload.ArchWarningsDeps must be an array")
elif (.Payload.ArchWarningsNotMatched | type) != "array" then
  contract_error("Payload.ArchWarningsNotMatched must be an array")
elif ((.Payload.ArchWarningsDeepScan // []) | type) != "array" then
  contract_error("Payload.ArchWarningsDeepScan must be an array when present")
elif ((.Payload.ArchWarningsDeepScan // []) | length) > 0 then
  contract_error("deep-scan findings are not supported by the v0.1 converter")
elif ((.Payload.OmittedCount // 0) | type) != "number" then
  contract_error("Payload.OmittedCount must be a number when present")
elif (.Payload.OmittedCount // 0) > 0 then
  contract_error("analyzer output was truncated; increase --max-warnings")
elif any(.Payload.ArchWarningsDeps[]; (.ComponentName | type) != "string" or (.ResolvedImportName | type) != "string" or (.FileRelativePath | type) != "string") then
  contract_error("dependency warning is missing ComponentName, ResolvedImportName, or FileRelativePath")
elif any(.Payload.ArchWarningsNotMatched[]; (.FileRelativePath | type) != "string") then
  contract_error("unclassified-source warning is missing FileRelativePath")
else {
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  version: "2.1.0",
  runs: [
    {
      tool: {
        driver: {
          name: "go-arch-lint",
          informationUri: "https://github.com/fe3dback/go-arch-lint",
          rules: [
            {
              id: "package-boundaries",
              shortDescription: { text: "Disallowed direct project import" },
              fullDescription: {
                text: "A Backstop Core component directly imports a project component outside its declared dependency allowlist."
              },
              defaultConfiguration: { level: "error" },
              properties: { tags: ["architecture", "dependency"] }
            },
            {
              id: "unclassified-package",
              shortDescription: { text: "Production Go source outside the architecture map" },
              fullDescription: {
                text: "A production Go source file is not assigned to any declared Backstop Core component."
              },
              defaultConfiguration: { level: "error" },
              properties: { tags: ["architecture", "classification"] }
            }
          ]
        }
      },
      results: [
        (.Payload.ArchWarningsDeps[]? | . as $warning | {
          ruleId: "package-boundaries",
          level: "error",
          message: {
            text: ("component " + $warning.ComponentName + " may not import " + $warning.ResolvedImportName)
          },
          locations: [{
            physicalLocation: {
              artifactLocation: { uri: ($warning | relative_path) },
              region: { startLine: ($warning.Reference.Line // 1) }
            }
          }],
          partialFingerprints: {
            "backstop-core-architecture/edge/v1":
              ([$warning.ComponentName, $warning.ResolvedImportName] | join("|"))
          },
          properties: {
            source_component: $warning.ComponentName,
            target_import: $warning.ResolvedImportName,
            evidence_kind: "direct-project-import",
            architecture_policy: "architecture/backstop-core.yml"
          }
        }),
        (.Payload.ArchWarningsNotMatched[]? | . as $warning | {
          ruleId: "unclassified-package",
          level: "error",
          message: { text: ("production Go source is outside the declared architecture: " + ($warning | relative_path)) },
          locations: [{
            physicalLocation: {
              artifactLocation: { uri: ($warning | relative_path) },
              region: { startLine: 1 }
            }
          }],
          partialFingerprints: {
            "backstop-core-architecture/unclassified/v1": ($warning | relative_path)
          },
          properties: {
            evidence_kind: "unclassified-production-source",
            architecture_policy: "architecture/backstop-core.yml"
          }
        })
      ]
    }
  ]
} end
'
