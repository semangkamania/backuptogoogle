#!/bin/sh

# Setup variables
BUTGG_CONF="${HOME}/.gdrive/butgg.conf"
GDRIVE_BIN="${HOME}/bin/gdrive"
DF_BACKUP_DIR="${HOME}/backup"
DF_LOG_FILE="${HOME}/.gdrive/butgg.log"
DF_DAY_REMOVE="7"
FIRST_OPTION=$1

# Date variables
TODAY=`date +"%d_%m_%Y"`

# Color variables
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
REMOVE='\e[0m'

# Change color of words
change_color(){
    case $1 in
         green) echo -e "${GREEN}$2${REMOVE}";;
           red) echo -e "${RED}$2${REMOVE}";;
        yellow) echo -e "${YELLOW}$2${REMOVE}";;
             *) echo "$2";;
    esac
}

# Show processing and write log
show_write_log(){
    if [ "${FIRST_OPTION}" == "-v" ]
    then
        echo `date "+[ %d/%m/%Y %H:%M:%S ]"` $1
    fi
    echo `date "+[ %d/%m/%Y %H:%M:%S ]"` $1 >> ${LOG_FILE}
}

# Check file type
check_file_type(){
    if [ -d $1 ]
    then
        FILE_TYPE="directory"
    elif [ -f $1 ]
    then
        FILE_TYPE="file"
    else
        show_write_log "`change_color red [CHECKS][FAIL]` Can not detect file type for $1. Exit"
        exit 1
    fi
}

# Detect OS
detect_os(){
    show_write_log "Checking OS..."
    if [ -f /etc/redhat-release ]
    then
        OS="CentOS"
    elif [ -f /usr/bin/lsb_release ]
    then
        OS="Ubuntu"
    elif [ -f /etc/freebsd-update.conf ]
    then
        OS="FreeBSD"
    else
        show_write_log "Sorry! We do not support your OS. Exit"
        exit 1
    fi
    show_write_log "OS supported"
}

# Write config
check_config(){
    if [ "$3" == "" ]
    then
        VAR=$1
        eval "$VAR"="$2"
        if [ $1 == LOG_FILE ]
        then
            show_write_log "---"
        fi
        show_write_log "`change_color yellow [WARNING]` $1 does not exist. Use default config"
        if [ -f ${BUTGG_CONF} ]
        then
            sed -i ".${TODAY}" "/^$1/d" ${BUTGG_CONF}
        fi
        echo "$1=$2" >> ${BUTGG_CONF}
    else
        VAR=$1
        eval "$VAR"="$3"
        if [ $1 == LOG_FILE ]
        then
            show_write_log "---"
        fi
    fi
}

# Get config
get_config(){
    if [ ! -f ${BUTGG_CONF} ]
    then
        check_config LOG_FILE ${DF_LOG_FILE}
        check_config BACKUP_DIR ${DF_BACKUP_DIR}
        check_config DAY_REMOVE ${DF_DAY_REMOVE}
    else
        LOG_FILE=`cat ${BUTGG_CONF} | grep "^LOG_FILE"   | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config LOG_FILE ${DF_LOG_FILE} ${LOG_FILE}
        BACKUP_DIR=`cat ${BUTGG_CONF} | grep "^BACKUP_DIR" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config BACKUP_DIR ${DF_BACKUP_DIR} ${BACKUP_DIR}           
        DAY_REMOVE=`cat ${BUTGG_CONF} | grep "^DAY_REMOVE" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config DAY_REMOVE ${DF_DAY_REMOVE} ${DAY_REMOVE} 
    fi
}

# Check infomations before upload to Google Drive
check_info(){
    if [ ! -d "${BACKUP_DIR}" ]
    then       
        show_write_log "`change_color red [CHECKS][FAIL]` Directory ${BACKUP_DIR} does not exist. Exit"
        exit 1
    fi
    if [ ! -f ${HOME}/.gdrive/token_v2.json ]
    then
        show_write_log "`change_color red [CHECKS][FAIL]` File ${HOME}/.gdrive/token_v2.json does not exist. Exit"
        show_write_log "Please run command: '${GDRIVE_BIN} about' to create your Google token for gdrive"
        exit 1
    else
        echo "\n" | ${GDRIVE_BIN} list >/dev/null
        if [ $? -ne 0 ]
        then
            echo ""
            show_write_log "`change_color red [CHECKS][FAIL]` File ${HOME}/.gdrive/token_v2.json exists but can not verify Google token for gdrive. Exit"
            show_write_log "Please run command: '${GDRIVE_BIN} about' to recreate your Google token for gdrive"
            exit 1
        fi
    fi
}

# Run upload to Google Drive
run_upload(){
    show_write_log "Start upload to Google Drive..."
    CHECK_BACKUP_DIR=`${GDRIVE_BIN} list -m 100000 --name-width 0 | grep -c "${TODAY}"`
    if [ ${CHECK_BACKUP_DIR} -eq 0 ]
    then
        show_write_log "Directory ${TODAY} does not exist. Creating..."
        ID_DIR=`${GDRIVE_BIN} mkdir ${TODAY} | awk '{print $2}'`
    else
        show_write_log "Directory ${TODAY} existed. Skipping..."
        ID_DIR=`${GDRIVE_BIN} list -m 100000 --name-width 0 | grep "${TODAY}" | head -1 | awk '{print $1}'`
    fi
    if [ ${#ID_DIR} -ne 33 ]
    then
        show_write_log "`change_color red [CREATE][FAIL]` Can not create directory ${TODAY}"
        exit 1
    elif [ ${CHECK_BACKUP_DIR} -eq 0 ]
    then
        show_write_log "`change_color green [CREATE]` Created directory ${TODAY} with ID ${ID_DIR}"
    else
        :
    fi
    BACKUP_DIR=`realpath ${BACKUP_DIR}`
    for i in $(ls -1 ${BACKUP_DIR})
    do
        check_file_type "${BACKUP_DIR}/$i"            
        show_write_log "Uploading ${FILE_TYPE} ${BACKUP_DIR}/$i to directory ${TODAY}..."                
        UPLOAD_FILE=`${GDRIVE_BIN} upload -p ${ID_DIR} --recursive ${BACKUP_DIR}/$i`
        if [ "${UPLOAD_FILE}" == *"Error"* ] || [ "${UPLOAD_FILE}" == *"Fail"* ]
        then
            show_write_log "`change_color red [UPLOAD][FAIL]` Can not upload backup file! ${UPLOAD_FILE}"
            show_write_log "Something wrong!!! Exit."
            exit
        else
            show_write_log "`change_color green [UPLOAD]` Uploaded ${FILE_TYPE} ${BACKUP_DIR}/$i to directory ${TODAY}"
        fi
    done
    show_write_log "Finish! All files and directories in ${BACKUP_DIR} are uploaded to Google Drive in directory ${TODAY}"
}

remove_old_dir(){
    if [ "${OS}" == "CentOS" ] || [ "${OS}" == "Ubuntu" ]
    then
        OLD_BACKUP_DAY=`date +%d_%m_%Y -d "-${DAY_REMOVE} day"`
    else
        OLD_BACKUP_DAY=`date -v-${DAY_REMOVE}d +%d_%m_%Y`
    fi
    OLD_BACKUP_ID=`${GDRIVE_BIN} list -m 100000 --name-width 0 | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
    if [ "${OLD_BACKUP_ID}" != "" ]
    then
        ${GDRIVE_BIN} delete -r ${OLD_BACKUP_ID}
        OLD_BACKUP_ID=`${GDRIVE_BIN} list -m 100000 --name-width 0 | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
        if [ "${OLD_BACKUP_ID}" == "" ]
        then
            show_write_log "`change_color green [REMOVE]` Removed directory ${OLD_BACKUP_DAY}"
        else
            show_write_log "`change_color red [REMOVE][FAIL]` Directory ${OLD_BACKUP_DAY} exists but can not remove!"
        fi
    else
        show_write_log "Directory ${OLD_BACKUP_DAY} does not exist. Nothing need remove!"
    fi
}

# Main functions
get_config
detect_os
check_info
run_upload
remove_old_dir