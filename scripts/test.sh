#!/bin/sh
set -eu

root=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)

sh "$root/scripts/test-converters.sh"
sh "$root/scripts/test-integration.sh"
