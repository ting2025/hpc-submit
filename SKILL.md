---
name: hpc-submit
description: Write correct, ready-to-submit HPC batch job submission scripts for SLURM (sbatch), PBS/Torque/PBS Pro (qsub), LSF (bsub), SGE/UGE (qsub), and HTCondor (condor_submit). Use this skill whenever the user asks for a job script, submission script, submit file, batch script, or wants to run something on a cluster, supercomputer, HPC system, condor pool, or the Open Science Grid — including GPU/deep-learning training jobs, MPI multi-node runs, array jobs and parameter sweeps, high-throughput many-job workloads, and serial or OpenMP jobs — even if they don't name the scheduler explicitly.
---

# HPC Job Submission Scripts

Write batch submission scripts that succeed on the first `sbatch`/`qsub`/`bsub`. A script "succeeds" when the scheduler accepts it, the resources it requests match how the program actually runs, and the job produces logs the user can find. Most failed submissions come from a handful of predictable mistakes — wrong directive syntax for the scheduler, resource geometry that doesn't match the launch line, or invented site-specific names — so the workflow below is built around avoiding those.

## Step 1: Identify the scheduler and site

If the user names the scheduler, use it. Otherwise infer from clues:

| Clue in the request | Scheduler |
|---|---|
| `sbatch`, `srun`, `#SBATCH`, "partition", `squeue` | SLURM |
| `#PBS`, `qsub` with `-l select=` or `-l nodes=`, `PBS_O_WORKDIR` | PBS/Torque/PBS Pro |
| `bsub`, `#BSUB`, `bjobs`, "LSF" | LSF |
| `#$`, `qsub` with `-pe`, `SGE_TASK_ID`, "Grid Engine" | SGE/UGE |
| `condor_submit`, `.sub` file, `queue` statement, `$(Process)`, "condor pool", "OSG"/"Open Science Grid", OSPool | HTCondor |

If the user names a specific cluster, check `references/sites/` for a matching file — it records that cluster's real scheduler, partitions/queues, account format, GPU syntax, and module system. If a site file exists, its details override the generic guidance. In particular: when the request points at SGE/UGE (or mentions CRC, Notre Dame, `crcfe` hosts, or queues named `long`/`gpu`/`hpc`/`largemem`) without naming another cluster, it is almost certainly the Notre Dame CRC cluster — read `references/sites/nd-crc.md` and use its real queue, PE, and GPU syntax rather than placeholders. If the scheduler is still ambiguous, ask — a script written for the wrong scheduler is worthless, and one question is cheaper than a rejected submission.

## Step 2: Read the scheduler reference

Read the matching file before writing the script — each scheduler has different directive syntax, environment variables, and failure modes, and the reference files carry the details that are easy to get subtly wrong:

- `references/slurm.md`
- `references/pbs.md` (covers both PBS Pro and Torque — they differ; the file explains how)
- `references/lsf.md`
- `references/sge.md`
- `references/htcondor.md`

HTCondor is structurally different from the other four: the deliverable is a **submit description file** (plus, usually, a wrapper shell script), not a shell script with directive comments, and it assumes **no shared filesystem** by default — file transfer must be declared. The steps below still apply conceptually (gather requirements, match resources to the run, validate, hand off), but follow the htcondor.md reference for structure instead of the directive-script template in Step 4.

## Step 3: Gather job requirements

You need, at minimum: what program to run, walltime, CPU/node geometry, memory, and (if relevant) GPU count. Infer what you reasonably can — a PyTorch training script implies GPU + conda/module environment; an `mpirun` program implies multi-node geometry; "run this on each of these 500 files" implies an array job.

Ask rather than guess for anything **site-specific**: partition/queue names, account/project strings, QOS, parallel environment names (SGE), and exact module names. These vary by cluster and an invented one gets the job rejected at submit time. If the user can't tell you and no site file covers it, use an obviously-placeholder value with a comment telling them what to replace and what command reveals the right value (e.g. `sinfo` for SLURM partitions, `qconf -spl` for SGE parallel environments). Never present an invented partition or module version as if it were real.

## Step 4: Write the script

Structure every script the same way, regardless of scheduler:

1. **Shebang** — `#!/bin/bash` (and for SGE also `-S /bin/bash`, since some sites default to csh).
2. **All scheduler directives in one block immediately after the shebang.** Schedulers stop parsing directives at the first executable line — a directive after an `echo` is silently ignored.
3. Job name, walltime, resource geometry, memory, stdout/stderr paths (use the scheduler's job-ID substitution so reruns don't clobber logs), and mail/account/queue as applicable.
4. **Environment setup** — `module purge` then explicit `module load` lines, then conda/venv activation if needed. Purging first makes the job reproducible instead of dependent on whatever the user's login shell had loaded.
5. **`cd` to the working directory.** PBS, SGE (without `-cwd`), and some LSF setups start jobs in `$HOME`, not where the user submitted — a top cause of "my job ran but produced nothing".
6. **A launch line that matches the requested geometry** (see below).
7. Optionally echo job metadata (job ID, node list, start time) at the top of the run — costs nothing and makes debugging failed runs far easier.

### The geometry rule

The single most common way a "successful" submission wastes an allocation: requesting N nodes but launching a program that only uses one. Always make the resource request and the launch line agree:

- **MPI job**: tasks requested = ranks launched. Use the scheduler-aware launcher (`srun` on SLURM; `mpirun` with the scheduler's hostfile elsewhere) so ranks land on the allocated nodes.
- **OpenMP/threaded job**: request 1 task with N cpus, and set the thread count from the scheduler's variable (e.g. `OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK`) rather than hardcoding it.
- **GPU deep learning**: single-process training needs 1 task even with multiple GPUs; `torchrun`/DDP needs one task per node with GPUs-per-node set. Say which pattern you chose and why.
- **Array job**: the script body must actually consume the task-ID variable (map it to an input file or parameter). An array job whose tasks all do identical work is a bug. Include a throttle (e.g. SLURM `%50`) for large arrays to be a good citizen.

### Array mapping patterns

Two ways the task ID becomes a concrete piece of work — `assets/array_demo.sh` is a scheduler-agnostic template showing both, ready to adapt:

- **Single-list mapping**: task N processes line N of a file list (`sed -n "${TASK_ID}p" inputs.txt`). Guard against an empty line (range larger than the file) so a misconfigured task exits cleanly instead of processing garbage.
- **Multi-parameter mapping**: task N indexes into *parallel bash arrays* that spell out every parameter combination explicitly (`METHODS[N-1]`, `SETTINGS[N-1]`). This handles crossed sweeps, irregular combinations, and "not applicable" placeholders that a file list or arithmetic can't express cleanly. Two guards matter: check the arrays have equal length (fail loudly — every task is wrong, not one), and check the task ID is within range. The array-range directive must be kept in sync with the list length by hand — say so in a comment next to the lists, because extra tasks merely exit but *missing ones are silently never run*.

Also consider whether an array is the right shape at all: a handful of short scenarios that can run back-to-back within one walltime are often better as a plain loop inside a single job (one submission, one log, shared warm caches) — reach for an array when combinations are numerous, long, or worth scheduling independently.

### Running something after all jobs finish

Users often want one post-processing step (merge results, make plots) after an array or set of jobs completes. Use the scheduler's native dependency mechanism — a second submitted job that waits:

| Scheduler | Dependency |
|---|---|
| SLURM | `sbatch --dependency=afterok:<jobid>` (`aftercorr` for per-task chaining) |
| PBS | `qsub -W depend=afterok:<jobid>` |
| LSF | `bsub -w "done(<jobid>)"` |
| SGE | `qsub -hold_jid <jobid>` (`-hold_jid_ad` for per-task) |
| HTCondor | DAGMan: a two-node DAG (`condor_submit_dag`) |

In-script coordination (each task drops a marker file; the last one takes a `mkdir` lock and runs the step) is a fallback for when a second submission isn't possible — warn that NFS attribute caching can hide markers written seconds earlier on other nodes, making every task undercount and the step silently skip.

### Memory semantics differ — flag it

Whether a memory request means per-node, per-core, or per-slot depends on the scheduler (and on LSF/SGE, on the site). The reference files spell this out per scheduler. Get it wrong in one direction and the job is killed by the OOM policer; wrong in the other and it queues forever. State in a comment which semantics the request uses.

## Step 5: Validate and hand off

Before presenting the script, check:

- [ ] Directives contiguous at the top, correct prefix for the scheduler
- [ ] Walltime present and in that scheduler's format (they differ: `D-HH:MM:SS` vs `HH:MM:SS` vs LSF's `HH:MM`)
- [ ] Launch line matches requested geometry
- [ ] Log paths use job-ID substitution
- [ ] No invented site-specific names — placeholders are commented as placeholders
- [ ] `cd` handled for schedulers that start in `$HOME`

Then give the user the exact submission command (mind LSF's `bsub < script.lsf` — forgetting the `<` silently ignores all `#BSUB` directives), plus the one-liners to monitor the job and to check why it's pending or why it failed. Briefly note any assumptions made (e.g. "assumed per-node memory; adjust `--mem-per-cpu` if your site meters per core").

## Adding a site file

When the user provides real details for a cluster they use regularly, offer to save them: copy `references/sites/TEMPLATE.md` to `references/sites/<cluster-name>.md` and fill it in. Future requests naming that cluster then skip the site-specific questions entirely.
