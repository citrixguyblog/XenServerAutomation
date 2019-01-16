#!/bin/sh
#Unattended XenServer Script
#Created by: Michael Winkler, Julian Mooren (CANCOM)
#Version: 1.2
#Creation date: 01-19-2019

# Start installation
echo $(date) "- Start XenServer installation ...">> /var/log/xenautomation.log

# General variables
HOSTLABEL='hostname'
FTPServer='ftp://192.168.2.149/xenserver/files/7.1'
CTXLicServer='192.168.2.20'
CTXLicEdition='enterprise-per-socket'
NTPServer='192.168.2.10'

# set timezone
echo $(date) "-   Set timezone ...">> /var/log/xenautomation.log
echo $(date) "-     execute *timedatectl set-timezone Europe/Berlin*">> /var/log/xenautomation.log
timedatectl set-timezone Europe/Berlin

echo $(date) "-     execute */etc/firstboot.d/60-import-keys start*">> /var/log/xenautomation.log
/etc/firstboot.d/60-import-keys start

echo $(date) "-     execute *ntpdate -u $NTPServer*">> /var/log/xenautomation.log
ntpdate -u $NTPServer

# wait for network
echo $(date) "-   Wait for network ...">> /var/log/xenautomation.log
while :
do
	if ping -c 1 $CTXLicServer &> /dev/null
	then
		echo $(date) "-     network state [OK]">> /var/log/xenautomation.log
		break              #Abandon the loop.
	else
		echo $(date) "-     network state [FAIL]">> /var/log/xenautomation.log
		sleep 2	
	fi
done

# XenServer hotfixes download
mkdir /tmp/updates
echo $(date) "-   Download updates...">> /var/log/xenautomation.log
echo $(date) "-     execute *wget -nd -r --no-parent -A.iso -P /tmp/files/Hotfix $FTPServer/Hotfix -nv*">> /var/log/xenautomation.log
wget -nd -r --no-parent -A.iso -P /tmp/files/Hotfix $FTPServer/Hotfix -nv 2>&1 | while read line ; do
echo $(date) "-       [LOG] $line">> /var/log/xenautomation.log
done

echo $(date) "-   Download packages ...">> /var/log/xenautomation.log
echo $(date) "-     execute *wget -nd -r --no-parent -A.rpm -P /tmp/files/GRID $FTPServer/GRID -nv*">> /var/log/xenautomation.log
wget -nd -r --no-parent -A.rpm -P /tmp/files/GRID $FTPServer/GRID -nv 2>&1 | while read line ; do
echo $(date) "-       [LOG] $line">> /var/log/xenautomation.log
done

# enable maintenance mode
echo $(date) "-   Basic configuration ...">> /var/log/xenautomation.log
echo $(date) "-     Enable maintenance mode">> /var/log/xenautomation.log
echo $(date) "-       execute *xe host-disable*">> /var/log/xenautomation.log
xe host-disable &>> /var/log/xenautomation.log

# set licence server (needed for Updates)
echo $(date) "-     Setting Licencse Server">> /var/log/xenautomation.log
echo $(date) "-       execute *xe host-apply-edition edition=$CTXLizenzedition license-server-address=$CTXLizenzserver*">> /var/log/xenautomation.log
xe host-apply-edition edition=$CTXLicEdition license-server-address=$CTXLicServer &>> /var/log/xenautomation.log

# enable multipathing
echo $(date) "-     Enable Multipathing">> /var/log/xenautomation.log
echo $(date) "-       execute *xe host-list name-label=`hostname` --minimal*">> /var/log/xenautomation.log
HOSTUUID=$(xe host-list name-label=`hostname` --minimal)

echo $(date) "-       execute *xe host-param-set other-config:multipathing=true uuid=$HOSTUUID *">> /var/log/xenautomation.log
xe host-param-set other-config:multipathing=true uuid=$HOSTUUID &>> /var/log/xenautomation.log

echo $(date) "-       execute *xe host-param-set other-config:multipathhandle=dmp uuid=$HOSTUUID*">> /var/log/xenautomation.log
xe host-param-set other-config:multipathhandle=dmp uuid=$HOSTUUID &>> /var/log/xenautomation.log

# disable maintenance mode
echo $(date) "-     Enable maintenance mode">> /var/log/xenautomation.log
echo $(date) "-       execute *xe host-enable*">> /var/log/xenautomation.log
xe host-enable &>> /var/log/xenautomation.log

# UUID local storage
echo $(date) "-   Check local storage UUID ...">> /var/log/xenautomation.log
while :
do
	SRUUID=$(xe sr-list name-label='Local storage' --minimal)
	if [ "$SRUUID" = "" ]
	then
		echo $(date) "-     SRUUID [unknown]">> /var/log/xenautomation.log
		sleep 2	
	else
		echo $(date) "-     SRUUID="$SRUUID>> /var/log/xenautomation.log
		break

	fi
done

while :
do
	SRState=$(xe sr-scan uuid=$SRUUID 2>&1)
	if [ "$SRState" = "" ]
	then
		echo $(date) "-     SRState [OK]">> /var/log/xenautomation.log
		break
	else
		echo $(date) "-     SRState="$SRState>> /var/log/xenautomation.log
		sleep 2	
	fi
done

# Install XenServer updates
echo $(date) "-   Installing XenServer update">> /var/log/xenautomation.log
for updatefile in `ls /tmp/files/Hotfix`; do

	echo $(date) "-     Update $updatefile ..." >> /var/log/xenautomation.log

	echo $(date) "-       execute: *xe update-upload sr-uuid=$SRUUID file-name=/tmp/updates/$updatefile*">> /var/log/xenautomation.log
	PATCHUUID=$(xe update-upload sr-uuid=$SRUUID file-name=/tmp/files/Hotfix/$updatefile  2>&1)
	
	echo $(date) "-       execute: *xe update-apply uuid=$PATCHUUID*">> /var/log/xenautomation.log
	xe update-apply uuid=$PATCHUUID &>> /var/log/xenautomation.log

	echo $(date) "-       execute: *xe update-pool-clean uuid=$PATCHUUID*">> /var/log/xenautomation.log
	xe update-pool-clean uuid=$PATCHUUID &>> /var/log/xenautomation.log

	rm -f /tmp/files/Hotfix/$updatefile

done

# Install NVIDIA GRID Manager
echo $(date) "-   Installing XenServer packages ...">> /var/log/xenautomation.log

for driver in `ls /tmp/files/GRID`; do

	echo $(date) "-     Packages $updatefile ..." >> /var/log/xenautomation.log

	echo $(date) "-       execute: *rpm -iv /tmp/files/GRID/$driver*">> /var/log/xenautomation.log
	rpm -iv /tmp/files/GRID/$driver &>> /var/log/xenautomation.log

done

# Remove Updates & Packages
rm -f /tmp/files/*

# remove installer service
echo $(date) "-   Removing Install Service">> /var/log/xenautomation.log
echo $(date) "-     execute: *rm -f /etc/systemd/system/multi-user.target.wants/postinstall.service*">> /var/log/xenautomation.log
rm -f /etc/systemd/system/multi-user.target.wants/postinstall.service


echo $(date) "- Reboot XenServer. After reboot unattended installation is finished">> /var/log/xenautomation.log

# XenServer reboot system
reboot
