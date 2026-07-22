#!/bin/sh

# DESCRIPTION:
#   Backs libvirtd machines up.
#
# USAGE:
#   ./bc.sh
#
# OPTIONS:
#   no options intended
#
# SEE ALSO:
#   https://libvirt.org/kbase/live_full_disk_backup.html
#
# NOTE:
#   `virsh --connect qemu:///system domjobabort ${VM_NAME}` aborts backup task for a given ${VM_NAME}

# append to ${BACKUP_LOG_FILE}
log() {
    printf "$(date '+%Y-%m-%d %H:%M:%S') - ${1}\n" | tee -a ${BACKUP_LOG_FILE}
}

# Loads environment variables from .env
environment() {
    # . for bash, zsh, ksh, (d)ash. source for (t)csh
    if [ ! -f ./.env ]
    then
        printf "No .env file found, craft one from .env.template\n"
        exit 1
    fi
    . ./.env
    mkdir -p ${BACKUP_DIR}
}

# Creates a local backup dir if missing
create_backup_dir() {
    mkdir -p ${BACKUP_DIR}
}

# Creates a ${BACKUP_DIR}/YYYY-mm-dd for the current run of the script
create_current_backup_dir() {
    mkdir -p ${CURRENT_BACKUP_DIR}
}

# if marker file ${RUNNING_FILE} exists
check_running() {
    if [ -f ${RUNNING_FILE} ]
    then
        log "Another copy of this file may be running. Stop it, remove ${RUNNING_FILE} and repeat. Exiting\n"
        exit 1
    fi
}

# creates a marker file ${RUNNING_FILE}
create_running() {
    touch ${RUNNING_FILE}
}

# removes the marker file ${RUNNING_FILE}
rm_running() {
    rm ${RUNNING_FILE}
}

backup_vm() {
    local VM_NAME=${1}
    # Dump VM config
    virsh --connect qemu:///system dumpxml ${VM_NAME} > ${CURRENT_BACKUP_DIR}/${VM_NAME}.xml
    local DOMBLKLIST=`virsh --connect qemu:///system domblklist ${VM_NAME} --details | grep disk`

    local DISK_NAMES=`printf "${DOMBLKLIST}\n" | tr -s ' ' | cut -d ' ' -f 4 | tr '\n' ' ' | sed 's/[[:space:]]*$//'`

    # Build backup task xml
    local BACKUP_TASK_XML="<domainbackup>\n    <disks>"
    for DISK_NAME in ${DISK_NAMES}
    do
        BACKUP_TASK_XML="${BACKUP_TASK_XML}\n        <disk name='${DISK_NAME}' type='file'>\n            <target file='/${CURRENT_BACKUP_DIR}/${VM_NAME}-${DISK_NAME}.qcow2'/>\n                <driver type='qcow2'/>\n        </disk>\n"
    done
    BACKUP_TASK_XML="${BACKUP_TASK_XML}    </disks>\n</domainbackup>"

    # persist backup task xml to a file
    local BACKUP_TASK_FILE=${CURRENT_BACKUP_DIR}/${VM_NAME}-backup-task.xml
    printf "${BACKUP_TASK_XML}\n" > ${BACKUP_TASK_FILE}

    # launch backup
    virsh --connect qemu:///system backup-begin ${VM_NAME} --backupxml ${BACKUP_TASK_FILE}

    # wait for backup completion
    while true; do
        if `virsh --connect qemu:///system domjobinfo ${VM_NAME} | grep -q "None"`
        then
            break
        fi
        sleep 10s
    done
    log "${VM_NAME} backup completed"
}

# Returns space separated list for a ${1} VM name
list_vm_hard_disks() {
    local VM_NAME=${1}
    local DOMBLKLIST=`virsh --connect qemu:///system domblklist ${VM_NAME} --details | grep disk`
    local DISK_NAMES=`printf "${DOMBLKLIST}\n" | tr -s ' ' | cut -d ' ' -f 4 | tr '\n' ' ' | sed 's/[[:space:]]*$//'`
    printf "${DISK_NAMES}"
}

# main function to prevent occasional environment pollution
closure() {
    set -Eeuo pipefail
    #set -x # debug
    environment
    create_backup_dir # at this point log file is available

    local LAUNCH_DATE=`date +%Y-%m-%d`
    local CURRENT_BACKUP_DIR=${BACKUP_DIR}/${LAUNCH_DATE}

    check_running
    create_current_backup_dir

    create_running

    for VM_NAME_TO_BACK_UP in ${VM_NAMES_TO_BACK_UP}
    do
        if `virsh --connect qemu:///system domstate ${VM_NAME_TO_BACK_UP} | grep -q "running"`
        then
           backup_vm ${VM_NAME_TO_BACK_UP}
        else
            log "${VM_NAME_TO_BACK_UP} is not running, skipping\n"
        fi
    done

    rm_running

    log "Backup done"
}

closure
