#!/usr/bin/env bash

if [[ "$(whoami)" != "root" ]]; then
	echo "This script should be run as root! Exiting..."
	exit 1
fi

echo "Stopping the service..."
systemctl stop speakup-installer

echo "Disabling the service..."
systemctl disable speakup-installer

echo "Reloading services..."
systemctl daemon-reload

echo "Removing the install script..."
rm /usr/bin/speakup-installer

echo "Removing the service..."
rm /usr/lib/systemd/system/speakup-installer.service

if [[ "$1" == "all" ]]; then
echo "Removing service configuration..."
rm /etc/sysconfig/speakup-installer 

echo "Removing log file..."
rm /var/log/speakup-installer.log"
fi

if [[ -e /usr/bin/speakup-installer || -e /usr/lib/systemd/system/speakup-installer.service ]]; then
	 result=" not "
else
 result=""
fi
echo "The speakup-installer service is ${result} removed."

exit 0
