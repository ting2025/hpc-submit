# SGE / UGE (Grid Engine) Reference

Directives use `#$`. Submit with `qsub script.sh`; monitor with `qstat -u $USER`; why pending: `qstat -j <id>` (see "scheduling info" at the bottom); finished-job accounting: `qacct -j <id>`.

## Core directives

| Directive | Meaning | Notes |
|---|---|---|
| `-N name` | Job name | Must not start with a digit |
| `-S /bin/bash` | Shell | Include always — some sites default to csh and bash syntax then fails cryptically |
| `-cwd` | Run in submit directory | Without it the job starts in `$HOME` |
| `-q queue` | Queue | Site-specific; list with `qconf -sql` |
| `-P project` | Project | |
| `-l h_rt=HH:MM:SS` | Hard walltime | |
| `-l mem_free=4G` / `-l h_vmem=4G` | Memory | **Per slot**, multiplied by the `-pe` slot count. `h_vmem` is a hard kill limit; which resource name a site uses varies — check `qconf -sc` |
| `-pe NAME N` | Parallel environment + slots | PE **names are entirely site-specific** (`smp`, `mpi`, `orte`, `mpich`…). List with `qconf -spl`. Never guess one |
| `-l gpu=1` | GPUs | Site-defined resource; name varies (`gpu`, `ngpus`, `gpu_card`) — check `qconf -sc` |
| `-t 1-500` | Array | Index in `$SGE_TASK_ID`; throttle with `-tc 50` |
| `-j y` | Merge stderr into stdout | |
| `-o path` / `-e path` | Logs | Default `<name>.o<jobid>` (arrays: `.o<jobid>.<taskid>`) |
| `-m bea -M user@x` | | |
| `-V` | Export submit environment | Prefer explicit module loads |
| `-R y` | Reservation | Helps large parallel jobs actually start on busy clusters |

Runtime variables: `$JOB_ID`, `$SGE_TASK_ID`, `$NSLOTS` (granted slots), `$PE_HOSTFILE` (host/slot list for MPI), `$SGE_O_WORKDIR`.

## Launching

- **Threaded/OpenMP**: request a shared-memory PE (often called `smp`), then `export OMP_NUM_THREADS=$NSLOTS`.
- **MPI**: request the MPI PE; integrated MPI builds honor the allocation with plain `mpirun -np $NSLOTS ./program`; otherwise convert `$PE_HOSTFILE` into a machinefile.

## Examples

### Serial

```bash
#!/bin/bash
#$ -N convert
#$ -S /bin/bash
#$ -cwd
#$ -l h_rt=02:00:00
#$ -l mem_free=8G
#$ -j y
#$ -o logs/

module load python/3.11        # placeholder module name
python convert.py
```

### OpenMP (16 threads)

```bash
#$ -pe smp 16                  # placeholder PE name: check `qconf -spl`
#$ -l h_rt=08:00:00
#$ -l mem_free=4G              # per slot → 64 GB total
...
export OMP_NUM_THREADS=$NSLOTS
./threaded_program
```

### MPI (64 ranks)

```bash
#$ -pe mpi 64                  # placeholder PE name
#$ -l h_rt=24:00:00
#$ -R y
...
module load openmpi
mpirun -np $NSLOTS ./solver input.dat
```

### Array over files

```bash
#$ -t 1-500
#$ -tc 50
...
INPUT=$(sed -n "${SGE_TASK_ID}p" filelist.txt)
./process "$INPUT"
```

### Array over parameter combinations (multi-parameter mapping)

```bash
#$ -t 1-6        # KEEP IN SYNC with the array lengths below
...
METHODS=(  alpha alpha beta beta gamma gamma )
SETTINGS=( low   high  low  high low   high  )
N=${#METHODS[@]}
[ "${#SETTINGS[@]}" -ne "$N" ] && { echo "array length mismatch" >&2; exit 2; }
if [ "$SGE_TASK_ID" -lt 1 ] || [ "$SGE_TASK_ID" -gt "$N" ]; then
  echo "task $SGE_TASK_ID out of range"; exit 0
fi
METHOD=${METHODS[$((SGE_TASK_ID-1))]}
SETTING=${SETTINGS[$((SGE_TASK_ID-1))]}
./run_experiment --method "$METHOD" --setting "$SETTING" --out "results/${METHOD}_${SETTING}"
```

See `assets/array_demo.sh` for the fully-guarded template. For post-processing after the whole array, submit a follow-up job with `-hold_jid <jobid>` rather than coordinating inside the tasks.

## Gotchas

- Memory requests are **per slot**: `-pe smp 16` with `-l h_vmem=4G` = 64 GB total; users who meant 4 GB total get their PE request rejected or a node-sized reservation.
- Omitting `-cwd` (job runs in `$HOME`) and omitting `-S /bin/bash` (csh parses your bash) are the two classic SGE failures.
- PE names cannot be guessed — a wrong PE name is an immediate rejection. Ask or use a commented placeholder pointing at `qconf -spl`.
- `-o logs/` requires the directory to exist before submission; SGE won't create it and the job dies instantly with no log.
- `h_rt` too low kills the job with SIGKILL at the limit — no grace, no partial output flush.
