# Notre Dame CRC — new-user documentation pointers

Orientation material for someone new to the CRC, or for pointing a user at the official source when a question goes beyond job scripts. Main portal: https://docs.crc.nd.edu

## Key documentation pages

- Available hardware: https://docs.crc.nd.edu/infrastructure/available_hardware.html
- UGE environment (queues, PEs, host groups): https://docs.crc.nd.edu/infrastructure/crc_uge_env.html
- Introductory videos index: https://docs.crc.nd.edu/new_user/introductory_videos.html

## Introductory video topics (all linked from the videos index)

Getting connected: accessing CRC systems (accounts) · front-end systems overview · connecting from Windows · connecting from Mac · connecting from the browser (FastX) · utilizing front-end systems appropriately.

Working on the cluster: modules · file systems · transferring files · job scripts · parallel environments · queues · job submission · job monitoring · checking available resources (CPU/GPU availability) · job arrays.

## Notes

- Front ends (`crcfe01`/`crcfe02`) are for editing, compiling, and submitting — not for running compute workloads; use `qsub` (or a short interactive session) instead.
- AFS retires **May 2027**; migrate anything still on AFS paths.
- Support: CRCSupport@nd.edu (PI must request research-group/host-group access).
