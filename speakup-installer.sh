#!/usr/bin/env bash

# This script is not part of the Linux Kernel, nor the speakup screen reader.
# This script uses the same license as the Linux Kernel - http://kernel.org
# Author: Zahari Yurukov <zahari.yurukov@gmail.com>
# Version: 0.2
# You can get the latest version from: https://github.com/zahyur/speakup-installer
# This script installs the speakup screen reader for the currently active Linux kernel.
# it watches for speakup's presence, and in case it couldn't find it proceeds with installation.
# it uses a kernel from kernel.org, matching the version of the currently active kernel.
# It installs only speakup and it's modules in the currently active kernel's directory, it doesn't install a whole kernel!
# This script is tested only under Fedora 23, 24 and 25 - 32-bit, but should work with all Fedora versions, and probably other distributions.
# The author of this script is not responsible for any damages resulting of the use of this script. You're using it on your own risk!


if [[ "$(whoami)" != "root" ]]; then
	echo "This script should be run as root! Exiting..."
	exit 1
fi

self="$(basename ${0})"
arguments="${@}"
shouldPause=0
shouldVerify=1
LOGFILE=/var/log/speakup-installer.log
initialdir="$(pwd)"
builddir="/usr/src/kernels"
if ! [[ -d ${builddir} && -w ${builddir} ]]; then
  builddir="/tmp"
fi
installdir="/usr/lib/modules/$(uname -r)/kernel/drivers/staging/speakup"
read -a kernelVersion <<< "$(sed 's/\([^-]\)\(-.*\)$/\1 \2/' <<<"$(uname -r)")"
kernelSource=linux-${kernelVersion[0]}

helpdoc="\
${self} version 0.2\n\
\n\
-i,--installdir <install-dir>    -  Install speakup in the given kernel modules directory\n\
-d,--daemon         -  Run the script in the background.\n\
-r,--reinstall          -  Backup speakup and reinstall. \n\
-R,--restore       -  Restore speakup from backup.\n\
-c,--clean         - Clean downloaded files.\n\
-u,--uninstall           -  Remove speakup.\n\
-C,--custom-speakup <directory>       -  Copy speakup's source from the given directory.\n\
-E,--install-espeakup           - Download espeakup from github and install it.\n\
-p,--prepare          - Install the nesessary packages for speakup compilation.\n\
-P,--pause      -  make pause between steps\n\
-k,--kernel-version      -  set the kernel version, like 4.9.13\n\
-x,--kernel-extra      -  set the kernel version, like -200.fc25.i686+PAE\n\
-K,--kernel-source      -  set the directory with the unpacked kernel source\n\
-t,--trust     - Don't check the integrity of the archive or the signature of the tarball\n\
-h,--help - Print this message.\n\
\n\
"

getopt --test > /dev/null
if [[ $? == 4 ]]; then
 SHORT=i:drRcuC:EpPk:x:K:th
 LONG=installdir:,daemon,reinstall,restore,clean,uninstall,custom-speakup:,install-espeakup,prepare,pause,kernel-version:,kernel-extra:,kernel-source:,trust,help
 PARSED=`getopt --options $SHORT --longoptions $LONG --name "${self}" -- ${arguments}`
 if [[ $? != 0 ]]; then
  exit 2
 fi

 eval set -- "${PARSED}"

 while true; do
  case "$1" in
   -i|--installdir)
	if [[ -d "$2" ]]; then
 	installdir="$2/kernel/drivers/staging/speakup"
 	echo "Install directory set to ${installdir}"
else
	echo "$2 doesn't exists or is not a directory!"
	exit 1
fi
    shift 2
    ;;
	  -d|--daemon)
echo $$ > /var/run/speakup-installer.pid 
exec > "${LOGFILE}" 2>&1
    shift
    ;;
	  -r|--reinstall)
	if [[ -d ${installdir} ]]; then
 	echo "Moveing current speakup to a backup location..."
 	mv "${installdir}" "${builddir}/speakup.backup"
fi
    shift
    ;;
	  -R|--restore)
	echo "Restoring speakup from the last backup..."
	mv "${builddir}/speakup.backup" "${installdir}"
	exit $?
    ;;
   -c|--clean)
	echo "Cleaning downloaded files..."
	rm -rf ${builddir}/linux-${kernelVersion[0]}*
	exit $?
    ;;
   -u|--uninstall)
		echo "Removeing speakup from ${installdir}..."
		rm -rf "${installdir}"
		exit $?
    ;;
	  -C|--custom-speakup)
		if [[ -e "$2" ]]; then
  customSpeakup="$2"
  if [[ -d ${customSpeakup} ]]; then
	  customSpeakup=${customSpeakup}/*
  fi
 else
 echo "Path $2 doesn't exists."
 exit 1
		fi
		shift 2
    ;;
	  -E|--install-espeakup)
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
    ;;
    -p|--prepare)
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
	    ;;
    -P|--pause)
	    shouldPause=1
	    shift
	    ;;
    -k|--kernel-version)
	    installdir=$(echo ${installdir}|sed 's/'${kernelVersion[0]}'/'$2'/')
	    kernelSource=$(echo ${kernelSource}|sed 's/'${kernelVersion[0]}'/'$2'/')
	    kernelVersion[0]=$2
	    shift 2
	    ;;
    -x|--kernel-extra)
	    installdir=$(echo ${installdir}|sed 's/'${kernelVersion[1]}'/'$2'/')
	    kernelVersion[1]=$2
	    shift 2
	    ;;
    -K|--kernel-source)
	    kernelSource=$(readlink -qsf $2)
	    shift 2
	    ;;
    -t|--trust)
	    shouldVerify=0
	    shift
	    ;;
    -h|--help)
    echo -e "${helpdoc}"
		exit 0
		;;
   --)
    shift
    break
    ;;
   *)
    echo "Programming error" >> "${LOGFILE}"
    exit 3
    ;;
  esac
 done
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

	function make-pause {
   if [[ "${shouldPause}" == "1" ]]; then
	   read -p "*** Press any key to continue or Control+C to abort ***" -n 1
	   echo -e "\n"
   fi
	}

if ! [[ -e  $(sed 's/^\(.*\)\/drivers\/staging\/speakup/\1/' <<<${installdir}) ]]; then
	echo "It looks like there are no kernel modules in "$(sed 's/^\(.*\)\/drivers\/staging\/speakup/\1/' <<<${installdir})
	echo "You may have entered wrong kernel version or extra version."
 exit 1
fi

	echo "Checking for speakup..."
	while [[ -e "${installdir}/speakup.ko" ]]; do
		echo "Speakup is installed for the current curnel. Re-check in 60 seconds. Press Control+C to abort."
		echo "Use '${self} --reinstall' or remove ${installdir} to reinstall..."
		sleep 60
	done

	echo "Speakup not found in the current kernel's directory - installing."
	make-pause
	cd "${builddir}"

	if ! [[ -d ${kernelSource} ]]; then
		while true; do
			if ! [[ -f linux-${kernelVersion[0]}.tar.gz ]]; then
				echo "Downloading kernel ${kernelVersion[0]} from kernel.org..."
				wget -q -c -N https://www.kernel.org/pub/linux/kernel/v${kernelVersion[0]:0:1}.x/linux-${kernelVersion[0]}.tar.gz
			fi
			if [[ "${shouldVerify}" == "0" ]]; then
				echo "Unpacking linux-${kernelVersion[0]}.tar.gz..."
tar -xf linux-${kernelVersion[0]}.tar.gz
				break
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
		echo "Kernel ${kernelVersion[0]} found in $(readlink -qsf ${kernelSource})."
	fi

	cd ${kernelSource} 

if [[ "$?" == "0" ]]; then
	if [[ ${customSpeakup} ]]; then
		echo "Copying ${customSpeakup} to $(pwd)/drivers/staging/speakup/"
make-pause
cp -R ${customSpeakup} drivers/staging/speakup/
fi
	
	echo "Executing make oldconfig..."
make-pause
	yes '' | make oldconfig

	echo "Editing makefile..."
	make-pause
	sed -i 's/EXTRAVERSION =.*$/EXTRAVERSION = '"${kernelVersion[1]}"'/' Makefile

	echo "Editing .config..."
	make-pause
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
	make-pause
	make prepare

	echo "Executing make modules_prepare..."
	make-pause
	make modules_prepare

	echo "Building speakup..."
	make-pause
	make SUBDIRS=scripts/mod
	make SUBDIRS=drivers/staging/speakup/ modules

	echo "Copying speakup to ${installdir}"
	make-pause
	mkdir -p "${installdir}"
	cp drivers/staging/speakup/speakup*.ko "${installdir}"

	cd ${installdir}/../../..
	echo "executing depmod..."
	make-pause
	depmod

	echo "Executing modprobe speakup_soft..."
	make-pause
	modprobe speakup_soft

	make-pause
	echo "----------"
	echo "result:"
	echo "----------"
	echo "Listing ${installdir}"
	echo "----------"
	ls "${installdir}"
	make-pause
	echo "----------"
	echo "lsmod:"
	echo "----------"
	lsmod | grep speakup
	make-pause
	echo "----------"
	echo "dmesg:"
	echo "----------"
	dmesg | grep speakup
	make-pause
	echo "----------"
	echo "modinfo:"
	echo "----------"
	modinfo speakup
	echo "----------"
fi

	make-pause
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

	make-pause
	#restart the script, in case this is unattended run
	cd "${initialdir}"
	$0

	exit 0

