#!/bin/sh

# Set variables
GITHUB_LINK="https://raw.githubusercontent.com/mbrother2/backuptogoogle/master"
BUTGG_CONF="${HOME}/.gdrive/butgg.conf"
DF_BACKUP_DIR="${HOME}/backup"
DF_LOG_FILE="${HOME}/.gdrive/butgg.log"
DF_DAY_REMOVE="7"
GDRIVE_BIN="${HOME}/bin/gdrive"
GDRIVE_TOKEN="${HOME}/.gdrive/token_v2.json"
CRON_BACKUP="${HOME}/bin/cron_backup.sh"
SETUP_FILE="${HOME}/bin/butgg.sh"
CRON_TEMP="${HOME}/.gdrive/old_cron"
SECOND_OPTION=$2

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

# Check MD5 of downloaded file
check_md5sum(){
    curl -o $2 ${GITHUB_LINK}/$1
    ORIGIN_MD5=`curl -s ${GITHUB_LINK}/MD5SUM | grep $1 | awk '{print $1}'`
    if [ "${OS}" == "CentOS" ] || [ "${OS}" == "Ubuntu" ]
    then
        LOCAL_MD5=`md5sum $2 | awk '{print $1}'`
    else
        LOCAL_MD5=`md5 $2 | awk '{print $4}'`
    fi
    if [ "${ORIGIN_MD5}" == "${LOCAL_MD5}" ]
    then
        show_write_log "Check md5sum for file $1 successful"
    else
        show_write_log "`change_color red [CHECKS][FAIL]` Can not verify md5sum for file $1. Exit!"
        exit 1
    fi
}

# Check log file
check_log_file(){
    if [ ! -f ${BUTGG_CONF} ]
    then
        LOG_FILE=${DF_LOG_FILE}
    else
        LOG_FILE=`cat ${BUTGG_CONF} | grep "^LOG_FILE" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        if [ "${LOG_FILE}" == "" ]
        then
            LOG_FILE=${DF_LOG_FILE}
            show_write_log "---"
            show_write_log "`change_color yellow [WARNING]` LOG_FILE does not exist. Use default config"
        else
            show_write_log "---"
        fi
    fi
}

# Write log
show_write_log(){
    echo "`date "+[ %d/%m/%Y %H:%M:%S ]"` $1" | tee -a ${LOG_FILE}
}

# Create necessary directory
create_dir(){
    if [ ! -d ${HOME}/$1 ]
    then
        mkdir -p ${HOME}/$1
    fi
    if [ ! -d ${HOME}/$1 ]
    then
        echo "Can not create directory ${HOME}/$1. Exit"
        exit 1
    fi
    echo 1 >> ${HOME}/$1/test.txt
    if [ $? -ne 0 ]
    then
        echo "Can not write to ${HOME}/$1. Exit"
        exit 1
    fi
    rm -f ${HOME}/$1/test.txt
}

# Prepare setup
pre_setup(){
    create_dir bin
    create_dir .gdrive
}

# Check network
check_network(){
    show_write_log "Cheking network..."
    if ping -c 1 raw.githubusercontent.com > /dev/null
    then
        show_write_log "Connect Github successful"
    else
        show_write_log "`change_color red [CHECKS][FAIL]` Can not connect to Github file, please check your network. Exit"
        exit 1
    fi
    if ping -c 1 dl.google.com > /dev/null
    then
        show_write_log "Connect Google successful"
    else
        show_write_log "`change_color red [CHECKS][FAIL]` Can not connect to Github file, please check your network. Exit"
        exit 1
    fi
}

# Detect OS
detect_os(){
    show_write_log "Checking OS..."
    if [ -f /etc/redhat-release ]
    then
        OS="CentOS"
        GO_FILE="go1.12.5.linux-amd64"
    elif [ -f /usr/bin/lsb_release ]
    then
        OS="Ubuntu"
        GO_FILE="go1.12.5.linux-amd64"
    elif [ -f /etc/freebsd-update.conf ]
    then
        OS="FreeBSD"
        GO_FILE="go1.12.5.freebsd-amd64"
    else
        show_write_log "Sorry! We do not support your OS. Exit"
        exit 1
    fi
    show_write_log "OS supported"
}

# Download file from Github
download_file(){
    show_write_log "Downloading script cron file from github..."
    check_md5sum cron_backup.sh "${CRON_BACKUP}"
    show_write_log "Downloading setup file from github..."
    check_md5sum butgg.sh "${SETUP_FILE}"
    chmod 755 ${CRON_BACKUP} ${SETUP_FILE}
}

# Build GDRIVE_BIN
build_gdrive(){
    which git
    if [ $? -ne 0 ]
    then
        echo "Command git not found. Trying to install git..."
        if [ "${OS}" == "CentOS" ]
        then
            yum -y install git
        elif [ "${OS}" == "Ubuntu" ]
        then
            apt-get install git
        else
            pkg install -y install git
        fi
        which git
        if [ $? -ne 0 ]
        then
            echo "Command git not found. Please install git first."
            exit 1
        fi
    fi
    cd $HOME/bin
    show_write_log "Downloading go from Google..."
    curl -o ${GO_FILE}.tar.gz https://dl.google.com/go/${GO_FILE}.tar.gz
    show_write_log "Extracting go lang..."
    tar -xf ${GO_FILE}.tar.gz
    show_write_log "Cloning gdrive project from Github..."
    rm -rf gdrive
    git clone https://github.com/gdrive-org/gdrive.git
    show_write_log "Build your own gdrive!"
    echo "Please go to URL to create your own Google credential:"
    echo "https://github.com/mbrother2/backuptogoogle/wiki/Create-own-Google-credential-step-by-step"
    read -p " Your Google API client_id: " gg_client_id
    read -p " Your Google API client_secret: " gg_client_secret
    if [ "${OS}" == "CentOS" ] || [ "${OS}" == "Ubuntu" ]
    then
        sed -i "s#^const ClientId =.*#const ClientId = \"${gg_client_id}\"#g" $HOME/bin/gdrive/handlers_drive.go
        sed -i "s#^const ClientSecret =.*#const ClientSecret = \"${gg_client_secret}\"#g" $HOME/bin/gdrive/handlers_drive.go
    else
        sed -i ".${TODAY}" "s#^const ClientId =.*#const ClientId = \"${gg_client_id}\"#g" $HOME/bin/gdrive/handlers_drive.go
        sed -i ".${TODAY}" "s#^const ClientSecret =.*#const ClientSecret = \"${gg_client_secret}\"#g" $HOME/bin/gdrive/handlers_drive.go
    fi
    show_write_log "Building gdrive..."
    cd $HOME/bin/gdrive
    $HOME/bin/go/bin/go get github.com/prasmussen/gdrive
    $HOME/bin/go/bin/go build -ldflags '-w -s'
    if [ $? -ne 0 ]
    then
        show_write_log "`change_color red [ERROR]` Can not build gdrive. Exit"
        exit 1
    else
        show_write_log "Build gdrive successful. Gdrive bin locate here ${GDRIVE_BIN} "
    fi
    mv $HOME/bin/gdrive/gdrive $HOME/bin/gdrive.bin
    chmod 755 $HOME/bin/gdrive
    rm -f $HOME/bin/${GO_FILE}.tar.gz
    rm -rf $HOME/bin/go
    rm -rf $HOME/bin/gdrive
    mv $HOME/bin/gdrive.bin $HOME/bin/gdrive
}

# Setup gdrive credential
setup_credential(){
    show_write_log "Setting up gdrive credential..."
    if [ "${SECOND_OPTION}" == "credential" ]
    then
        if [ -f ${GDRIVE_TOKEN} ]
        then
            rm -f ${GDRIVE_TOKEN}
        fi
    fi
    ${GDRIVE_BIN} about
    if [ $? -ne 0 ]
    then
        show_write_log "`change_color yellow [WARNING]` Can not create gdrive credential. Please run \"${GDRIVE_BIN} about\" to create it after"
        sleep 3
    else
        show_write_log "Setup gdrive credential successful"
    fi
}

# Set up config file
setup_config(){
    show_write_log "Setting up config file..."
    read -p " Which directory do you want to upload to Google Drive?(default ${DF_BACKUP_DIR}): " BACKUP_DIR
    read -p " How many days you want to keep backup on Google Drive?(default ${DF_DAY_REMOVE}): " DAY_REMOVE    
    if [ -z "${BACKUP_DIR}" ]
    then
        BACKUP_DIR="${DF_BACKUP_DIR}"
    fi
    if [ -z "${DAY_REMOVE}" ]
    then
        DAY_REMOVE="${DF_DAY_REMOVE}"
    fi
    echo "LOG_FILE=${LOG_FILE}" > ${BUTGG_CONF}
    echo "BACKUP_DIR=${BACKUP_DIR}" >> ${BUTGG_CONF}
    echo "DAY_REMOVE=${DAY_REMOVE}" >> ${BUTGG_CONF}
    if [ $? -ne 0 ]
    then
        show_write_log "`change_color red [ERROR]` Can not write config to file ${BUTGG_CONF}. Please check permission of this file. Exit"
        exit 1
    else
        if [ ! -d ${BACKUP_DIR} ]
        then
            show_write_log "`change_color yellow [WARNING]` Directory ${BACKUP_DIR} does not exist! Ensure you will be create it after."
            sleep 3
        fi
        show_write_log "Setup config file successful"
    fi       
}

# Set up cron backup
setup_cron(){
    show_write_log "Setting up cron backup..."
    crontab -l > ${CRON_TEMP}
    CHECK_CRON=`cat ${CRON_TEMP} | grep -c "cron_backup.sh"`
    if [ ${CHECK_CRON} -eq 0 ]
    then
        echo "PATH=$PATH" >> ${CRON_TEMP}
        echo "0 0 * * * sh ${CRON_BACKUP} >/dev/null 2>&1" >> ${CRON_TEMP}
        crontab ${CRON_TEMP}
        if [ $? -ne 0 ]
        then
            show_write_log "Can not setup cronjob to backup! Please check again"
            SHOW_CRON="`change_color yellow [WARNING]` Can not setup cronjob to backup"
        else
            show_write_log "Setup cronjob to backup successful"
            SHOW_CRON="0 0 * * * sh ${CRON_BACKUP} >/dev/null 2>&1"
        fi
    else
        show_write_log "Cron backup existed. Skip"
        SHOW_CRON=`cat ${CRON_TEMP} | grep "cron_backup.sh"`
    fi
    rm -f  ${CRON_TEMP}
}

# Show information
show_info(){
    echo ""
    if [ "${SECOND_OPTION}" == config ]
    then
        show_write_log "+-----"
        show_write_log "| SUCESSFUL! Your information:"
        show_write_log "| Backup dir      : ${BACKUP_DIR}"
        show_write_log "| Keep backup     : ${DAY_REMOVE} days"
        show_write_log "| Config file     : ${BUTGG_CONF}"
        show_write_log "+-----"
    else
        show_write_log "+-----"
        show_write_log "| SUCESSFUL! Your information:"
        show_write_log "| Backup dir      : ${BACKUP_DIR}"
        show_write_log "| Config file     : ${BUTGG_CONF}"
        show_write_log "| Log file        : ${LOG_FILE}"
        show_write_log "| Keep backup     : ${DAY_REMOVE} days"
        show_write_log "| butgg.sh file   : ${SETUP_FILE}"
        show_write_log "| Cron backup file: ${CRON_BACKUP}"
        show_write_log "| Gdrive bin file : ${GDRIVE_BIN}"
        show_write_log "| Cron backup     : ${SHOW_CRON}"
        show_write_log "| Google token    : ${GDRIVE_TOKEN}"
        show_write_log "+-----"

        echo ""
        echo " If you get trouble when use butgg.sh please report here:"
        echo " https://github.com/mbrother2/backuptogoogle/issues"
    fi
}

_setup(){
    check_log_file
    if [ -z "${SECOND_OPTION}" ]
    then
        pre_setup
        check_network
        detect_os
        download_file
        build_gdrive
        setup_credential
        setup_config
        setup_cron
        show_info
    else
        case ${SECOND_OPTION} in
            config)
                setup_config
                show_info
                ;;
            credential)
                setup_credential
                ;;
            only-build)
                pre_setup
                check_network
                detect_os
                build_gdrive
                ;;
            no-build)
                pre_setup
                check_network
                detect_os
                download_file
                setup_credential
                setup_config
                setup_cron
                show_info
                ;;
            no-update)
                pre_setup
                check_network
                detect_os
                build_gdrive
                setup_credential
                setup_config
                setup_cron
                show_info
                ;;
            *)
                show_write_log "No such command: ${SECOND_OPTION}. Please use butgg.sh --help"
                ;;
        esac
    fi
}

_update(){
    check_log_file
    pre_setup
    check_network
    detect_os
    download_file
}

_uninstall(){
    check_log_file
    show_write_log "Removing all butgg.sh scripts..."
    rm -f ${GDRIVE_BIN} ${CRON_BACKUP} ${SETUP_FILE}
    if [ $? -ne 0 ]
    then
        show_write_log "Can not remove all butgg.sh scripts. Please check permission of these files"
    else
        show_write_log "Remove all butgg.sh scripts successful"
    fi
    read -p " Do you want remove ${HOME}/.gdrive directory?(y/n) " REMOVE_GDRIVE_DIR
    if [ "${REMOVE_GDRIVE_DIR}" == "y" ] || [ "${REMOVE_GDRIVE_DIR}" == "Y" ]
    then
        rm -rf ${HOME}/.gdrive
        if [ $? -ne 0 ]
        then
            show_write_log "Can not remove directory ${HOME}/.gdrive. Please check permission of this directory"
        else
            echo "Remove directory ${HOME}/.gdrive successful"
        fi
    else
        show_write_log "Skip remove ${HOME}/.gdrive directory"
    fi
}

_help(){
    echo "butgg.sh - Backup to Google Drive solution"
    echo ""
    echo "Usage: butgg.sh [options] [command]"
    echo ""
    echo "Options:"
    echo "  --help       show this help message and exit"
    echo "  --setup      setup or reset all scripts & config file"
    echo "    config     only setup config"
    echo "    credential only setup credential"
    echo "    only-build only build gdrive bin"
    echo "    no-build   setup butgg without build gdrive"
    echo "    no-update  setup butgg without update script"
    echo "  --update     update to latest version"
    echo "  --uninstall  remove all butgg scripts and .gdrive directory"
}

# Main functions
case $1 in
    --help)      _help ;;
    --setup)     _setup ;;
    --update)    _update ;;
    --uninstall) _uninstall ;;
    *)           echo "No such option: $1. Please use butgg.sh --help" ;;
esac