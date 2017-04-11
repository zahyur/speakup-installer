#!/usr/bin/env bash

if [[ "$(whoami)" != "root" ]]; then
	echo "This script should be run as root! Exiting..."
	exit 1
fi

if ! [[ -e /usr/bin/speakup-installer ]]; then
	 firstInstall=1
fi

echo "Copying the install script..."
cp speakup-installer.sh /usr/bin/speakup-installer

if [[ "${firstInstall}" == "1" ]]; then
echo "Preparing the system for building speakup..."
/usr/bin/speakup-installer --prepare
fi

echo "Copying the service..."
cp speakup-installer.service /usr/lib/systemd/system/speakup-installer.service
cp -u service.options /etc/sysconfig/speakup-installer 

echo "Reloading services..."
systemctl daemon-reload

echo "Enabling the service..."
systemctl enable speakup-installer

echo "Starting the service..."
systemctl restart speakup-installer

if [[ "$?" == "0" ]]; then
 result=""
else
	 result=" not "
fi
echo "The speakup-installer service is ${result} started."

exit 0
