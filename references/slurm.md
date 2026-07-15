# SLURM Reference

Directives use `#SBATCH`. Submit with `sbatch script.sh`; monitor with `squeue -u $USER`; inspect a finished job with `sacct -j <id> --format=JobID,State,Elapsed,MaxRSS,ExitCode`; explain a pending job with `squeue -j <id> --start` or `scontrol show job <id>`.

## Core directives

| Directive | Meaning | Notes |
|---|---|---|
| `--job-name=NAME` | Job name | Shows in `squeue`; usable in log paths as `%x` |
| `--time=D-HH:MM:SS` | Walltime | `HH:MM:SS` also accepted. Shorter time → better backfill scheduling |
| `--partition=NAME` | Partition | Site-specific; list with `sinfo` |
| `--account=NAME` | Charge account | Required on allocation-metered clusters |
| `--qos=NAME` | Quality of service | Site-specific |
| `--nodes=N` | Node count | |
| `--ntasks=N` / `--ntasks-per-node=N` | MPI ranks | Prefer `--ntasks-per-node` with `--nodes` for predictable layout |
| `--cpus-per-task=N` | Cores per rank | For threading/OpenMP under each task |
| `--mem=SIZE` | Memory **per node** | e.g. `--mem=64G`; `--mem=0` requests all node memory on many sites |
| `--mem-per-cpu=SIZE` | Memory **per core** | Mutually exclusive with `--mem` |
| `--gres=gpu:N` or `--gpus-per-node=N` | GPUs | Some sites need a type: `--gres=gpu:a100:4` |
| `--array=0-99%10` | Array job | `%10` throttles to 10 concurrent tasks |
| `--output=FILE` / `--error=FILE` | Logs | `%j`=job ID, `%x`=name, `%A`/`%a`=array parent/index. Default merges both into `slurm-%j.out` |
| `--mail-type=END,FAIL` `--mail-user=...` | Email | |
| `--constraint=FEATURE` | Node features | e.g. CPU generation; site-specific |
| `--exclusive` | Whole node | |

Useful runtime variables: `$SLURM_JOB_ID`, `$SLURM_ARRAY_TASK_ID`, `$SLURM_CPUS_PER_TASK`, `$SLURM_NTASKS`, `$SLURM_JOB_NODELIST`, `$SLURM_SUBMIT_DIR` (jobs start in the submit directory already — no `cd` needed, unlike PBS/SGE).

## Launching

Use `srun ./program` for MPI — it reads the allocation directly, no `-np` or hostfile needed. `mpirun` also works with most MPI builds but `srun` is the native path. For non-MPI programs just invoke them directly.

## Examples

### GPU training (single node, 4 GPUs, single process w/ DDP via torchrun)

```bash
#!/bin/bash
#SBATCH --job-name=train-resnet
#SBATCH --partition=gpu            # placeholder: check `sinfo`
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:4
#SBATCH --mem=128G                 # per node
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out

module purge
module load cuda/12.4              # placeholder: check `module avail cuda`
source ~/miniconda3/etc/profile.d/conda.sh
conda activate torch

echo "Job $SLURM_JOB_ID on $SLURM_JOB_NODELIST, started $(date)"
torchrun --standalone --nproc_per_node=4 train.py --epochs 50
```

Multi-node DDP: `--nodes=2 --ntasks-per-node=1 --gpus-per-node=4`, then launch with `srun torchrun --nnodes=$SLURM_NNODES --nproc_per_node=4 --rdzv_backend=c10d --rdzv_endpoint=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n1):29500 train.py`.

### MPI (2 nodes × 64 ranks)

```bash
#!/bin/bash
#SBATCH --job-name=cfd-run
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --mem=0
#SBATCH --time=1-00:00:00
#SBATCH --output=logs/%x-%j.out

module purge
module load gcc openmpi            # placeholder module names

srun ./solver input.dat            # srun launches all 128 ranks
```

### OpenMP (1 task, 32 threads)

```bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
...
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
./threaded_program
```

### Array over input files

```bash
#SBATCH --array=1-500%50
#SBATCH --output=logs/%x-%A_%a.out
...
INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" filelist.txt)
./process "$INPUT"
```

## Gotchas

- `--mem` is per **node**, `--mem-per-cpu` per **core**; never use both.
- sbatch exports the submitting shell's environment into the job by default — `module purge` in the script guards against surprises.
- Time format `1-12:00:00` = 1 day 12 h; a bare number means **minutes**.
- Array logs need `%A_%a`, not `%j`, or all tasks write to distinguishable-but-confusing per-task job IDs.
- GPU jobs on some sites require both a GPU partition **and** `--gres`; requesting `--gres` on a CPU partition pends forever.
- Pending forever? `squeue -j <id> -O reason` — commonly a bad account/QOS/partition combination, or a resource shape no node satisfies.
