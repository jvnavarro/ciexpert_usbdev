# OpenTitan-style coverage

Optional setup to measure coverage the same way as the OpenTitan `dvsim`.
Use it when you need to compare numbers with OpenTitan. For daily work, `make` and `make cov` stay the same.

## Usage
From inside `dv/`:
```
cov_ot/run_cov_ot.sh <vseq> <num_seeds>      # e.g.: cov_ot/run_cov_ot.sh usbdev_smoke_vseq 10
```
The script uses seeds 1 to N. The output goes to `dv/out_cov_ot/`, which is not tracked by git:
- report: `out_cov_ot/urg_report/dashboard.txt`;
- failed seeds: `out_cov_ot/falhas.txt` (if the file does not exist, all seeds passed).

## Origin of the files
Copied without changes from [OpenTitan](https://github.com/lowRISC/opentitan), commit `5b83d34b99`, Apache 2.0 license (the copyright notice is kept in each file):

| File | Origin | Purpose |
|---|---|---|
| `cover.cfg` | `hw/dv/tools/vcs/cover.cfg` | where to measure: DUT hierarchy, without already verified primitives |
| `common_cov_excl.cfg` | `hw/dv/tools/vcs/common_cov_excl.cfg` | unused signals, tied off and left out of the count |
| `fsm_reset_cov.cfg` | `hw/dv/tools/vcs/fsm_reset_cov.cfg` | ignores FSM transitions caused by reset |
| `usbdev_unr_excl.el` | `hw/ip/usbdev/dv/cov/usbdev_unr_excl.el` | code proven unreachable by formal analysis (VC Formal UNR) |
| `usbdev_manual_excl.el` | `hw/ip/usbdev/dv/cov/usbdev_manual_excl.el` | unreachable code justified by hand |

`run_cov_ot.sh` was written for this project. Its coverage options (`-cm_tgl portsonly`, `-cm_line contassign`, etc.) follow the `vcs_cov` mode of `hw/dv/tools/dvsim/vcs.hjson`.

## Notes
- The Makefile is not changed: the script runs with `COV=0` and passes the options through the `VCS` and `PLUSARGS` variables.
- The `.el` exclusions are only valid for RTL identical to OpenTitan `5b83d34b99`. If `rtl/` changes, `urg` warns *Module checksum mismatch* and stops applying the affected exclusion.
- 12 of the about 500 exclusions do not apply to this TB (`u_tlul2sram` instances and the `u_wake_events_cdc` checksum).
- The GROUP column (functional coverage) comes from the covergroups in `env/usbdev_env_cov.sv`, which are different from the OpenTitan ones, so it should not be compared directly.
