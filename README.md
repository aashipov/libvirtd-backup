# Backup libvirtd VMs

## Prerequisites

- libvirt ≥ 7.2.0
- QEMU ≥ 4.2
- modern POSIX‑compliant shell
- unprivileged user with `virsh` clearance (as per Distro manual)

## How-tos

With unprivileged user at each host:

- pick archive or clone```git clone https://github.com/aashipov/libvirtd-backup.git``` or pull recent version ```git pull -r```
- make an .env file ```cp .env.template .env```, adjust variables (Per-host variables, especially)
- launch backups `./bc.sh`
- kill backup jobs `pkill -f bc.sh ; ./bc-kill.sh`
- replicate backups and clean obsoletes `rc.sh`

## License

Perl "Artistic License"
