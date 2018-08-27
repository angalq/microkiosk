#!/bin/bash

### BEGIN INIT INFO 
# Provides: ani 
# Required-Start: $local_fs $network $syslog 
# Required-Stop: 
# Default-Start: 2 3 4 5 
# Default-Stop: 0 1 6 
# Short-Description: Start KID - Kiosk ID
# Description: The KID service enable network query
### END INIT INFO

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be executed by root" 1>&2
   exit 1
fi

# Load service functions
. /lib/lsb/init-functions

case "$1" in
start)
    log_begin_msg "Starting KID - Kiosk ID"
    value=`pgrep -f 'nc -l -v 55555'; echo $?`
    if [ "$value" -ne 0 ]
    then
        runuser -l usuario -c 'while true; do printf "KIOSK in `hostname`" | nc -l -v 55555; sleep 0.05s; done' >> /var/log/kid.log 2>&1 &
        log_end_msg $?
    else
        log_end_msg 1
        exit 1
    fi
    ;;
stop)
    log_begin_msg "Stoping KID - Kiosk ID"
    pids=`pgrep -f 'nc -l -v 55555'`
    if [ -n "$pids" ]
    then
        for i in $pids
        do
            kill -9 $i
        done
    fi
    log_end_msg 0
    ;;
*)
    echo "Use: $0 (start | stop)"
esac

