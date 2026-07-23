# libvirt VMs live backup

## Prerequisites

- libvirt ≥ 7.2.0
- QEMU ≥ 4.2
- modern POSIX‑compliant shell
- unprivileged user with `virsh` clearance (as per Distro manual)

## How-tos

With unprivileged user at each host:

- pick archive or clone`git clone https://github.com/aashipov/libvirt-backup.git` or pull recent version `git pull -r`
- make an .env file `cp .env.template .env`, adjust variables (Per-host variables, especially)
- launch backup jobs `./bc.sh` (consecutive, blocking)
- kill backup jobs `pkill -f bc.sh ; ./bc-kill.sh`
- replicate backups and clean obsoletes `./rc.sh`

## Technology choice

[Official manual](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/backing-up-and-recovering-virtual-machines_configuring-and-managing-virtualization)

[Tools like](https://github.com/abbbi/virtnbdbackup) may not fit an 'air-gapped' / 'airtight' environment / 'secure' linux distros

GNU Coreutils, sed, grep, environment file and shell script 'glue' might be an alternative to the above

Live/online backup may produce inconsistent data across VMs which depend on each other. 

Logical Volume Manager (LVM) is considered slower than traditional partitions. Virtual disks must be attached to VM as virtio / writeback cache mode

## License

Perl "Artistic License"
