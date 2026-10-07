#!/usr/bin/env bash

# If something fails, stop immediately 
set -euo pipefail

# This script is located ../project_area/sim/scripts/run.sh
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SEED=${SEED:-1}
[[ $SEED =~ ^[0-9]+$ ]] || { echo "SEED must be a nonnegative integer" >&2; exit 1; }

# Choose parameters before compilation. Set N/W explicitly to fix them
RANDOM=$SEED
N=${N:-$((4 + RANDOM % 7))}
widths=(16 32 64)
W=${W:-${widths[RANDOM % 3]}}
[[ $N =~ ^[0-9]+$ ]] && ((N >= 2 && N <= 10)) || {
    echo "N must be between 2 and 10" >&2; exit 1;
}
[[ $W == 16 || $W == 32 || $W == 64 ]] || {
    echo "W must be 16, 32 or 64" >&2; exit 1;
}

args=()
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    read -r -a words <<< "$line"
    args+=("${words[@]}")
done < "$ROOT/sim/plusargs.txt"

build_dir="$ROOT/build/n${N}_w${W}"
run_dir="$ROOT/results/n${N}_w${W}/run_$(date +%Y%m%d_%H%M%S)_$$_seed${SEED}"
mkdir -p "$build_dir" "$run_dir"
cd "$run_dir"
printf 'N=%s\nW=%s\nSEED=%s\n' "$N" "$W" "$SEED" > config.txt
printf ' %q' "$@" "${args[@]}" >> config.txt
printf '\n' >> config.txt

vcs -full64 -sverilog -debug_access+all -kdb \
    "+incdir+$ROOT" "+incdir+$ROOT/tb" \
    "+define+DRVRS=$N" "+define+PCKG_SZ=$W" \
    -top test_bench "$ROOT/tb/test_bench.sv" \
    -Mdir="$build_dir/csrc" -o "$build_dir/simv" -l compile.log

"$build_dir/simv" "+ntb_random_seed=$SEED" "$@" "${args[@]}" -l run.log
echo "Results: $run_dir"
echo "verdi -dbdir $build_dir/simv.daidir -ssf $run_dir/waves.fsdb"
