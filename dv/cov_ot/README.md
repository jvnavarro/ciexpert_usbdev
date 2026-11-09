# Cobertura no padrão OpenTitan

Configuração opcional para medir cobertura do mesmo jeito que o `dvsim` da OpenTitan.
Use quando precisar comparar números com a OpenTitan. Para o dia a dia, `make` e `make cov` continuam iguais.

## Uso
De dentro de `dv/`:
```
cov_ot/run_cov_ot.sh <vseq> <num_seeds>      # ex.: cov_ot/run_cov_ot.sh usbdev_smoke_vseq 10
```
O script usa as seeds de 1 a N. A saída fica em `dv/out_cov_ot/`, que não vai para o git:
- relatório: `out_cov_ot/urg_report/dashboard.txt`;
- seeds que falharam: `out_cov_ot/falhas.txt` (se o arquivo não existir, todas passaram).

## Origem dos arquivos
Copiados sem alteração da [OpenTitan](https://github.com/lowRISC/opentitan), commit `5b83d34b99`, licença Apache 2.0 (o aviso de copyright está mantido em cada arquivo):

| Arquivo | Origem | Função |
|---|---|---|
| `cover.cfg` | `hw/dv/tools/vcs/cover.cfg` | onde medir: hierarquia do DUT, sem primitivas já verificadas |
| `common_cov_excl.cfg` | `hw/dv/tools/vcs/common_cov_excl.cfg` | sinais não usados, amarrados fora da conta |
| `fsm_reset_cov.cfg` | `hw/dv/tools/vcs/fsm_reset_cov.cfg` | ignora transições de FSM causadas pelo reset |
| `usbdev_unr_excl.el` | `hw/ip/usbdev/dv/cov/usbdev_unr_excl.el` | código provado inalcançável por análise formal (VC Formal UNR) |
| `usbdev_manual_excl.el` | `hw/ip/usbdev/dv/cov/usbdev_manual_excl.el` | código inalcançável justificado à mão |

O `run_cov_ot.sh` foi escrito para este projeto. As opções de cobertura dele (`-cm_tgl portsonly`, `-cm_line contassign`, etc.) seguem o modo `vcs_cov` de `hw/dv/tools/dvsim/vcs.hjson`.

## Observações
- O Makefile não é alterado: o script roda com `COV=0` e passa as opções pelas variáveis `VCS` e `PLUSARGS`.
- As exclusões `.el` só valem para o RTL idêntico ao da OpenTitan `5b83d34b99`. Se o `rtl/` mudar, o `urg` avisa *Module checksum mismatch* e deixa de aplicar a exclusão afetada.
- 12 das cerca de 500 exclusões não se aplicam a este TB (instâncias `u_tlul2sram` e checksum de `u_wake_events_cdc`).
- A coluna GROUP (cobertura funcional) não existe aqui, porque este TB não tem covergroups.
