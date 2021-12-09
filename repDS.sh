#!/bin/bash
# Use this script to setup multiple DS 7.x.x servers in replication and initialize
#
# Created on 08/Dec/2021
# Author = G.Nikolaidis
# Version 1.00
#
# Before execuete the script make sure you have installed Java version 11 or later
# the unzip and netstat utility 
# include the DS-7.x.x.zip in the same directory where you execute the script
# chmod 755 the script to make it executable and execute it as root or sudo
# execute with command line argument the number of DS to deploy: ./replDS 3


clear
noOfServers=$1



# Settings
# you can change the below settings to meet your installation requirments 
#
#Destination path will be in the format /opt/ds7xRepl0, /opt/ds7xRepl1, /opt/ds7xRepl2, /opt/ds7xRepl3, /opt/ds7xReplx ...
destPath=/opt/ds7xRepl

#hostname will be in format rep0.example.com, rep1.example.com, rep2.example.com, repx.example.com
hostName=rep
domain=.example.com

#serverId will be in the format MASTER0, MASTER1, MASTER2, MASTERx
serverId=MASTER


installationProfile=ds-evaluation
generateUsers=100

#change the name of the zip file to install
#password to be used: Password1
installationZipFile=DS-7.0.2.zip
installationPassword=Password1

#Default protocol ports to be used
#on each additional server the port will be +1 ie. server0 ldapPort:1389, server1 ldapPort:1390, server2 ldapPort:1391 etc
#ldaps port server0 ldapsPort:1686, server1 ldapsPort:1687 etc  
ldapPort=1389
ldapsPort=1636
httpsPort=8443
replPort=8989
adminPort=4444


# Path of the first installed server
#
setupPath=${destPath}0/opendj
binPath=$setupPath/bin/




tput civis

# Functions
#
progressBar()
{
sleepTime=$1
while ps |grep $! &>/dev/null; do
        printf '▇'
        #printf '\u2589'
        sleep ${sleepTime}
done
printf "\n"
}



unzipMessage()
{
if [ $? -eq 0 ];then
        printf "extraction successful..Done\n"
else    
        printf "something went wrong while extracting the file!\n"
        printf "check your file might be corrupted, re download it.\n"
        printf "Installation failed!"
        tput cnorm
	exit -1
fi
}


setupMessage()
{
if [ $? -eq 0 ];then
        printf "setup DS successful..Done\n"
else    
        printf "something went wrong while setup!\n"
        printf "Installation failed!"
        tput cnorm
	exit -1
fi
}


initialiseRepMessage()
{
if [ $? -eq 0 ];then
        printf "initialise replication successful..Done\n"
else
        printf "something went wrong while initialise replication!\n"
        printf "Installation failed!"
        tput cnorm
	exit -1
fi
printf "\n"
}




# Start
#

#Check the number or replication servers to be installed
#Max number is set to 8 (this number can be changed) 
#
if [[ $noOfServers -lt 2 ]]
then
	printf "The number of servers joining replication must be more that 1!\nPlease execute the script with command line argument like ./repDS 3\nwhere 3 is the number of DS to deploy, min=2 max=8.\n"
	tput cnorm
	exit -1
fi
if [[ $noOfServers -gt 8 ]]
then
	printf "The number of installing servers will be very high and resources will be not enough!\n"
	tput cnorm
	exit -1
fi
 

printf "Installing ($niOfServers) DS7 Replication Servers.....\n"
printf "\n"



# check for Java environment
#
printf "Checking for Java environment..\n"
#printf "Java version: "; java -version 2>&1 |grep "version" | awk '{print $3}'
javaVer=`java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1`

if [[ $javaVer -lt 11 ]];then
        printf "You need to install Java version 11\n"
        printf "Execute sudo yum install java-11-openjdk\n"
        printf "Installation failed!\n"
        tput cnorm
	exit -1
else
        jdkVersion=`java -version 2>&1 |grep "version" | awk '{print $3}'`
        printf "compatible Java version $jdkVersion..Done\n"
fi




# Check if netstat is installed and then check all the ports to avoid conflicts.. 
#
netstat -V &>/dev/null

if [ $? -eq 0 ];then
        printf "netstat utility found..Done\n"
else
        printf "netstat utility not found, please use sudo yum/apt install net-tools\n"
        printf "installation aborted!\n"
        tput cnorm
	exit -1
fi

checkPorts()
{
 portCheck=$1
 noOfDS=$2
 for (( i=0; i<$noOfDS; i++ ))
 do	
	result=`netstat -tulpn |grep -w $portCheck| awk {'print $4'} |cut -c4-`
        result=`netstat -tulpn |grep -o -m 1 $portCheck`
        if [ "$result" == "$portCheck" ];then
                printf "Port $portCheck exists and there will be conflict!\n"
                printf "installation aborted!\n"
                tput cnorm
		exit -1
        else
                printf "Checking port: $portCheck ..Done\n"
        fi
	((portCheck++))
 done
}

for j in $ldapPort $ldapsPort $httpsPort $replPort $adminPort
do 
	printf "Checking protocol port: $j\n"
	checkPorts $j $noOfServers
done





#Check for existing directories
#Create new directories if there are none existing
#
for (( k=0; k<$noOfServers; k++ ))
do
        if [ -d $destPath${k} ];then
                echo; printf "Directory already exists, please delete or rename it\n"
                printf "Installation abort!\n"
                tput cnorm
		exit -1
        else
                printf "Creating directory $destPath${k}...\n"
                mkdir $destPath${k}
                if [ $? -eq 0 ];then
                        printf "Created successful..Done\n"
                else
                        printf "Can not create directory $destPath${k} check the directory permissions!\n"
                        printf "Installation failed!\n"
                        tput cnorm
			exit -1
                fi
        fi
done




# Check if unzip utility exists
#
echo
printf "Checking for unzip utility...\n"
unzipVer=`unzip -v 2>&1`
if [ $? -eq 0 ];then
        printf "uzip util..Done\n"
else
        printf "Unzip utility is not installed, you need to install it\n"
        printf "Execute sudo yum install unzip\n"
        printf "Installation failed!\n"
        tput cnorm
	exit -1
fi





# Check if DS-7.x.x.zip file exist on the directory
#
printf "Checking for zip file..\n"
if [ -f "$installationZipFile" ];then
        printf "found,$installationZipFile..ok\n"
else
        printf "Can't find $installationZipFile file, please make sure to include\n"
        printf "the file on the same directory where you execute the script\n"
        printf "Installation failed!\n"
        tput cnorm
	exit -1
fi





# Unzip files to directories
#
printf "Unzipping files to directories...\n"
for (( dir=0; dir<$noOfServers; dir++ )) 
do
        unzip $installationZipFile -d $destPath${dir} 2>&1 >/dev/null &
        progressBar 0
        unzipMessage
done




# Create deployment key
#
printf "creating DEPLOYMENT_KEY...please wait it might take some time..\n"
export installationPassword
$binPath./dskeymgr create-deployment-key --deploymentKeyPassword $installationPassword > $setupPath/DEPLOYMENT_KEY
if [ $? -eq 0 ];then
        printf "creation successful..Done\n"
else
        printf "something went wrong creating the DEPLOYMENT_KEY!\n"
        printf "Installation failed!\n"
        tput cnorm
	exit -1
fi
deploymentKey=$(cat $setupPath/DEPLOYMENT_KEY |awk '{ print $1 }')
export deploymentKey
printf "DEPLOYMENT_KEY: $deploymentKey\n"




# Insert hostNames into /etc/hosts file
#
cp /etc/hosts /etc/hosts.backup
if [ $? -eq 0 ];then
        printf "backup /etc/hosts hosts.backup..Done\n"
else
        printf "backup /etc/hosts file hosts.backup..failed!\n"
        printf "must run as root\n"
        printf "installation..failed!\n"
        tput cnorm
	exit -1
fi

for (( name=0; name<$noOfServers; name++ ))
do
cat /etc/hosts |grep "$hostName${name}$domain"
if [ $? -eq 0 ];then
        printf "hostNames already exist on /etc/hosts..Done\n"
else
        sed -i "/127.0.0.1/ s/$/ $hostName${name}$domain/" /etc/hosts
fi

done
printf "insert hostNames into /etc/hosts..Done\n"





installationText()
{
# Create INSTALLATION text
#printf "Installation instructions..\n\n\n$setupCommand\n\n\n$setupCommand2\n\n\n$initReplication\n\n\nDEPLOYMENT_KEY:$deploymentKey\nPassword: $installationPassword\n" > $setupPath/INSTALLATION
#
#ldap ldaps admin replication replication port
ld=$1
lds=$2
adm=$3
rep=$4
repb=$4

printf "Installation instructions..\n\n\n" > $setupPath/INSTALLATION

for (( b=0; b<$noOfServers; b++ ))
do
        bootStrapServers=$bootStrapServers" "--bootstrapReplicationServer" "$hostName${b}$domain:$repb
        ((repb++))
done

for (( i=0; i<$noOfServers; i++ ))
do
setupCommand="$destPath${i}/opendj/./setup --ldapPort $ld --adminConnectorPort $adm --rootUserDN "uid=admin" --rootUserPassword $installationPassword --monitorUserPassword $installationPassword --deploymentKeyPassword $installationPassword --deploymentKey $deploymentKey --enableStartTLS --ldapsPort $lds --hostName $hostName${i}$domain --serverId $serverId${i} --replicationPort $rep $bootStrapServers --profile $installationProfile --set ds-evaluation/generatedUsers:$generateUsers --acceptLicense"

printf "$setupCommand\n\n\n" >> $setupPath/INSTALLATION

((ld++))
((adm++))
((lds++))
((rep++))

done

s=0
initReplication="$binPath./dsrepl initialize --baseDN dc=example,dc=com --toAllServers --hostname $hostName${s}$domain --port $adminPort --bindDN "uid=admin" --bindPassword $installationPassword --trustStorePath $setupPath/config/keystore --trustStorePasswordFile $setupPath/config/keystore.pin --no-prompt"
printf "$initReplication\n\n\nDEPLOYMENT_KEY:$deploymentKey\nPassword: $installationPassword\n" >> $setupPath/INSTALLATION
}

#Call installation instruction function
installationText $ldapPort $ldapsPort $adminPort $replPort



executeInstallation()
{
# Execute DS setup
#
#ldap ldaps admin replication replication port
ld=$1
lds=$2
adm=$3
rep=$4
repb=$4

printf "executing DS ./setup command...\n"

for (( b=0; b<$noOfServers; b++ ))
do
        bootStrapServers=$bootStrapServers" "--bootstrapReplicationServer" "$hostName${b}$domain:$repb
        ((repb++))
done

for (( i=0; i<$noOfServers; i++ ))
do
$destPath${i}/opendj/./setup --ldapPort $ld --adminConnectorPort $adm --rootUserDN "uid=admin" --rootUserPassword $installationPassword --monitorUserPassword $installationPassword --deploymentKeyPassword $installationPassword --deploymentKey $deploymentKey --enableStartTLS --ldapsPort $lds --hostName $hostName${i}$domain --serverId $serverId${i} --replicationPort $rep $bootStrapServers --profile $installationProfile --set ds-evaluation/generatedUsers:$generateUsers --acceptLicense 2>&1 >/dev/null &

((ld++))
((adm++))
((lds++))
((rep++))

progressBar 2
setupMessage

done
}

#Call installation command
#
executeInstallation $ldapPort $ldapsPort $adminPort $replPort 




# starting DS servers
#
printf "Starting DS server$startServer\n"
for (( startServer=0; startServer<$noOfServers; startServer++ ))
do
	$destPath${startServer}/opendj/bin/./start-ds
	printf "Server$startServer started..Done\n\n\n"
done




# Initialise replication
#
s=0
printf "starting replication initialisation please wait..\n"
sleep 10
$binPath./dsrepl initialize --baseDN dc=example,dc=com --toAllServers --hostname $hostName${s}$domain --port $adminPort --bindDN "uid=admin" --bindPassword $installationPassword --trustStorePath $setupPath/config/keystore --trustStorePasswordFile $setupPath/config/keystore.pin --no-prompt
printf "Replication initialisation started..\n\n"

#Execute status command
#
sleep 20
$binPath./dsrepl status --showGroups --showReplicas --hostname $hostName${s}$domain --port $adminPort --bindDN "uid=monitor" --bindPassword $installationPassword --trustStorePath $setupPath/config/keystore --trustStorePassword:file $setupPath/config/keystore.pin --no-prompt

printf "installation successful..Done\n"
printf "Sagionara...\n"
tput cnorm

#END
