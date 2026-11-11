#!/bin/bash
# Runs a vseq with the SAME coverage configuration as the OpenTitan dvsim,
# so the numbers can be compared fairly. It does not change the Makefile:
# it uses COV=0 (turns off the Makefile coverage) and injects the OpenTitan options.
#
# Usage (from dv/):  cov_ot/run_cov_ot.sh <vseq> <num_seeds>
#   e.g.: cov_ot/run_cov_ot.sh usbdev_smoke_vseq 50
# Output: out_cov_ot/  (report in out_cov_ot/urg_report/dashboard.txt)

set -e
# load VCS first (the Makefile "command -v" check does not work with VCS="vcs <options>")
source /usr/share/Modules/init/bash && module load vcs/W-2024.09-SP2-3
SEQ=${1:-usbdev_smoke_vseq}
N=${2:-50}
CFG=$(cd "$(dirname "$0")" && pwd)
OUT=$(pwd)/out_cov_ot
DB=$OUT/simv.vdb

# Compile options (hw/dv/tools/dvsim/vcs.hjson, build mode vcs_cov)
CM_BUILD="-cm line+cond+fsm+tgl+branch+assert \
 -cm_hier $CFG/cover.cfg+$CFG/common_cov_excl.cfg \
 -cm_common_hier -cm_line contassign -cm_tgl mda+structarr+portsonly \
 -cm_cond for -cm_report noinitial -cm_seqnoconst -diag noconst -cm_glitch 0 \
 +warn=noVCM-OPTIGN -cm_dir $DB -cm_fsmresetfilter $CFG/fsm_reset_cov.cfg"

rm -rf "$OUT"; mkdir -p "$OUT"
make compile COV=0 OUT_DIR="$OUT" VCS="vcs $CM_BUILD"
# -cm_seqnoconst/-diag noconst write constfile.txt in the repo root: keep it with the output
mv -f "$(cd .. && pwd)/constfile.txt" "$OUT/" 2>/dev/null || true

rm -f "$OUT/falhas.txt"
for s in $(seq 1 "$N"); do
  make sim COV=0 OUT_DIR="$OUT" TEST_SEQ="$SEQ" SEED="$s" \
    PLUSARGS="-cm line+cond+fsm+tgl+branch+assert -cm_dir $DB -cm_name ${SEQ}_$s" \
    || echo "seed $s FAILED" >> "$OUT/falhas.txt"
done

# Report with the same exclusions (.el) that dvsim uses for usbdev
cd "$OUT" && urg -full64 -lca -dir "$DB" -line nocasedef \
  -elfile "$CFG/usbdev_manual_excl.el" -elfile "$CFG/usbdev_unr_excl.el" \
  -report "$OUT/urg_report" -format both -log "$OUT/urg.log"
grep -A3 'Total Coverage Summary' "$OUT/urg_report/dashboard.txt"
[ -f "$OUT/falhas.txt" ] && cat "$OUT/falhas.txt" || echo ">>> all $N seeds passed"
