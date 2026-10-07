#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runs=${1:-100}
if (($# > 0)); then shift; fi
[[ $runs =~ ^[0-9]+$ ]] && ((runs > 0)) || {
    echo "Usage: bash regression.sh [number_of_seeds] [plusargs...]" >&2; exit 1;
}
first_seed=${SEED:-1}
[[ $first_seed =~ ^[0-9]+$ ]] || { echo "SEED must be a nonnegative integer" >&2; exit 1; }

# A regression keeps one DUT configuration for every simulation seed.
N=${N:-4}
W=${W:-16}
export N W
echo "Regression: N=$N W=$W, $runs seeds starting at $first_seed"

for ((i = 0; i < runs; i++)); do
    SEED=$((first_seed + i)) bash "$SCRIPT_DIR/run.sh" "$@"
done
echo "Regression finished: N=$N W=$W, $runs seeds"
