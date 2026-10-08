#!/usr/bin/env bash

set -e

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mode=${mode:-compile} # compile, run o clean

if [ "$mode" = "clean" ]; then
    rm -rf -- "$ROOT/results"
    echo "Resultados borrados"
    exit 0
fi

source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh || exit 1
MODO_PARAMETROS=${MODO_PARAMETROS:-default}
SEED=${SEED:-1}

# Definición de los parámetros del DUT antes de compilarlo
if [ "$MODO_PARAMETROS" = "random" ]; then
    RANDOM=$SEED
    WIDTHS=(16 32 64)
    N=${N:-$((4 + RANDOM % 7))}
    W=${W:-${WIDTHS[RANDOM % ${#WIDTHS[@]}]}}
else
    N=${N:-4}
    W=${W:-16}
fi
build_dir="$ROOT/build/n${N}_w${W}"
SIMV="$build_dir/simv"
mkdir -p "$build_dir"
echo "N=$N W=$W broadcast=FF seed=$SEED mode=$mode"

if [ "$mode" = "compile" ]; then
    cd "$build_dir"
    vcs -Mupdate -full64 -sverilog -debug_access+all -kdb \
        "+incdir+$ROOT" "+incdir+$ROOT/tb" \
        "+define+DRVRS=$N" "+define+PCKG_SZ=$W" \
        -top test_bench "$ROOT/tb/test_bench.sv" \
        -Mdir="$build_dir/csrc" -o "$SIMV" -l compile.log
    exit 0
fi
if [ "$mode" != "run" ]; then
    echo "Usa mode=compile, mode=run o mode=clean"
    exit 1
fi


PLUSARGS_FILE=${PLUSARGS_FILE:-"$ROOT/plusargs.txt"}
args=()
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    line=${line%%#*}
    read -r -a words <<< "$line"
    args+=("${words[@]}")
done < "$PLUSARGS_FILE"
parent_dir=${RESULTS_DIR:-"$ROOT/results/n${N}_w${W}"}
run_dir="$parent_dir/run_$(date +%Y%m%d_%H%M%S)_$$_seed${SEED}"
mkdir -p "$run_dir"
cp "$PLUSARGS_FILE" "$run_dir/plusargs.txt"
cd "$run_dir"
printf 'N=%s\nW=%s\nSEED=%s\n' "$N" "$W" "$SEED" > config.txt
"$SIMV" "+ntb_random_seed=$SEED" "${args[@]}" -l run.log
# Detener la corrida si el checker no reporto PASS -- útil para regresiones
grep -q '\[Checker\] PASS' run.log
perl "$ROOT/report.pl" run.log
echo "Resultados: $run_dir"
echo "verdi -dbdir $build_dir/simv.daidir -ssf $run_dir/waves.fsdb"
