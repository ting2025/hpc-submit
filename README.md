# hpc-submit — a Claude skill for HPC job submission scripts

A [Claude Skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) that teaches Claude to write correct, ready-to-submit batch job scripts for the five major cluster schedulers:

| Scheduler | Submit with | Covered |
|---|---|---|
| SLURM | `sbatch` | GPU/DDP training, MPI, arrays, OpenMP |
| PBS Pro / Torque / OpenPBS | `qsub` | both dialects (`select` vs `nodes:ppn`) |
| LSF | `bsub <` | slots/ptile geometry, GPU, arrays |
| SGE / UGE (Grid Engine) | `qsub` | PEs, per-slot memory, arrays |
| HTCondor | `condor_submit` | submit files, file transfer, queue sweeps, DAG pointers |

The skill enforces the things that actually make first submissions fail: matching the resource request to the launch line, never inventing site-specific names (partitions, accounts, PEs, module versions), scheduler-specific memory semantics, log directories that must exist before submission, and array jobs that genuinely map task IDs to work.

## Download and install

### Claude Code (CLI / desktop / IDE)

Clone this repository into your personal skills directory:

```bash
# personal (available in every project)
git clone https://github.com/<your-username>/hpc-submit.git ~/.claude/skills/hpc-submit

# or project-scoped (available to collaborators in one repo)
git clone https://github.com/<your-username>/hpc-submit.git <project>/.claude/skills/hpc-submit
```

Claude Code discovers skills in those directories automatically. Update later with `git pull`.

### Claude.ai and the Claude desktop/mobile apps

Download `hpc-submit.skill` from this repository's [Releases](../../releases) page, then upload it under **Settings → Capabilities → Skills**.

## How to use

Describe the job in plain language, and the skill triggers on requests for *job scripts*, *submission scripts*, or running things on a *cluster*, and it infers the scheduler from context if you don't name it:

> Write me a SLURM script to train a PyTorch model on 4 GPUs, ~100 GB RAM, about 10 hours.

> I have 800 input files listed in inputs.txt and process.sh takes one as an argument — run them all on our SGE cluster without hogging it.

> We're on an HTCondor pool with no shared filesystem. Run ./simulate for each of the 300 .cfg files in params/.

Claude will ask for anything site-specific it can't know such as queue names, accounts, module versions, or create placeholders, and hands back the exact submit and monitoring commands with the script.

### Adapting it to your cluster

Generic scheduler knowledge lives in `references/<scheduler>.md`. Cluster-specific truth (real queue names, PEs, GPU syntax, filesystem rules) lives in `references/sites/` — copy `references/sites/TEMPLATE.md` to `references/sites/<your-cluster>.md`, fill it in, and the skill will use those values verbatim whenever you mention that cluster. A completed example for the Notre Dame CRC UGE cluster is included (`nd-crc.md`); remove or replace it if that's not your site.

`assets/array_demo.sh` is a scheduler-agnostic array-job template showing both task-mapping patterns (one task per input-file line, and one task per parameter combination via parallel bash arrays) with the guards that keep big sweeps honest.

## Repository layout

```
hpc-submit/
├── SKILL.md                    # workflow: identify scheduler → gather → write → validate
├── references/
│   ├── slurm.md  pbs.md  lsf.md  sge.md  htcondor.md
│   └── sites/
│       ├── TEMPLATE.md         # fill-in form for your cluster
│       ├── nd-crc.md           # example: Notre Dame CRC (UGE)
│       └── nd-crc-user-docs.md
└── assets/
    └── array_demo.sh           # array-job template (single- and multi-parameter mapping)
```

## Skill description

The exact description Claude uses to decide when to invoke the skill (from `SKILL.md` frontmatter):

> Write correct, ready-to-submit HPC batch job submission scripts for SLURM (sbatch), PBS/Torque/PBS Pro (qsub), LSF (bsub), SGE/UGE (qsub), and HTCondor (condor_submit). Use this skill whenever the user asks for a job script, submission script, submit file, batch script, or wants to run something on a cluster, supercomputer, HPC system, condor pool, or the Open Science Grid — including GPU/deep-learning training jobs, MPI multi-node runs, array jobs and parameter sweeps, high-throughput many-job workloads, and serial or OpenMP jobs — even if they don't name the scheduler explicitly.

## Appendix
### Author's statement
This skill is coded by Claude Code, and the author wrote the templates for major syntaxes. This skill is distributed under the MIT license, while Anthropic reserve rights for proper use of code and personal distribution of packages. The author thank University of Notre Dame CRC for their user documentations and tutorial sessions.

### References
1. Anthropic. *Extend Claude with skills*. https://code.claude.com/docs/en/skills
2. SchedMD. *sbatch — Slurm Workload Manager*. https://slurm.schedmd.com/sbatch.html
3. Altair. *Altair PBS Professional 2022.1 User Guide*. https://help.altair.com/2022.1.0/PBS%20Professional/PBSUserGuide2022.1.pdf
4. IBM. *IBM Spectrum LSF Command Reference*. https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=reference-command
5. Open Grid Scheduler. *SGE Manual Pages*. https://gridscheduler.sourceforge.net/htmlman/manuals.html
6. HTConder. *HTCondor Version 25.11.0 Manual*. https://htcondor.readthedocs.io/en/latest/#htcondor-version-release-manual


