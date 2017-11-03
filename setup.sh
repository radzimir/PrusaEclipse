#!/usr/bin/env bash

help () {
cat <<EOF

=== INTRO ===
This script:

1. Installs Sloeber (Eclipse For Arduino)
2. Checks out Prusa MK2 Firmware
3. Prepares all libraries and guide you during further configuration. 

The parameter --sandbox points by default to paren directory where you checked out ths 'project'. 
Example:

  mysandbox/PrusaMK2Eclipse/setup.sh
  mysandbox/soeber <- eclipse installation
  mysandbox/soeber-workspace <- eclipse workspace
  mysandbox/Prusa-Firmware <- Firmware from github

Additionally the following directories are used:

  ~/Download <- where sloeber archive will be saved
  ~/Arduino/libraries <- where we install LiquidTWI2 library

Please be aware: this two directories are outside of your sanbox and will be modified permanently. 

=== Human Interface ===

Script guides you through installtion showing two types of messages:
INFO:.... <- expalantion wat is beeing done, where you seat back and pray
COMMAND:... <- call to action, request what YOU must execute and confirm

=== Error Handling and Retry ===

If ccript is interupted (Ctrl-C) or ends with unexpected error, it can be startet simply again. 
Through cheking of preconditions, it tries to continue where break occured.

If nothing helps, please panick and remove your sanbox, then try again. 

Example: $0 -sandbox path 

Parameters:
  --help|-h : show this help
  --trace|-t : trace script
  --sandbox|-s : target path to your sandbox

EOF
}


#set -o xtrace
set -o errexit
set -o nounset
#set -o pipefail

__start_dir=`pwd`
__install="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#----------------------------------------------------------------
# Exit script always in the same directory where it was started
# Show ERROR warning if anny error occurred, do not show if Crl-C was pressed.
#----------------------------------------------------------------

cleanup() {
    # 130 is Ctrl-C
    if [[ $? -ne 0 && $? -ne 130 ]]; then
echo "Exit status: $?";
cat <<'EOF'
 ______ _____  _____   ____  _____
|  ____|  __ \|  __ \ / __ \|  __ \
| |__  | |__) | |__) | |  | | |__) |
|  __| |  _  /|  _  /| |  | |  _  /
| |____| | \ \| | \ \| |__| | | \ \
|______|_|  \_\_|  \_\\____/|_|  \_\

EOF
    fi
    cd $__start_dir
}

trap cleanup EXIT

#
# some utlity functions
#

qpushd() {
	pushd $@ 1>/dev/null
}

qpopd() {
	popd $@ 1>/dev/null
}

inf() {
	printf "INFO    : $@ \n"
}

die() {
	printf "ERROR   : $@ \n"
	exit 1
}

cmd() {
	printf "COMMAND : $@ - continue? [Y/n]"
	read answer
	case "${answer:-y}" in
		"Y"|"y")
			;;
		*)
			inf "exiting on demand"
			exit 0;
	esac
}

P_HELP="";
P_TRACE="";
P_SANDBOX=`cd ${__install}/..; pwd`

while [[ $# -gt 0 ]]
do
  NEXT_PARAMETER=$1
  case "$NEXT_PARAMETER" in
  "--help"|"-h")
    P_HELP=true;
    ;;
  "--trace"|"-t")
    P_TRACE=true
    ;;
  "--sandbox"|"-s")
    P_SANDBOX=$2
    shift
    ;;
  *)
    echo "ERROR: Unsupported parameter '$NEXT_PARAMETER'\n\n"
    exit -1;
    ;;
  esac
  shift
done;

if [[ "$P_HELP" = true ]]; then
  help
  exit 0
fi

if [[ "$P_TRACE" = true ]]; then
  set -x
fi

# check if sanbox exists, if not, exit
if [[ ! -d $P_SANDBOX ]]; then
  die "Directory '$P_SANDBOX' not found.";
fi

qpushd $P_SANDBOX

# install sloeber if not found
if [[ ! -e "sloeber" ]]; then
	inf "installing sloeber"
	githubUrl="https://github.com"
	#TODO: determine platform, assumin 64 bit
	sloeberReleaseUrl=`curl -s ${githubUrl}/Sloeber/arduino-eclipse-plugin/releases/ | perl -ne 'if ( /href="(.*?\/releases\/download\/.*?linux64.*?)"/ ) { print "$1\n"; exit 0; };'`
	sloeberArchiveName=`basename $sloeberReleaseUrl`;
	qpushd ~/Downloads
	if [[ ! -e $sloeberArchiveName ]]; then
		wget ${githubUrl}${sloeberReleaseUrl}
	else
		inf "using existing archive ~/Downloads/${sloeberArchiveName}"
	fi
	qpopd 
  tar -xvzf ~/Downloads/$sloeberArchiveName
else
  inf "$P_SANDBOX/sloeber alreday exists, continue with old installation"  
fi

if [[ ! -e Prusa-Firmware ]]; then 
  git clone https://github.com/prusa3d/Prusa-Firmware.git
  qpushd Prusa-Firmware/Firmware
  #TODO: assuming variant RAMBo13a
  cp variants/1_75mm_MK2-RAMBo13a-E3Dv6full.h Configuration_prusa.h
	qpopd
fi
qpopd

# last Sloeber release has a bug, apply clean up workaround for IndexOutOfBound Exception
cleanUpOldLibs() {
  if [[ -e $P_SANDBOX/sloeber/arduinoPlugin/libraries ]]; then
    qpushd $P_SANDBOX/sloeber/arduinoPlugin/libraries
    for nextLib in `ls -1`; do
      if [[ `ls $nextLib | wc -l` -eq 0 ]]; then
        inf "Removing empty directory $nextLib";
        rmdir $nextLib
      fi
    done
    qpopd
  fi
}

cleanUpOldLibs;

inf "Starting sloeber, wait until android plugin is installed."
$P_SANDBOX/sloeber/sloeber-ide -data $P_SANDBOX/sloeber-workspace 2>/dev/null &
cmd "Are all downloads finished?"

if [[ ! -e $P_SANDBOX/sloeber/arduinoPlugin/packages/rambo ]]; then
  inf "Rambo hardware not registered yet."
  cmd "Open Arduino->Preferences->Third party index URL's and paste additional URL: \nhttps://raw.githubusercontent.com/ultimachine/ArduinoAddons/master/package_ultimachine_index.json"
  cmd "Open Arduino->Platforms and Boards and select rambo->RepRap..->1.0.1"
fi

# install libs under rambo hardware to link them automatically
mkdir -p ~/Arduino/libraries
qpushd ~/Arduino/libraries
if [[ ! -e LiquidTWI2 ]]; then
	inf "checking out LiquidTWI2"
  git clone https://github.com/lincomatic/LiquidTWI2.git
fi
qpopd

qpushd $P_SANDBOX/sloeber/arduinoPlugin/packages
if [[ ! -e rambo/hardware/avr/1.0.1/libraries/SPI ]]; then 
  cp -r arduino/hardware/avr/1.6.20/libraries/SPI        rambo/hardware/avr/1.0.1/libraries/
fi
if [[ ! -e rambo/hardware/avr/1.0.1/libraries/Wire ]]; then
  cp -r arduino/hardware/avr/1.6.20/libraries/Wire       rambo/hardware/avr/1.0.1/libraries/
fi

if [[ ! -e rambo/hardware/avr/1.0.1/libraries/LiquidTWI2 ]]; then
  ln -s ~/Arduino/libraries/LiquidTWI2 rambo/hardware/avr/1.0.1/libraries/LiquidTWI2
fi
qpopd

cmd "\n\
1. In Arduino->Preferences->LibraryManager->Display switch LiquidCristal off and LiquideCrystal_I2C on.\n\
2. If you can't confirm a dialog, close sloeber and start this script again."

cleanUpOldLibs;

cmd "\n\
1. Create new Arduino Sketch named \"Firmware\" located exactly in $P_SANDBOX/PrusaMK2/Prusa-Firmware/Firmware\n\
2. Choose rambo as a platform.\n\
3. Choose \"Default ino file\" as template, it will not overwrite exiting one.\n\
4. Go to Arduino->Add Libary to sleected Project, add LiquideCrystal_I2C.\n\
4. Now you are done. You should be able to build the firmware and navigate the code.";

inf "HINT: Start sloeber ar any time using command: $P_SANDBOX/sloeber/sloeber-ide -data $P_SANDBOX/sloeber-workspace"

