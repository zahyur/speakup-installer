#This is an installer for the speakup screen reader.
In case the Linux distribution been used has excluded it from the kernel modules distributed with their custom kernel, or you want to compile a custom speakup source code.

This script is not part of the Linux Kernel, nor the speakup screen reader.

 This script uses the same license as the Linux Kernel - http://kernel.org

 Author: Zahari Yurukov <zahari.yurukov@gmail.com>

This script installs the speakup screen reader for the currently active Linux kernel.
 it watches for speakup's presence, and in case it couldn't find it proceeds with installation.
 it uses a kernel from kernel.org, matching the version of the currently active kernel.
 It installs only speakup and it's modules in the currently active kernel's directory, it doesn't compile and install a whole kernel!

 This script is tested only under Fedora 23, 24 and 25 - 32-bit, but should work with all Fedora versions, and probably other distributions.

 The author of this script is not responsible for any damages resulting of the use of this script. You're using it on your own risk!

#Usage:
Just run the script as root or with sudo.
if you haven't compiled speakup, other modules or the Linux kernel before, run `./speakup-installer.sh --prepare` first.
The ./install.sh script will do that for you, as well as installing a systemd service.
The service will write a logfile in /var/log/speakup-installer.log.
If you want to install espeakup as well, run `./speakup-installer --install-espeakup`.

#Options:

-i,--installdir <install-dir>    -  Install speakup in the given kernel modules directory (e. g. /usr/lib/modules/4.9.13-201.fc25.i686+PAE).

-d,--daemon         -  Run the script in the background. It will write it's output to /var/log/speakup-installer.log

-r,--reinstall          -  Backup speakup to the build directory and reinstall.

-R,--restore       -  Restore speakup from backup.

-c,--clean         - Clean downloaded files from the build directory.

-u,--uninstall           -  Remove speakup from the installation directory.

-C,--custom-speakup <directory>       -  Copy speakup's source from the given directory to the kernel's source directory before installing.

-E,--install-espeakup           - Download espeakup from github and install it.
This option checks out espeakup's source code from github and installs it.

-p,--prepare          - Install the nesessary packages for speakup compilation.
This option uses your package manager to install packages, nessesary for kernel compilation. It currently tries to support dnf, yum, pacman and apt based distributions.

-P,--pause      -  make pause between steps.
If you run this script for the first time and want to monitor closely what it does, or want to debug it - that option will stop at every step, allowing you to read the previous output.

-k,--kernel-version      -  set the kernel version, like 4.9.13. 
It's not nesesary that to be the currently loaded version.

-x,--kernel-extra      -  set the kernel extra version, like -201.fc25.i686+PAE.
That's everything after the digits in `uname -r`, i. e. after 4.9.13, for example, including the dash.

-K,--kernel-source      -  set the directory with the unpacked kernel source.
It could be an absolute path, or relative to the build directory (usr/src/kernels or /tmp, if the former is not available).

-t,--trust     - Don't check the integrity of the archive or the signature of the tarball.
That could be dangerous for unattended installs, but sometimes you may want to save some time, when installing manually.

-h,--help - Print this help and exit.

