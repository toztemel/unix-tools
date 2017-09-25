################ Purpose : To quickly find out health status on a server        ################
################ Tested on RHEL6.3/RHEL5.10/SLES11/Centos6 64bit Vms.             ################

#!/bin/bash

clear
echo -e "";
echo -e "**********************************************WELCOME************************************************************";
#reading user choice whether to continue or terminate program
ans=y;
printf "Enter your choice of action to invoke Health Check on current Node \"y\" OR \"n\" :";
read ans;
ans=$(echo $ans | tr 'a-z' 'A-Z');
if [ "$ans" != "Y" ]
then
    echo -e "\nTerminating program on user request... Bye!"
    exit 1
fi


#check for the existence of "mpstat" command OR sysstat package
#printf "\nChecking the availability \"mpstat\" OR \"sysstat\" package..........";
if [ ! -x /usr/bin/mpstat ]
then
    printf "\nError : Either \"mpstat\" command not available OR \"sysstat\" package is not properly installed. Please make sure this package is installed and working properly!, then run this script.\n\n"
    exit 1
fi
#printf "\t\tPassed \n";

mount | egrep -viw "sys|proc|udev|tmpfs|devpts|none|iso9660|fuse|swap|sunrpc" > /tmp/mounted.fs.out

echo -e ""
D="----------------------------------"
echo -e "$D Health Status Report $D"


function Application_Check {
    NODE_TYPE="Controller"
    declare -a WME=`sudo /opt/msv/bin/mscli -c 'list-dn' | grep -i CIL | grep -i VmInstance | awk -F "VmInstance=" '{print $2}'`
    #echo ${WME[*]}
    a1=`echo ${WME[*]} | wc -w`
    declare -i w=a1+1
    declare -i d=w*2
    declare -a SRE=`sudo /opt/msv/bin/mscli -c 'get-all-services --location' | grep -A $d -i CIL_PersistenceStorage | grep weight | awk -F ":" '{print $2}' | awk -F "," '{print $1}' | sed -s 's/"//g'`
    b=`echo ${SRE[*]} | wc -w`
    echo -e "######################## Checking CIL entry in Service Registry ################################"
    echo ""
    if [ $b != 0 ]
    then
        echo -e "######################## CIL entry present in Service Registry ##################### \033[0;32m [OK]  \033[0m\n"
    else
        echo -e "######################## Unable to Determine CIL Location from Service Registry  ##################### \033[0;31m [ERROR]  \033[0m\n"
    #exit 1
    fi

    if [ $b == 0 ]
    then
        echo -e "######################## Unable to Determine CIL Location: Can not check CIL Connection  ##################### \033[0;31m [ERROR]  \033[0m\n"
    else
        for (( c = 1; c <= $a1; c ++ ))
        do
            n=`echo ${SRE[*]} | awk '{print $'''$c'''}'`
            nc $n 12742 -w 3
            x=`echo $?`
            if [ $x == 0 ]
            then
                echo -e "#############   CIL Connection Available towards node `echo $n`   ##################### \033[0;32m [OK] \033[0m\n"
            else
                echo -e "#############   CIL Connection Down towards `echo$n`     ##################### \033[0;31m [ERROR]  \033[0m\n"
            fi
        done
    fi
    sleep 2


    KARAF_PROCESS_CHECK_COMMAND="ps -eaf | grep -i karaf | grep -v grep"
    ######################## Checking Karaf Status ###################################

    KARAF_CHECK=`eval $KARAF_PROCESS_CHECK_COMMAND`
    #echo $KARAF_CHECK

    if [ $? -eq 0 ]
    then
        echo -e "#############   Karaf Instance Running   ##################### \033[0;32m [OK] \033[0m\n"
	outputFile='/tmp/healthCheck_output'
	rm ${outputFile}
        sudo ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa_karaf -p 13122 karaf@localhost bundle:list | grep -iv "ACTIVE\|FACTORY" | awk -F \| '{print $5}' | tail -n +4 > ${outputFile}
        KARAF_BUNDLE_CHECK1=`cat ${outputFile} | wc -l`
        if [ $KARAF_BUNDLE_CHECK1 == 0 ]
        then
            echo -e "######################## All Bundles Active ##################### \033[0;32m [OK]  \033[0m\n"
        else
            echo -e "######################## Bundles in Inactive State  ##################### \033[0;31m [ERROR]  \033[0m"
            cat ${outputFile}
	    rm ${outputFile}
        fi
    else
        echo -e "#############   Karaf Instance Down      ##################### \033[0;31m [ERROR]  \033[0m\n"
    fi
    sleep 2
}


echo -e "\nRunning Application Check"
echo -e "---------------------------\n"
Application_Check

sleep 3
## Reporting basic details of the system
if [ -e /usr/bin/lsb_release ]
then
    echo -e "\nOperating System :" `lsb_release -d | awk -F: '{print $2}' | sed -e 's/^[ \t]*//'`
else
    echo -e "\nOperating System :" `cat /etc/system-release`
fi
echo -e "Kernel Version :"`uname -r`

sleep 3
uptime | awk '{print $2" "$3" "$4}' | sed -e 's/,.*//g' | grep day 2>&1 > /dev/null
if [ `echo $?` != 0 ]
then
    echo -e "System Uptime :"`uptime | awk '{print $2" "$3" "$4}' | sed -e 's/,.*//g'`" hours"
else
    echo -e "System Uptime : "`uptime | awk '{print $2" "$3" "$4}' | sed -e 's/,.*//g'`
fi

sleep 3
## Check for any read-only file system
echo -e "\nChecking If Any Read-only File System"
echo -e "$D"
if [ `cat /tmp/mounted.fs.out | awk '{print $6}' | grep ro | wc -l` -ge 1 ];
then
    cat /tmp/mounted.fs.out | grep -w 'ro'
else
    echo -e "No read-only file systems found"
fi

sleep 3
## Check for currently mounted file systems
echo -e "\n\nChecking For Currently Mounted File Systems"
echo -e "$D"
cat /tmp/mounted.fs.out | column -t

sleep 3
## Check disk usage on all mounted file systems.
echo -e "\n\nChecking For Disk Usage On Mounted File Systems"
echo -e "$D$D"
echo -e "( 0-90% = OK/HEALTHY, 90-95% = WARNING, 95-100% = CRITICAL )"
echo -e "$D$D"
echo -e "Mounted File System Utilization (Percentage Used):\n"
#df -PTh|egrep -v "tmpfs|iso9660|Avail|udev"|awk '{print $7" "$6}'|column -t

df -PTh | egrep -v "tmpfs|iso9660|Avail" | awk '{print $7}' > /tmp/s1.out
df -PTh | egrep -v "tmpfs|iso9660|Avail" | awk '{print $6}' | sed -e 's/%//g' > /tmp/s2.out
> /tmp/s3.out
for i in `cat /tmp/s2.out`;
do
    if [ $i -ge 95 ];
    then
        #echo $i"% ---- CRITICAL" >> /tmp/s3.out;
        echo -e $i"%" "\e[47;31m ------ CRITICAL \e[0m" >> /tmp/s3.out;
    elif [[ $i -ge 90 && $i -lt 95 ]];
    then
        #echo $i"% ---- WARNING" >> /tmp/s3.out;
        echo -e $i"%" "\e[43;31m ------ WARNING \e[0m" >> /tmp/s3.out;
    else
        #echo $i"% ---- OK/HEALTHY" >> /tmp/s3.out;
        echo -e $i"%" "########## \033[0;32m [OK/HEALTHY]  \033[0m #########" >> /tmp/s3.out;
    fi
done
paste -d"\t" /tmp/s1.out /tmp/s3.out

sleep 3
## Check for any zombie processes.
echo -e "\n\nChecking For Zombie Processes"
echo -e "$D"
if [ `ps -eo stat | grep -w Z | wc -l` -ge 1 ];
then
    echo -e "Number of zombie process on the system are :" `ps -eo stat | grep -w Z | wc -l`
else
    echo -e "No zombie processes on the system"
fi

sleep 3
## Check Inode usage.
echo -e "\n\nChecking For INode Usage"
echo -e "$D$D"
echo -e "( 0-90% = OK/HEALTHY, 90-95% = WARNING, 95-100% = CRITICAL )"
echo -e "$D$D"
echo -e "INode Utilization (Percentage Used):\n"

df -Phi | egrep -v "tmpfs|iso9660|IUse|media|udev" | awk '{print $6}' > /tmp/s1.out
df -Phi | egrep -v "tmpfs|iso9660|IUse|media|udev" | awk '{print $5}' | sed -e 's/%//g' > /tmp/s2.out
> /tmp/s3.out
for i in `cat /tmp/s2.out`;
do
    if [ $i -ge 95 ];
    then
        #echo $i"% ---- CRITICAL" >> /tmp/s3.out;
        echo -e $i"%" "\e[47;31m ------ CRITICAL \e[0m" >> /tmp/s3.out;
    elif [[ $i -ge 90 && $i -lt 95 ]];
    then
        #echo $i"% ---- WARNING" >> /tmp/s3.out;
        echo -e $i"%" "\e[43;31m ------ WARNING \e[0m" >> /tmp/s3.out;
    else
        #echo $i"% ---- OK/HEALTHY" >> /tmp/s3.out;
        echo -e $i"%" "################ \033[0;32m [OK/HEALTHY]  \033[0m #############" >> /tmp/s3.out;
    fi
done
paste -d"\t" /tmp/s1.out /tmp/s3.out

sleep 3
## Check for RAM Utilization
echo -e "\n\nChecking Memory Details"
echo -e "$D"
echo -e "Total RAM in MB : "$((`grep -w MemTotal /proc/meminfo | awk '{print $2}'` / 1024))", in GB :"$((`grep -w MemTotal /proc/meminfo | awk '{print $2}'` / 1024 / 1024))
echo -e "Used RAM in MB  :"$((`free -m | grep -w Mem: | awk '{print $3}'`))", in GB :"$((`free -m | grep -w Mem: | awk '{print $3}'` / 1024))
echo -e "Free RAM in MB  :"$((`grep -w MemFree /proc/meminfo | awk '{print $2}'` / 1024))" , in GB :"$((`grep -w MemFree /proc/meminfo | awk '{print $2}'` / 1024 / 1024))

sleep 3
## Check for SWAP Utilization
echo -e "\n\nChecking SWAP Details"
echo -e "$D"
echo -e "Total Swap Memory in MB : "$((`grep -w SwapTotal /proc/meminfo | awk '{print $2}'` / 1024))", in GB :"$((`grep -w SwapTotal /proc/meminfo | awk '{print $2}'` / 1024 / 1024))
echo -e "Swap Free Memory in MB : "$((`grep -w SwapFree /proc/meminfo | awk '{print $2}'` / 1024))", in GB :"$((`grep -w SwapFree /proc/meminfo | awk '{print $2}'` / 1024 / 1024))

sleep 3
## Check for Processor Utilization (current data)
echo -e "\n\nChecking For Processor Utilization"
echo -e "$D"
echo -e "Manufacturer: "`grep -w "vendor_id" /proc/cpuinfo | uniq | awk '{print $3}'`
echo -e "Processor Model: "`grep -w "model name" /proc/cpuinfo | uniq | awk -F":" '{print $2}' | sed 's/^ //g'`
echo -e "Number of processors/cores: "`cat /proc/cpuinfo | grep -wc processor`
echo -e "\nCurrent Processor Utilization Summary :\n"
mpstat | tail -2

sleep 3
## Check for load average (current data)
echo -e "\n\nChecking For Load Average"
echo -e "$D"
echo -e "Current Load Average :" `uptime | grep -o "load average.*" | awk '{print $3" " $4" " $5}'`

CPU_USAGE=`sar 1 1 | tail -1 | awk '{print $8}'`
e=`echo ${CPU_USAGE%%.*}`
#echo $e
if [ $e -lt 33 ]
then
    echo -e "\n############### CPU under Load ##################  \033[0;31m [ALARMING]  \033[0m\n"
else
    echo -e "\n############## CPU Health check Execution ################### \033[0;32m [OK] \033[0m\n"
fi

sudo rm -rf /tmp/s1.out /tmp/s2.out /tmp/s3.out /tmp/mounted.fs.out
exit
echo -e "\n"



