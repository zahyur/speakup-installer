#!/usr/bin/env bash

# This script is not part of the Linux Kernel, nor the speakup screen reader.
# This script uses the same license as the Linux Kernel - http://kernel.org
# Author: Zahari Yurukov <zahari.yurukov@gmail.com>
# Version: 0.2
# You can get the latest version from: http://zahari.tk/scripts/speakup-installer.sh
# This script installs the speakup screen reader for the currently active Linux kernel.
# it watches for speakup's presence, and in case it couldn't find it proceeds with installation.
# it uses a kernel from kernel.org, matching the version of the currently active kernel.
# It installs only speakup and it's modules in the currently active kernel's directory, it doesn't install a whole kernel!
# This script is tested only under Fedora 23 32-bit, but should work with all Fedora versions, and probably other distributions.
# The author of this script is not responsible for any damages resulting of the use of this script. You're using it on your own risk!


if [[ "$(whoami)" != "root" ]]; then
	echo "This script should be run as root! Exiting..."
	exit 1
fi

initialdir="$(pwd)"
builddir="/usr/src/kernels"
if ! [[ -d ${builddir} && -w ${builddir} ]]; then
  builddir="/tmp"
fi
installdir="/usr/lib/modules/$(uname -r)/kernel/drivers/staging/speakup"
read -a kernelVersion <<< "$(sed 's/\([^-]\)\(-.*\)$/\1 \2/' <<<"$(uname -r)")"
isDaemon=true

if [[ "$1" == "install" ]]; then
	isDaemon=false
	if [[ -d "$2"} ]]; then
 	echo "Install directory set to $2"
 	installdir="$2"
fi
elif [[ "$1" == "daemon" ]]; then
	isDaemon=true
elif [[ "$1" == "reinstall" ]]; then
	if [[ -d ${installdir} ]]; then
 	echo "Moveing current speakup to a backup location..."
 	mv "${installdir}" "${builddir}/speakup.backup"
fi
elif [[ "$1" == "restore" ]]; then
	echo "Restoring speakup from the last backup..."
	mv "${builddir}/speakup.backup" "${installdir}"
	exit $?
elif [[ "$1" == "clean" ]]; then
	echo "Cleaning downloaded files..."
	rm -rf ${builddir}/linux-${kernelVersion[0]}*
	exit $?
	elif [[ "$1" == "uninstall" ]]; then
		echo "Removeing speakup from ${installdir}..."
		rm -rf "${installdir}"
		exit $?
	elif [[ "$1" == "custom-speakup" ]]; then
		if [[ -e "$2" ]]; then
  customSpeakup="$2"
  if [[ -d ${customSpeakup} ]]; then
	  customSpeakup=${customSpeakup}/*
  fi
 else
 echo "Path $2 doesn't exists."
 exit 1
		fi
	elif [[ "$1" == "install-espeakup" ]]; then
		cd ${builddir}
		echo "Getting espeakup..."
		git clone https://github.com/williamh/espeakup
		cd espeakup
		if [[ "$?" != "0" ]]; then
 echo "Error getting espeakup! Exiting..."
 exit 1
		fi
		echo "Building espeakup..."
		make
		make install
		exit $?
	elif [[ "$1" == "prepare" ]]; then
		echo "Preparing dependancies..."
		depErrors=0
		if [[ $(command -v dnf) ]]; then
			pm_cmd=dnf
			dnf builddep -y kernel-${kernelVersion[0]}
			depErrors=$((${depErrors}+$?))
		elif [[ $(command -v yum) ]]; then
			pm_cmd=yum
			yum-builddep -y kernel-${kernelVersion[0]}
   depErrors=$((${depErrors}+$?))
		elif [[ $(command -v apt-get) ]]; then
			pm_cmd=apt-get
			apt-get build-dep -y linux-image-$(uname -r)
   depErrors=$((${depErrors}+$?))
		elif [[ $(command -v pacman) ]]; then
			pm_cmd=pacman
			pacman --needed -Syu base-devel linux-headers xmlto docbook-xsl kmod inetutils bc
   depErrors=$((${depErrors}+$?))
		fi
		if [[ ${pm_cmd} == "dnf" || ${pm_cmd} == "yum" ]]; then
			# RHEL/Fedora based package names
			${pm_cmd} install -y gcc make kernel-headers wget gnupg tar gzip git espeak-devel
   depErrors=$((${depErrors}+$?))
		elif [[ ${pm_cmd} == "apt-get" ]]; then
			# Debian/Ubuntu based package names
			${pm_cmd} install -y gcc make wget gnupg tar gzip linux-headers-$(uname -r) build-essential kernel-package fakeroot libncurses5-dev libssl-dev ccache git espeak-dev
   depErrors=$((${depErrors}+$?))
		fi
		echo "Errors: ${depErrors}"
		exit ${depErrors}
	elif [ "$1" == "help" -o "$1" == "--help" -o "$1" == "-h" ];then
		echo "Usage: $(basename $0) [prepare|reinstall|restore|clean|uninstall|install-espeakup]"
		exit 0
	fi

	# functions
	function verify-kernel-download {
		file=$1
		while true; do
			result=$(gpg --verify ${file}.sign ${file} 2>&1)
			code=$?
			if [[ "${code}" == "2" ]]; then
				fingerprint="$(grep 'RSA key' <<< "${result}" | sed 's/^.*ID\s\([^\s]\+\).*$/\1/g')"
				gpg --keyserver pgpkeys.mit.edu --recv-key ${fingerprint}
				gpg --fingerprint ${fingerprint}
			elif [[ "${code}" == "1" ]]; then
				return 1
			elif [[ "${code}" == "0" ]]; then
				return 0
			fi
		done
	}

	echo "Checking for speakup..."
	while [[ -e "${installdir}/speakup.ko" ]]; do
		echo "Speakup is installed for the current curnel. Re-check in 60 seconds. Press Control+C to abort."
		echo "Use '$(basename $0) reinstall' or remove ${installdir} to reinstall..."
		sleep 60
	done

	echo "Speakup not found in the current kernel's directory - installing."
	cd "${builddir}"

	if ! [[ -d linux-${kernelVersion[0]} ]]; then
		while true; do
			if ! [[ -f linux-${kernelVersion[0]}.tar.gz ]]; then
				echo "Downloading kernel ${kernelVersion[0]} from kernel.org..."
				wget -q -c -N https://www.kernel.org/pub/linux/kernel/v${kernelVersion[0]:0:1}.x/linux-${kernelVersion[0]}.tar.gz
			fi
			if ! [[ -f linux-${kernelVersion[0]}.tar.sign ]]; then
				echo "Downloading signature..."
				wget -q -c -N https://www.kernel.org/pub/linux/kernel/v${kernelVersion[0]:0:1}.x/linux-${kernelVersion[0]}.tar.sign
			fi
			echo "Checking integrity of the archive..."
			gunzip -t linux-${kernelVersion[0]}.tar.gz
			integrityError=$?
			if [[ "${integrityError}" != 0 ]]; then
				echo "Integrity Check failed!"
			else
				echo "Inflating archive..."
				gunzip -kf linux-${kernelVersion[0]}.tar.gz
				echo "Verifying tarball..."
				verify-kernel-download linux-${kernelVersion[0]}.tar
				signatureError=$?
				if [[ "${signatureError}" != 0 ]]; then
					echo "Verification failed!"
				fi
				echo "Unpacking linux-${kernelVersion[0]}.tar..."
				tar -xf linux-${kernelVersion[0]}.tar
				echo "removing tarball..."
				break
				rm linux-${kernelVersion[0]}.tar
			fi
			if [[ ${integrityError} != 0 || ${signatureError} != 0 ]]; then
				echo "removing the corrupted archive..."
				rm linux-${kernelVersion[0]}.tar.gz
			fi
		done
	else
		echo "Kernel ${kernelVersion[0]} found in ${builddir}."
	fi

	cd linux-${kernelVersion[0]}

if [[ "$?" == "0" ]]; then
	if [[ ${customSpeakup} ]]; then
		echo "Copying ${customSpeakup} to $(pwd)/drivers/staging/speakup/"
cp -R ${customSpeakup} drivers/staging/speakup/
fi
	echo "Executing make oldconfig..."
	yes '' | make oldconfig

	echo "Editing makefile..."
	sed -i 's/EXTRAVERSION =.*$/EXTRAVERSION = '"${kernelVersion[1]}"'/' Makefile

	echo "Editing .config..."
	sed -i -e 's/\# CONFIG_SPEAKUP is not set/CONFIG_SPEAKUP=m/' -e '/CONFIG_SPEAKUP=m/a \
CONFIG_SPEAKUP_SYNTH_ACNTSA=m\
CONFIG_SPEAKUP_SYNTH_APOLLO=m\
CONFIG_SPEAKUP_SYNTH_AUDPTR=m\
CONFIG_SPEAKUP_SYNTH_BNS=m\
CONFIG_SPEAKUP_SYNTH_DECTLK=m\
CONFIG_SPEAKUP_SYNTH_DECEXT=m\
CONFIG_SPEAKUP_SYNTH_LTLK=m\
CONFIG_SPEAKUP_SYNTH_SOFT=m\
CONFIG_SPEAKUP_SYNTH_SPKOUT=m\
CONFIG_SPEAKUP_SYNTH_TXPRT=m\
CONFIG_SPEAKUP_SYNTH_DUMMY=m' .config

	echo "Executing make prepare..."
	make prepare

	echo "Executing make modules_prepare..."
	make modules_prepare

	echo "Building speakup..."
	make SUBDIRS=scripts/mod
	make SUBDIRS=drivers/staging/speakup/ modules

	mkdir -p "${installdir}"
	echo "Copying speakup to ${installdir}"
	cp drivers/staging/speakup/speakup*.ko "${installdir}"

	cd /usr/lib/modules/$(uname -r)/
	echo "executing depmod..."
	depmod
	echo "Executing modprobe speakup_soft..."
	modprobe speakup_soft

	echo "----------"
	echo "result:"
	echo "----------"
	echo "Listing ${installdir}"
	echo "----------"
	ls "${installdir}"
	echo "----------"
	echo "lsmod:"
	echo "----------"
	lsmod | grep speakup
	echo "----------"
	echo "dmesg:"
	echo "----------"
	dmesg | grep speakup
	echo "----------"
	echo "modinfo:"
	echo "----------"
	modinfo speakup
	echo "----------"
fi

	#if it was successfull, remove the backup, else - restore (if possible).
	if [[ -e "${installdir}/speakup.ko" ]]; then
		echo "Installation successfull! Removing backup..."
		rm -rf "${builddir}/speakup.backup"
	elif [[ "${builddir}/speakup.backup" ]]; then
		echo "Installation failed! Restoring from backup."
		mv "${builddir}/speakup.backup" "${installdir}"
	else
		echo "Installation failed! No backup."
	fi

	echo "----------"

	#restart the script, in case this is unattended run
	cd "${initialdir}"
	$0

	exit 0

