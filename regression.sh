#!/usr/bin/env bash
set -e

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runs=${1:-100}
first_seed=${SEED:-1}
# Usar la configuracion que ya se usó en la compilación para todas las semillas
N=${N:-4}
W=${W:-16}
export N W
RESULTS_DIR="$ROOT/results/n${N}_w${W}/regression_$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p "$RESULTS_DIR"
cp "$ROOT/plusargs.txt" "$RESULTS_DIR/plusargs.txt"
PLUSARGS_FILE="$RESULTS_DIR/plusargs.txt"
export RESULTS_DIR PLUSARGS_FILE

for ((i = 0; i < runs; i++)); do
    echo "Corrida $((i + 1))/$runs"
    mode=run SEED=$((first_seed + i)) bash "$ROOT/comando.sh"
done
# Unir los CSV de las semillas, conservando una columna que identifique la corrida
awk '
FNR==1 { if (NR==1) print; next }
FNR==2 { if (NR==2) print "seed;" $0; next }
{
    seed=FILENAME;
    sub(/.*_seed/, "", seed);
    sub(/\/packets.csv$/, "", seed);
    print seed ";" $0;
}
' "$RESULTS_DIR"/run_*/packets.csv > "$RESULTS_DIR/regression.csv"
echo "Regresion terminada: N=$N W=$W, $runs semillas; $RESULTS_DIR"
