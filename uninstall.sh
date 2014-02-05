#!/bin/bash
#
# Script that attempts to intelligently uninstall Wireshark based on the rough
# guidance distributed in the "README" along with the OS X installer
#
# From "Read me first.rtf"
# How do I uninstall?
#
#	1.	Remove /Applications/Wireshark
#	2.	Remove the wrapper scripts from /usr/local/bin
#	3.	Remove /Library/StartupItems/ChmodBPF
#	4.	Remove the access_bpf group.

export PATH="/usr/bin:/usr/sbin::/bin:/sbin"

err() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

get_pkg_vol()
{
	local vol=$(pkgutil --pkg-info ${1} | awk '/volume:/{print $2}')
	echo $vol
}

get_pkg_path()
{
	local path=$(pkgutil --pkg-info ${1} | awk '/location:/{print $2}')
	echo $path
}

forget_pkg()
{
	pkgutil --forget ${1} > /dev/null 2>&1
}

remove_files()
{
	local vol=$(get_pkg_vol ${1})
	local path=$(get_pkg_path ${1})

	local bins=(
		"capinfos" 
		"dftest" 
		"dumpcap" 
		"editcap" 
		"mergecap" 
		"randpkt" 
		"rawshark" 
		"text2pcap" 
		"tshark" 
		"wireshark"
		)

	case "${1}" in 
		"org.wireshark.ChmodBPF.pkg")
			rm -rf "${vol}${path}/ChmodBPF"
			forget_pkg ${1}
			;;
		"org.wireshark.cli.pkg")
			local bin
			for bin in "${bins[@]}"; do 
				rm -f "${vol}${path}${bin}"
			done
			forget_pkg ${1}
			;;
		"org.wireshark.Wireshark.pkg")
			rm -rf "${vol}${path}/Wireshark.app"
			forget_pkg ${1}
			;;
	esac
}

restore_bpf_dev()
{
	chgrp wheel /dev/bpf*
	chmod g-rw /dev/bpf*
}

remove_bpf_group()
{
	local group=access_bpf
	if $(dscl . -list /Groups/${group} > /dev/null 2>&1); then
		dscl . -delete /Groups/${group}
	else 
		err "Group ${group} not found"
	fi
}

if [[ ${EUID} -ne 0 ]]; then
	err "Please run this script as root"
	exit -1
fi

packages=(
	"org.wireshark.ChmodBPF.pkg"
	"org.wireshark.cli.pkg"
	"org.wireshark.Wireshark.pkg"
	)

for pkg in ${packages[@]}; do
	if [[ $(pkgutil --pkgs | grep -E "^${pkg}\$" ) ]]; then 
		remove_files "${pkg}"
	else 
		err "Wireshark does no appear to be installed - aborting"
		exit -1
	fi
done

restore_bpf_dev
remove_bpf_group

exit 0
