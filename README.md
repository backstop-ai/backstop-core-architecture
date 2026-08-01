# Backstop Core Architecture Pack

`backstop-ai/backstop-core-architecture` enforces the production Go package
topology of [Backstop Core](https://github.com/backstop-ai/backstop-core). It is
consumer-specific policy, not a generic Go architecture standard.

## Scope

Version 0.1 enforces two properties:

- Every production Go source file belongs to a declared component.
- Every direct project import follows the component dependency allowlist in
  `architecture/backstop-core.yml`.

The classification rule is an anti-bypass guard: a new package cannot evade
dependency policy by living outside the component map.

Version 0.1 deliberately does not govern third-party dependencies, test-only
imports, interface injection, transitive runtime behavior, package size, or
semantic responsibility. Backstop's zero-baked language/tool invariant remains
owned by `backstop-ai/backstop-self`.

## Requirements

- Backstop with pack-declared findings-engine support
- `go-arch-lint` v1.16.0 on `PATH`
- `jq` for the pack-owned JSON-to-SARIF converter

Install the analyzer with:

```sh
go install github.com/fe3dback/go-arch-lint@v1.16.0
```

## Installation

Install the published release with:

```sh
backstop pack add backstop-ai/backstop-core-architecture@0.1.1
```

The pack remains external to Backstop Core. The consumer's `backstop.lock` is
the durable record of the installed version and content hash.

## Findings

`package-boundaries` reports a direct project import that is not allowed for the
source component. Its SARIF properties identify `source_component`,
`target_import`, `evidence_kind`, and the architecture policy path.

`unclassified-package` reports production Go source outside the declared
component map. Both findings use repository-relative locations and stable SARIF
partial fingerprints.

The converter fails closed when the analyzer payload shape changes, when
unsupported deep-scan findings appear, or when `go-arch-lint` reports truncated
output. An analyzer upgrade cannot silently normalize an unknown result to green.

## Evolving The Graph

The architecture file is a reviewed ratchet, not a claim that today's graph is
ideal forever. A change that needs a new dependency should update the declaration
only when the dependency direction is intentional and explain why the source
component needs that knowledge.

`cmd/backstop` is the composition root and therefore has broad outgoing access.
That exception does not permit any core component to import the CLI.

## Verification

Run the pack-owned converter and real-analyzer fixtures:

```sh
sh scripts/test.sh
```

When a Backstop development binary is available, also run:

```sh
backstop pack check
backstop pack test
```

The integration fixtures prove clean, forbidden-import, and unclassified-package
polarity using the pinned real analyzer rather than a stub.

## License

MIT
