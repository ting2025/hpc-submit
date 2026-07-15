#!/bin/bash
# array_demo.sh — dummy array-job body demonstrating the two task-ID mapping
# patterns. Adapt it, don't run it as-is. Scheduler directives are omitted on
# purpose: prepend the block for the target scheduler and keep its range in
# sync with the case used:
#   SLURM:  #SBATCH --array=1-N%50          PBS Pro: #PBS -J 1-N
#   SGE:    #$ -t 1-N   (throttle: -tc 50)  Torque:  #PBS -t 1-N
#   LSF:    #BSUB -J "demo[1-N]%50"
#   HTCondor: do NOT port this pattern — map parameters in the .sub queue
#   statement instead (queue var1,var2 from (...)); see references/htcondor.md.

# Resolve the task id across schedulers; defaults to 1 for a local dry run.
TASK_ID=${SLURM_ARRAY_TASK_ID:-${SGE_TASK_ID:-${PBS_ARRAY_INDEX:-${PBS_ARRAYID:-${LSB_JOBINDEX:-1}}}}}

MODE=${MODE:-multi}   # "single" or "multi" — pick the case being demonstrated

if [ "$MODE" = "single" ]; then
  # === Case A: single-list mapping ==========================================
  # One task per line of a file list. Array range = line count of inputs.txt.
  INPUT=$(sed -n "${TASK_ID}p" inputs.txt)
  if [ -z "$INPUT" ]; then
    echo "task $TASK_ID: no input line (range exceeds file?); exiting" >&2
    exit 0
  fi
  echo "task $TASK_ID -> $INPUT"
  # ./process "$INPUT"

else
  # === Case B: multi-parameter mapping ======================================
  # One task per parameter combination, via parallel bash arrays. Write out
  # the combinations explicitly (crossed lists, irregular cases, "none"
  # placeholders are all fine) — index i describes run i completely.
  #
  # KEEP THE ARRAY-RANGE DIRECTIVE IN SYNC with the number of entries below:
  # extra tasks exit immediately, but missing ones are silently never run.
  METHODS=(  alpha alpha beta  beta  gamma )
  SETTINGS=( low   high  low   high  none  )

  N=${#METHODS[@]}
  if [ "${#SETTINGS[@]}" -ne "$N" ]; then
    echo "config error: METHODS and SETTINGS differ in length" >&2
    exit 2   # fail loudly — every task is misconfigured, not just this one
  fi
  if [ "$TASK_ID" -lt 1 ] || [ "$TASK_ID" -gt "$N" ]; then
    echo "task $TASK_ID out of range 1..$N; exiting" >&2
    exit 0
  fi
  METHOD=${METHODS[$((TASK_ID - 1))]}
  SETTING=${SETTINGS[$((TASK_ID - 1))]}

  # Optional flags pattern: build an args array so "none" cleanly omits the flag.
  EXTRA_ARGS=()
  [ "$SETTING" != "none" ] && EXTRA_ARGS=(--setting "$SETTING")

  echo "task $TASK_ID/$N -> method=$METHOD setting=$SETTING"
  # ./run_experiment --method "$METHOD" "${EXTRA_ARGS[@]}" \
  #     --out "results/${METHOD}_${SETTING}"   # per-combination dir: no collisions
fi

# === Running something once AFTER the whole array finishes ==================
# Prefer a scheduler-native dependency — submit a second job held on the array:
#   SLURM: sbatch --dependency=afterok:<array_job_id> postprocess.sh
#   SGE:   qsub  -hold_jid <job_id> postprocess.sh
#   PBS:   qsub  -W depend=afterok:<job_id> postprocess.sh
#   LSF:   bsub  -w "done(<job_id>)" < postprocess.lsf
#   HTCondor: use DAGMan (a 2-node DAG: sweep -> postprocess).
# Only fall back to in-script coordination (each task drops a marker file,
# last task takes a `mkdir` lock and runs the postprocessing) when a second
# submission isn't possible — and beware NFS attribute caching, which can
# hide markers written seconds ago on other nodes and silently skip the
# postprocessing step.
