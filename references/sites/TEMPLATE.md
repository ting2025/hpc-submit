# Site: <cluster name>

Copy this file to `<cluster-name>.md` and fill in real values. Details recorded here override the generic scheduler reference — use them verbatim instead of asking the user or writing placeholders.

- **Scheduler**: <SLURM | PBS Pro | Torque | LSF | SGE/UGE> (version if known)
- **Login host**: <e.g. login.cluster.university.edu>
- **Account/project format**: <e.g. `--account=abc123` — where the user finds theirs>
- **Module system**: <Lmod / environment modules; e.g. `module load gcc/13.2 openmpi/4.1.6`>

## Partitions / queues

| Name | Purpose | Max walltime | Nodes/cores/mem | Notes |
|---|---|---|---|---|
| <normal> | <general CPU> | <48:00:00> | <128 cores, 512 GB> | |
| <gpu> | <A100 nodes> | <24:00:00> | <4× A100 80GB per node> | <GPU request syntax used here> |

## Site-specific syntax

- GPU request: <exact flag, e.g. `--gres=gpu:a100:4` or `-gpu "num=4"`>
- Memory semantics: <per node / per core / per slot; units>
- Parallel environments (SGE only): <e.g. `smp` up to 1 node, `mpi` across nodes>

## Filesystems

- Home: <path, quota, backed up?>
- Scratch: <path, purge policy — jobs should write here>

## Known quirks

- <e.g. "must load `slurm` module before sbatch works", "GPU jobs require `--qos=gpu`">
