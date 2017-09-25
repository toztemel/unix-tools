#!/bin/sh

if [ -z "$1" ]; then
    echo -e "Please type hostname: \c"
        read hostname
        if [ -z "$hostname" ]; then
                echo "Error: Unable to determine hostname"
                exit 1
        fi
        HOSTNAME=$hostname
else
        HOSTNAME=$1
fi

sed -i.bak "/$HOSTNAME/d" /h/.ssh/known_hosts
