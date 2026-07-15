# HTCondor Reference

HTCondor differs structurally from SLURM/PBS/LSF/SGE: instead of a shell script with directive comments, the user writes a **submit description file** (`key = value` lines ending in a `queue` statement) and submits it with `condor_submit job.sub`. The executable is separate — often a small wrapper shell script you should also write. Deliver **both files** when the job needs environment setup.

Monitor with `condor_q`; held jobs: `condor_q -hold` (the HoldReason says why); remove with `condor_rm <cluster>`; finished jobs: `condor_history <cluster>`; debug a running job: `condor_ssh_to_job <id>`; available machines/GPUs: `condor_status` / `condor_status -gpus -compact`.

## The file-transfer model — the key mental shift

HTCondor pools (especially Open Science Grid–style pools) generally do **not** share a filesystem between submit and execute machines. Assume file transfer unless the user says they have a shared FS:

```
should_transfer_files   = YES
transfer_input_files    = data.tar.gz, config.yaml
when_to_transfer_output = ON_EXIT
```

Everything the job reads must be listed in `transfer_input_files` (the `executable` transfers automatically). Files the job creates in its scratch working directory come back automatically on exit; the classic failure is a program writing results to an absolute path that exists only on the submit node — outputs vanish. Have the wrapper write outputs into the job's working directory.

## Core submit commands

| Command | Meaning | Notes |
|---|---|---|
| `universe = vanilla` | Execution environment | `vanilla` is the default and right for most jobs; `container`/`docker` for images; `parallel` for multi-node MPI (rare — HTCondor is built for high-throughput, not tightly-coupled jobs) |
| `executable = run.sh` | Program/wrapper to run | Transferred automatically |
| `arguments = $(infile) 42` | Argument list | |
| `request_cpus = 4` | Cores | |
| `request_memory = 8GB` | Memory | A bare number is **MB**; always write units. Jobs exceeding the request get **held**, not OOM-killed |
| `request_disk = 10GB` | Scratch disk | Required on many pools; covers inputs + outputs |
| `request_gpus = 1` | GPUs | Constrain capability with `gpus_minimum_capability = 8.0` / `gpus_minimum_memory = 40GB` or `require_gpus = Capability >= 8.0` |
| `output = out.$(Cluster).$(Process)` | stdout | |
| `error = err.$(Cluster).$(Process)` | stderr | |
| `log = job.$(Cluster).log` | **Event log** | Scheduler events (submit/start/hold/exit), not program output. Always include one — it's the primary debugging tool, and `condor_wait` watches it |
| `environment = "VAR=value"` | Env vars | `getenv = true` copies the submit shell's env — avoid; it breaks on remote execute nodes |
| `requirements = (OpSysAndVer == "AlmaLinux9")` | Machine constraints | ClassAd expression |
| `rank = Memory` | Preference among matches | Higher is better |
| `notification = Error` `notify_user = you@x` | Email | |
| `max_idle = 100` | Late materialization | For many-thousand-job submissions; keeps only 100 idle in queue at once |
| `+ProjectName = "MyProject"` | Custom attribute | Some pools (e.g. OSPool) require one — site-specific |

There is no walltime request in the core model; long jobs are fine, but some pools preempt/evict, so mention checkpointing for very long jobs if relevant.

## The queue statement — arrays and sweeps

The `queue` statement (last line) is where HTCondor replaces array jobs, and it's more expressive:

```
queue                              # one job
queue 500                          # 500 jobs, $(Process) = 0..499
queue infile matching *.dat        # one job per matching file, in $(infile)
queue infile from filelist.txt     # one job per line of a file
queue sample,seed from (           # multiple variables per job
  tumor1, 101
  tumor2, 102
)
```

Use `$(Cluster)` and `$(Process)` in output/error/log names so per-job files don't collide. Unlike SLURM/SGE arrays there's no throttle flag needed for fairness — the pool's fair-share scheduler handles it — but for >~10k jobs add `max_idle` so the queue stays responsive.

## Examples

### Sweep over 800 input files, no shared filesystem

`process.sub`:
```
universe                = vanilla
executable              = run.sh
arguments               = $(infile)
transfer_input_files    = $(infile)
should_transfer_files   = YES
when_to_transfer_output = ON_EXIT

request_cpus            = 1
request_memory          = 4GB
request_disk            = 8GB

output                  = logs/out.$(Cluster).$(Process)
error                   = logs/err.$(Cluster).$(Process)
log                     = logs/sweep.$(Cluster).log

queue infile from inputs.txt
```

`run.sh` (the wrapper — writes output to the scratch dir so it transfers back):
```bash
#!/bin/bash
set -e
INFILE=$(basename "$1")
./process "$INFILE" > "result_${INFILE%.dat}.out"
```

Create `logs/` before submitting — like SGE, HTCondor won't create it and the jobs go on hold.

### GPU job

```
universe                 = vanilla
executable               = train.sh
request_cpus             = 8
request_gpus             = 1
gpus_minimum_memory      = 40GB
request_memory           = 64GB
request_disk             = 50GB
transfer_input_files     = train.py, env.tar.gz, data/
should_transfer_files    = YES
when_to_transfer_output  = ON_EXIT
output                   = logs/train.$(Cluster).out
error                    = logs/train.$(Cluster).err
log                      = logs/train.$(Cluster).log
queue
```

With no shared FS there are no site modules — the wrapper typically unpacks a portable environment (e.g. `tar xzf env.tar.gz` for a conda-pack env, or use `universe = container` with `container_image = docker://...`, which many pools prefer for GPU work).

### Custom macros and computed values

Submit files support user-defined macros and match-time arithmetic — useful for keeping resource math in one place and for offsetting job numbering:

```
N_CPUS     = 24
RAM_PER_CPU = 800          # MB, matching the application's per-core config
offset     = 999

request_cpus   = $(N_CPUS)
request_memory = $(RAM_PER_CPU) * $(N_CPUS)

executable = wrapper.sh
arguments  = $$([$(Process) + $(offset)]) $(N_CPUS)
output     = logs/job_$$([$(Process) + $(offset)]).out
error      = logs/job_$$([$(Process) + $(offset)]).err
log        = logs/cluster.log
queue 1000
```

`$(name)` expands at submit time; `$$([ expr ])` evaluates a ClassAd expression at match time — the `$(Process) + $(offset)` idiom continues a numbering scheme across separate submissions (jobs 999–1998 here). Passing `$(N_CPUS)` into `arguments` lets the wrapper tell the application how many cores it was actually granted. Keep comments on their own lines, not trailing a value — trailing text can end up inside the value.

### Many-job submission (late materialization)

```
executable = foo
arguments  = input_file.$(Process)
output     = out.$(Process)
error      = err.$(Process)
log        = foo.log
max_idle   = 100
queue 15000
```

## Gotchas

- `request_memory = 4096` means 4096 **MB** — write explicit units (`4GB`) to avoid ambiguity.
- `log` is the scheduler event log, not program output; users conflate it with `output` constantly. Include all three.
- A job stuck **Idle** usually has unsatisfiable requirements — `condor_q -better-analyze <id>` explains which clause eliminated all machines.
- A **Held** job did start but hit a policy (over memory, missing input file, bad path) — `condor_q -hold` shows the reason; fix and `condor_release`.
- Outputs written to absolute paths don't transfer back — write to the job's working directory.
- No shebang tricks: submit files are not shell scripts; there is no `#CONDOR` directive form.
- MPI across machines needs `universe = parallel` and pool-admin setup; if a user asks for tightly-coupled multi-node MPI on a condor pool, flag that an HPC scheduler may be the better fit and confirm the pool supports the parallel universe.
