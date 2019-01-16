#!/bin/bash 
$1/root/post-executed 
wget ftp://192.168.2.149/xenserver/scripts/first-boot-script.sh  -O $1/root/first-boot-script.sh 
chmod 777 $1/root/first-boot-script.sh
touch $1/etc/systemd/system/postinstall.service
chmod 777 $1/etc/systemd/system/postinstall.service
cat > $1/etc/systemd/system/postinstall.service <<EOF 
[Unit]
After=xapi.service
	 
[Service]
ExecStart=/root/first-boot-script.sh
		 
[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/postinstall.service $1/etc/systemd/system/multi-user.target.wants/postinstall.service
