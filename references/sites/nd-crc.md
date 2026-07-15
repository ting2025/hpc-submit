# Site: Notre Dame CRC (Center for Research Computing)

The user's primary cluster. Details below override the generic `references/sge.md` guidance — use them verbatim. Official docs: https://docs.crc.nd.edu (hardware: `/infrastructure/available_hardware.html`, UGE environment: `/infrastructure/crc_uge_env.html`). New-user orientation: see `nd-crc-user-docs.md`.

- **Scheduler**: UGE (Univa Grid Engine) — `#$` directives, `qsub`
- **Login hosts**: `crcfe01.crc.nd.edu`, `crcfe02.crc.nd.edu` (64-core AMD EPYC 7543, 256 GB); `daccssfe.crc.nd.edu` (64-core Intel, 3 TB RAM)
- **Module system**: environment modules (`module load ...`)
- **Conda envs**: typically under `/users/<netid>/.conda/envs/`; activate via `source "$(conda info --base)/etc/profile.d/conda.sh" && conda activate /users/<netid>/.conda/envs/<env>`

## Queues

| Queue | Purpose | Runtime limit | Hardware |
|---|---|---|---|
| `long` | Primary general-access queue | 15 days | General-access nodes: 64-core AMD EPYC 7543, 256 GB RAM, 1 TB SSD (d32cepyc182–247) |
| `hpc` | HPC nodes | — | 48-core AMD EPYC 7451, 128 GB RAM, 2 TB SSD (d24cepyc067–140) |
| `largemem` | Large-memory jobs | — | 4 nodes: 64-core EPYC 7543, **2 TB RAM** each |
| `gpu` | GPU jobs | — | 12 nodes: dual Xeon Gold 6326 (32 cores), 256 GB RAM, **4× NVIDIA A10 per node** (48 GPUs total) |

Host-group targeting is also supported, e.g. `#$ -q *@@general_access` or `#$ -q *@@crc_d32cepyc` (list with `qconf -shgrpl`); users can only submit to host groups their research group has access to (PI emails CRCSupport@nd.edu for access).

## Parallel environments

| PE | Use | Note |
|---|---|---|
| `smp` | Shared-memory, single node | Up to 64 cores on one machine |
| `mpi-24` | Multi-node MPI | Request in 24-core increments (matches 48-core hpc nodes) |
| `mpi-32` | Multi-node MPI | 32-core increments |
| `mpi-64` | Multi-node MPI | 64-core increments (matches 64-core general-access nodes) |
| `mpi` | General MPI | Size-unspecified |

Syntax: `#$ -pe smp 8`, `#$ -pe mpi-64 128`. The increment must match the target hardware — a 24-core server will not accept `mpi-32` requests. No PE = serial, 1 core. One thread per core on all CRC machines.

## Site-specific syntax

- **GPU request**: `#$ -l gpu_card=N` on `-q gpu` (docs use `gpu_card`; if a script with `-l gpu=` is encountered, verify the resource name with `qconf -sc`). Pair with `-pe smp <cores>` for CPU cores alongside the GPU.
- **Typical GPU job header** (matches the user's existing scripts): `-q gpu`, `-l gpu_card=1`, `-pe smp 2`, `-j y`, `-o logs/`, `-cwd`.

## Limits

- Max **50 concurrent running jobs** per user (across all queues)
- Max **2,000 tasks** in a single array job (`-t 1-2000` ceiling)

## Known quirks

- AFS is being retired **May 2027** — don't build new workflows on AFS paths.
- GPU nodes have 4 A10s each with 32 CPU cores — requesting more than 8 cores per GPU (`-pe smp`) oversubscribes the node's CPU/GPU ratio.
