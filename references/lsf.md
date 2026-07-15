# LSF Reference

Directives use `#BSUB`. **Submit with `bsub < script.lsf`** — the `<` is mandatory; `bsub script.lsf` runs the script but silently ignores every `#BSUB` directive, giving the job default (tiny) resources. Monitor with `bjobs`; why pending: `bjobs -p <id>`; details of a finished job: `bhist -l <id>` or `bacct -l <id>`.

## Core directives

| Directive | Meaning | Notes |
|---|---|---|
| `-J name` | Job name | Arrays: `-J "sweep[1-500]%50"` (`%50` throttles) |
| `-q queue` | Queue | Site-specific; list with `bqueues` |
| `-P project` | Charge project | |
| `-W HH:MM` | Walltime | **Hours:minutes — no seconds field** |
| `-n N` | Total task slots | |
| `-R "span[ptile=M]"` | Slots per node | `-n 64` + `ptile=32` → 2 nodes. `span[hosts=1]` forces single node |
| `-R "rusage[mem=SIZE]"` | Memory reservation | Units and per-core vs per-job semantics are **site-configured** (`LSB_UNIT_FOR_LIMITS`); commonly MB **per slot**. Confirm or state your assumption |
| `-M SIZE` | Memory limit (kill threshold) | Distinct from the `rusage` reservation |
| `-gpu "num=4:mode=exclusive_process"` | GPUs (LSF ≥ 10.1) | Older sites use `-R "rusage[ngpus_excl_p=4]"` — site-specific |
| `-o file.%J` / `-e file.%J` | Logs | `%J`=job ID, `%I`=array index. Without `-o`, output arrives by **email** |
| `-B -N` | Mail at start / end | |
| `-x` | Exclusive node | |
| `-Is bash` | Interactive job | For quick testing |

Runtime variables: `$LSB_JOBID`, `$LSB_JOBINDEX` (array), `$LSB_DJOB_NUMPROC`, `$LSB_HOSTS` / `$LSB_DJOB_HOSTFILE` (allocated hosts), `$LS_SUBCWD` (submit dir — LSF usually starts jobs in the submit dir, but `cd` defensively if unsure).

## Launching

Scheduler-integrated MPI: plain `mpirun ./program` picks up the allocation on most sites; IBM installs may use `blaunch` as the underlying launcher. If not integrated: `mpirun -np $LSB_DJOB_NUMPROC -machinefile $LSB_DJOB_HOSTFILE ./program`.

## Examples

### GPU training (1 node, 4 GPUs)

```bash
#!/bin/bash
#BSUB -J train-resnet
#BSUB -q gpu                          # placeholder: check `bqueues`
#BSUB -n 16
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=8000]"           # assumed MB per slot → 128 GB total
#BSUB -gpu "num=4:mode=exclusive_process"
#BSUB -W 12:00
#BSUB -o logs/train.%J.out
#BSUB -e logs/train.%J.err

module purge
module load cuda/12.4                 # placeholder module name
conda activate torch

torchrun --standalone --nproc_per_node=4 train.py --epochs 50
```

### MPI (64 ranks over 2 nodes)

```bash
#BSUB -J cfd-run
#BSUB -n 64
#BSUB -R "span[ptile=32]"
#BSUB -W 24:00
#BSUB -o logs/cfd.%J.out
...
mpirun ./solver input.dat
```

### Array

```bash
#BSUB -J "sweep[1-500]%50"
#BSUB -o logs/sweep.%J.%I.out
...
INPUT=$(sed -n "${LSB_JOBINDEX}p" filelist.txt)
./process "$INPUT"
```

## Gotchas

- The `bsub < script` stdin redirect, again — most common LSF mistake by far.
- `-W 12:00` is 12 **hours**; writing `12:00:00` is a syntax error or misparse.
- Memory: `rusage[mem=]` semantics (MB vs GB, per slot vs per job) genuinely differ between sites — this is worth one clarifying question or an explicit stated assumption.
- Without `-o`, LSF mails the output, which on many clusters goes nowhere.
- `-n` counts slots, not nodes; node count emerges from `-n` ÷ `ptile`.
