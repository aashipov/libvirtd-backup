#!/bin/sh

# ------------------------------------------------------------
#  lib.sh – Shared functions
# ------------------------------------------------------------

# ------------------------------------------------------------
#  Prevent multiple loads of the library
# ------------------------------------------------------------
if [ -n "${_LIB_SH_LOADED}" ]
then
    return
fi
readonly _LIB_SH_LOADED=1

# ------------------------------------------------------------
#  Utility helpers
# ------------------------------------------------------------

log() {
    # Append timestamped message to log file and optionally to stdout
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" | tee -a "${BACKUP_LOG_FILE}"
}

die() {
    # Log and exit
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" | tee -a "${BACKUP_LOG_FILE}"
    exit 1
}

# ------------------------------------------------------------
#  Environment loading
# ------------------------------------------------------------
environment() {
    # Loads environment variables from .env
    local ENV_FILE=${_SCRIPT_DIR}/.env
    if [ ! -f ${ENV_FILE} ]
    then
        die "No ${ENV_FILE} file found, craft one from ${ENV_FILE}.template"
    fi
    # . for bash, zsh, ksh, (d)ash. source for (t)csh
    . ${ENV_FILE}
    mkdir -p ${BACKUP_DIR}
}

create_backup_dir() {
    # Creates a local backup dir if missing
    mkdir -p ${BACKUP_DIR}
}

create_current_backup_dir() {
    # Creates a ${BACKUP_DIR}/YYYY-mm-dd for the current run of the script
    mkdir -p ${CURRENT_BACKUP_DIR}
}

# ------------------------------------------------------------
#  Marker/lock file
# ------------------------------------------------------------
check_running() {
    # if marker/lock file ${RUNNING_FILE} exists
    if [ -f ${RUNNING_FILE} ]
    then
        die "Another copy of this file may be running. Stop it, remove ${RUNNING_FILE} and repeat. Exiting"
    fi
}

create_running() {
    # creates a marker/lock file ${RUNNING_FILE}
    touch ${RUNNING_FILE}
}

rm_running() {
    # removes the marker/lock file ${RUNNING_FILE}
    rm ${RUNNING_FILE}
}

# ------------------------------------------------------------
#  Back the running VM up
# ------------------------------------------------------------
backup_running_vm() {
    # Exports VM configuration (XML) and copies disks
    local VM_NAME=${1}
    # Dump VM config
    virsh --connect qemu:///system dumpxml ${VM_NAME} > ${CURRENT_BACKUP_DIR}/${VM_NAME}.xml || die "Failed to dump an XML config for ${VM_NAME}"
    local DOMBLKLIST=`virsh --connect qemu:///system domblklist ${VM_NAME} --details | grep disk || die "Could not parse disk list for ${VM_NAME}" `

    local DISK_NAMES=`printf "${DOMBLKLIST}\n" | tr -s ' ' | cut -d ' ' -f 4 | tr '\n' ' ' | sed 's/[[:space:]]*$//'`

    # Build backup task xml
    local BACKUP_TASK_XML="<domainbackup>\n    <disks>"
    for DISK_NAME in ${DISK_NAMES}
    do
        BACKUP_TASK_XML="${BACKUP_TASK_XML}\n        <disk name='${DISK_NAME}' type='file'>\n            <target file='${CURRENT_BACKUP_DIR}/${VM_NAME}-${DISK_NAME}.qcow2'/>\n                <driver type='qcow2'/>\n        </disk>\n"
    done
    BACKUP_TASK_XML="${BACKUP_TASK_XML}    </disks>\n</domainbackup>"

    # persist backup task xml to a file
    local BACKUP_TASK_FILE=${CURRENT_BACKUP_DIR}/${VM_NAME}-backup-task.xml
    printf "${BACKUP_TASK_XML}\n" > ${BACKUP_TASK_FILE}

    # launch
    log "${VM_NAME} backup start"
    virsh --connect qemu:///system backup-begin ${VM_NAME} --backupxml ${BACKUP_TASK_FILE} ||
            die "Failed to start backup for ${VM_NAME}"

    # wait for backup completion
    while :; do
        if virsh --connect qemu:///system domjobinfo ${VM_NAME} | grep -q "None"
        then
            break
        fi
        sleep 10s
    done
    log "${VM_NAME} backup finish"
}

# ------------------------------------------------------------
#  Back the VMs up
# ------------------------------------------------------------
backup_vms() {
    log "Backup start"
    for VM_NAME_TO_BACK_UP in ${VM_NAMES_TO_BACK_UP}
    do
        if virsh --connect qemu:///system domstate ${VM_NAME_TO_BACK_UP} | grep -q "running"
        then
           backup_running_vm ${VM_NAME_TO_BACK_UP}
        else
            log "${VM_NAME_TO_BACK_UP} is not running, skipping"
        fi
    done
    log "Backup finish"
}

# ------------------------------------------------------------
#  Kill the the backup jobs
# ------------------------------------------------------------
kill_backup_jobs() {
    log "Kill backup jobs start"
    for VM_NAME_TO_BACK_UP in ${VM_NAMES_TO_BACK_UP}
    do
        if virsh --connect qemu:///system domstate ${VM_NAME_TO_BACK_UP} | grep -q "running"
        then
           virsh --connect qemu:///system domjobabort ${VM_NAME_TO_BACK_UP}
           log "${VM_NAME_TO_BACK_UP} backup job killed"
        else
            log "${VM_NAME_TO_BACK_UP} is not running, skipping"
        fi
    done
    log "Kill backup jobs finish"
}
