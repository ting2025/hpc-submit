# PBS Reference (PBS Pro and Torque)

Directives use `#PBS`. Submit with `qsub script.sh`; monitor with `qstat -u $USER`; details with `qstat -f <id>`; why pending: `qstat -f <id> | grep comment`.

**Two dialects.** PBS Pro (and OpenPBS) uses `-l select=...` chunk syntax and `-J` for arrays. Old Torque uses `-l nodes=N:ppn=M` and `-t` for arrays. Determine which the cluster runs (ask, or check the site file); mixing dialects is the #1 PBS submission error. `qstat --version` distinguishes them.

## Core directives

| Directive | Meaning | Notes |
|---|---|---|
| `-N name` | Job name | Max ~15 chars on some systems |
| `-l walltime=HH:MM:SS` | Walltime | |
| `-q queue` | Queue | Site-specific; list with `qstat -Q` |
| `-A account` | Charge account | |
| `-l select=2:ncpus=32:mpiprocs=32:mem=64gb` | **PBS Pro** resources | 2 chunks (≈nodes), each 32 cores / 32 ranks / 64 GB. `mem` is **per chunk** |
| `-l place=scatter` | Chunk placement | Without it PBS Pro may pack multiple chunks onto one large node; add it when the user genuinely wants distinct physical nodes (bandwidth, memory) |
| `-l nodes=2:ppn=32` + `-l mem=128gb` | **Torque** resources | `mem` is total job memory on most Torque sites; `pmem` is per-process |
| `-l select=1:ngpus=4` / `-l nodes=1:ppn=8:gpus=4` | GPUs | Pro / Torque; syntax is highly site-dependent — confirm |
| `-J 0-99` / `-t 0-99` | Array | Pro / Torque. Index var: `$PBS_ARRAY_INDEX` (Pro) / `$PBS_ARRAYID` (Torque) |
| `-j oe` | Merge stderr into stdout | |
| `-o path` / `-e path` | Logs | Default: `<name>.o<jobid>` in submit dir, written **after** job ends |
| `-m abe -M user@x` | Email | |
| `-V` | Export submit environment | Prefer explicit `module load` instead |

Runtime variables: `$PBS_O_WORKDIR` (submit directory), `$PBS_JOBID`, `$PBS_NODEFILE` (hostfile for mpirun), `$NCPUS`.

## Launching

Jobs start in `$HOME` — **always** `cd $PBS_O_WORKDIR` before doing anything. For MPI: `mpirun ./program` works if the MPI is scheduler-integrated; otherwise `mpirun -np <ranks> -machinefile $PBS_NODEFILE ./program`.

## Examples

### MPI, PBS Pro (2 nodes × 32 ranks)

```bash
#!/bin/bash
#PBS -N cfd-run
#PBS -q normal                       # placeholder: check `qstat -Q`
#PBS -A PROJ123                      # placeholder account
#PBS -l select=2:ncpus=32:mpiprocs=32:mem=120gb
#PBS -l place=scatter
#PBS -l walltime=24:00:00
#PBS -j oe

cd $PBS_O_WORKDIR
module purge
module load gcc openmpi              # placeholder module names

mpirun ./solver input.dat            # scheduler-integrated MPI reads the allocation
```

### GPU training, PBS Pro

```bash
#PBS -l select=1:ncpus=16:ngpus=4:mem=128gb
#PBS -l walltime=12:00:00
...
cd $PBS_O_WORKDIR
module load cuda/12.4
conda activate torch
torchrun --standalone --nproc_per_node=4 train.py
```

### Array, Torque

```bash
#PBS -t 1-500
...
cd $PBS_O_WORKDIR
INPUT=$(sed -n "${PBS_ARRAYID}p" filelist.txt)
./process "$INPUT"
```

(PBS Pro: `#PBS -J 1-500` and `$PBS_ARRAY_INDEX`.)

### OpenMP

```bash
#PBS -l select=1:ncpus=32:ompthreads=32
...
cd $PBS_O_WORKDIR
export OMP_NUM_THREADS=$NCPUS
./threaded_program
```

## Gotchas

- Forgetting `cd $PBS_O_WORKDIR` is the classic PBS failure: job runs in `$HOME`, reads/writes nothing the user expected.
- stdout/stderr are spooled and only copied back **when the job ends** — for live progress, redirect explicitly inside the script (`./prog > $PBS_O_WORKDIR/run.log 2>&1`).
- PBS Pro `mem` in a select chunk is per chunk; Torque `mem` is usually whole-job. State which you assumed.
- Directives after the first executable line are ignored — keep the `#PBS` block contiguous.
- Interactive test run: `qsub -I -l select=1:ncpus=4 -l walltime=00:30:00`.
