#!/bin/bash
# Roda uma vseq com a MESMA configuracao de cobertura do dvsim da OpenTitan,
# para comparar os numeros de forma justa. Nao altera o Makefile:
# usa COV=0 (desliga a cobertura do Makefile) e injeta as opcoes deles.
#
# Uso (de dentro de dv/):  cov_ot/run_cov_ot.sh <vseq> <num_seeds>
#   ex.: cov_ot/run_cov_ot.sh usbdev_smoke_vseq 50
# Saida: out_cov_ot/  (relatorio em out_cov_ot/urg_report/dashboard.txt)

set -e
# carrega o VCS antes (o teste "command -v" do Makefile nao funciona com VCS="vcs <opcoes>")
source /usr/share/Modules/init/bash && module load vcs/W-2024.09-SP2-3
SEQ=${1:-usbdev_smoke_vseq}
N=${2:-50}
CFG=$(cd "$(dirname "$0")" && pwd)
OUT=$(pwd)/out_cov_ot
DB=$OUT/simv.vdb

# Opcoes de compilacao (hw/dv/tools/dvsim/vcs.hjson, build mode vcs_cov)
CM_BUILD="-cm line+cond+fsm+tgl+branch+assert \
 -cm_hier $CFG/cover.cfg+$CFG/common_cov_excl.cfg \
 -cm_common_hier -cm_line contassign -cm_tgl mda+structarr+portsonly \
 -cm_cond for -cm_report noinitial -cm_seqnoconst -diag noconst -cm_glitch 0 \
 +warn=noVCM-OPTIGN -cm_dir $DB -cm_fsmresetfilter $CFG/fsm_reset_cov.cfg"

rm -rf "$OUT"; mkdir -p "$OUT"
make compile COV=0 OUT_DIR="$OUT" VCS="vcs $CM_BUILD"
# -cm_seqnoconst/-diag noconst geram constfile.txt na raiz do repo: guarda junto da saida
mv -f "$(cd .. && pwd)/constfile.txt" "$OUT/" 2>/dev/null || true

rm -f "$OUT/falhas.txt"
for s in $(seq 1 "$N"); do
  make sim COV=0 OUT_DIR="$OUT" TEST_SEQ="$SEQ" SEED="$s" \
    PLUSARGS="-cm line+cond+fsm+tgl+branch+assert -cm_dir $DB -cm_name ${SEQ}_$s" \
    || echo "seed $s FALHOU" >> "$OUT/falhas.txt"
done

# Relatorio com as mesmas exclusoes (.el) que o dvsim usa para o usbdev
cd "$OUT" && urg -full64 -lca -dir "$DB" -line nocasedef \
  -elfile "$CFG/usbdev_manual_excl.el" -elfile "$CFG/usbdev_unr_excl.el" \
  -report "$OUT/urg_report" -format both -log "$OUT/urg.log"
grep -A3 'Total Coverage Summary' "$OUT/urg_report/dashboard.txt"
[ -f "$OUT/falhas.txt" ] && cat "$OUT/falhas.txt" || echo ">>> todas as $N seeds passaram"
