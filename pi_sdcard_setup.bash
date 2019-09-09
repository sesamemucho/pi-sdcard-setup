#!/bin/bash
# Tighten up a Raspbian Pi sdcard image before the first run.
# See the man page at the end of this file for more information.

# MIT License 
# Original work Copyright (c) 2017 Ken Fallon http://kenfallon.com
# Modified work Copyright (c) 2017 Bob Forgey http://grumpydogconsulting.com
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function cleanup()
{
    # Unmount the sdcard partition if we caught an error after mounting
    ( mount | grep -q "$sdcard_mount" 2>/dev/null ) && sudo umount "$sdcard_mount"
    # Detach the loop devices if we caught an error after they were created
    test "$loopdev" && sudo losetup -d "$loopdev"
}

# Run the cleanup function above if we exit early
trap cleanup ERR INT TERM

# Fail out of script if error occurs
set -e 

# Change these three variables
root_password_clear="${RPI_ROOT_PW_CLEAR:-correct horse battery staple}"
pi_password_clear="${RPI_PI_PW_CLEAR:-wrong cart charger paperclip}"
public_key_file="${RPI_PUB_KEY_PATH:-${HOME}/.ssh/id_ed25519.pub}"

sdcard_mount="/mnt/sdcard"

cmdline="$0 $*"

# Note that we use "$@" to let each command-line parameter expand to a
# separate word. The quotes around "$@" are essential!
# We need TEMP as the 'eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o 'hmd::' --long 'help,man,download::' -n "$(basename $0)" -- "$@")

if [ $? -ne 0 ]; then
    echo 'Terminating...' >&2
    exit 1
fi

image_to_download="https://downloads.raspberrypi.org/raspbian_latest"

# Note the quotes around "$TEMP": they are essential!
eval set -- "$TEMP"
unset TEMP

use_download=0
while true; do
    case "$1" in
	'-d'|'--download')
	    echo 'Download:'
            use_download=1
	    case "$2" in
		'')
		    echo 'Download, using default location' ${image_to_download}
		    ;;
		*)
		    echo "Download, argument '$2'"
		    ;;
	    esac
	    shift 2
	    continue
	    ;;
        '-h'|'--help')
            pod2usage -verbose 1 "$0"
            exit 0
            ;;
        '-m'|'--man')
            pod2usage -verbose 3 "$0"
            exit 0
            ;;
	'--')
	    shift
	    break
	    ;;
	*)
	    echo 'Internal error!' >&2
	    exit 1
	    ;;
    esac
done

if [[ $EUID -ne 0 ]]
then
    echo
    echo Please run this script as root: sudo $cmdline
    echo
    exit 0
fi

#------------------------------------------------------------
# Check for executables we need
declare -A nopes
for i in wget sha256sum 7z losetup python3;
do
    if type $i >/dev/null 2>&1;
    then
        true
    else
        nopes[${#nopes[@]}]=$i
    fi
done

if [[ ${#nopes[@]} -gt 1 ]]
then
    echo
    echo Please install the following programs: ${nopes[@]}
    exit 1
elif [[ ${#nopes[@]} -eq 1 ]]
then
    echo
    echo Please install the following program: ${nopes[@]}
    exit 1
fi
#------------------------------------------------------------

if [ ! -e "${public_key_file}" ]
then
    echo "Can't find the public key file \"${public_key_file}\""
    echo "You can create one using:"
    echo "   ssh-keygen -t ed25519 -f ${public_key_file} -C \"Raspberry Pi keys\""
    exit 1
fi

if [[ $use_download -eq 0 ]]
then
    # We haven't specified a download, so we need an image file
    zip_file_name="${1:?No download specified, so a zip file name must be specified}"
else
    # Use a default zip file path of "./raspian_image.zip"
    zip_file_name="${1:-./raspbian_image.zip}"

    # 1. Get the source of the download index page
    # 2. Get the 30 lines following the name of the image to download
    # 3. Look for the first line containing 'SHA-256'
    # 4. Extract the checksum from that line.
    # Yes, a bunch of assumptions, but fewer than the last version.

    checksum_line=$(wget --quiet https://www.raspberrypi.org/downloads/raspbian/ -O - | grep -A 30 -F \"$image_to_download\" | grep SHA-256 | head -1)
    checksum=$(echo "$checksum_line" | sed -e 's/.*\([0-9a-fA-F]\{64\}\).*/\1/')

    if [[ ! $checksum =~ [0-9a-fA-F]{64} ]]
    then
        echo "Error occurred while parsing for the Raspian checksum."
        echo "You will need to fix this before proceeding."
        exit 1
    fi

    # Download the latest image, using the  --continue "Continue getting a partially-downloaded file"
    wget --continue "${image_to_download}" -O "${zip_file_name}"

    echo "Checking that the SHA-256 of the downloaded image matches \"${checksum}\""

    if [[ $( sha256sum "${zip_file_name}" | awk '{ print $1 }') == ${checksum} ]]
    then
        echo "The checksums match"
    else
        echo "The checksums did not match"
        exit 1
    fi
fi

# Following the tutorial
mkdir -p ${sdcard_mount}

# unzip
extracted_image="$( 7z l ${zip_file_name} | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}.*img$/ {print $NF}' )"
echo "The name of the image file is \"${extracted_image}\""

7z -y x "${zip_file_name}"

if [ ! -e "${extracted_image}" ]
then
    echo "Can't find the image \"${extracted_image}\""
    exit
fi

# Get loopback devices for the partitions in the image
loopdev=$(losetup -Pf --show "${extracted_image}")
echo loopdev is $loopdev

echo "Mounting the sdcard boot disk"
mount ${loopdev}p1 ${sdcard_mount}
ls -al ${sdcard_mount}
if [ ! -e "${sdcard_mount}/kernel.img" ]
then
    echo "Can't find the mounted card\"${sdcard_mount}/kernel.img\""
    exit
fi

touch "${sdcard_mount}/ssh"
if [ ! -e "${sdcard_mount}/ssh" ]
then
    echo "Can't find the ssh file \"${sdcard_mount}/ssh\""
    exit
fi

umount "${sdcard_mount}"

echo "Mounting the sdcard root disk"
mount ${loopdev}p2 ${sdcard_mount}
ls -al ${sdcard_mount}

if [ ! -e "${sdcard_mount}/etc/shadow" ]
then
    echo "Can't find the mounted card\"${sdcard_mount}/etc/shadow\""
    exit
fi

echo "Change the passwords and sshd_config file"

root_password="$( python3 -c "import crypt; print(crypt.crypt('${root_password_clear}', crypt.mksalt(crypt.METHOD_SHA512)))" )"
pi_password="$( python3 -c "import crypt; print(crypt.crypt('${pi_password_clear}', crypt.mksalt(crypt.METHOD_SHA512)))" )"
sed -e "s#^root:[^:]\+:#root:${root_password}:#" "${sdcard_mount}/etc/shadow" -e  "s#^pi:[^:]\+:#pi:${pi_password}:#" -i "${sdcard_mount}/etc/shadow"
sed -e 's;^#PasswordAuthentication.*$;PasswordAuthentication no;g' -e 's;^PermitRootLogin .*$;PermitRootLogin no;g' -i "${sdcard_mount}/etc/ssh/sshd_config"
mkdir "${sdcard_mount}/home/pi/.ssh"
chmod 0700 "${sdcard_mount}/home/pi/.ssh"
chown 1000:1000 "${sdcard_mount}/home/pi/.ssh"
cat ${public_key_file} >> "${sdcard_mount}/home/pi/.ssh/authorized_keys"
chown 1000:1000 "${sdcard_mount}/home/pi/.ssh/authorized_keys"
chmod 0600 "${sdcard_mount}/home/pi/.ssh/authorized_keys"

umount "${sdcard_mount}"
losetup -d ${loopdev}
new_name="${extracted_image%.*}-ssh-enabled.img"
mv -v "${extracted_image}" "${new_name}"

lsblk

echo ""
echo "Now you can burn the disk using something like:"
echo "      dd bs=4M status=progress if=${new_name} of=/dev/mmcblk????; sync"
echo ""

exit

:<<POD

=head1 NAME

pi_sdcard_setup - Tighten up a Raspbian Pi sdcard image

=head1 SYNOPSIS

pi_sdcard_setup [options] [F<file>]

 Options:
   -h|--help      brief help message
   -m|--man       full documentation
   -d|--download  [F<download URL>]

=head1 OPTIONS

=over 8

=item B<-h|--help>

Print a brief help message and exits.

=item B<-m|--man>

Prints the manual page and exits.

=item B<-d|--download> F<URL to download image>

Downloads a Raspbian Pi image to process. If the URL is not given, the
default location is
L<https://downloads.raspberrypi.org/raspbian_latest> If this option is
not used, you will need to supply the name of a .zip file that
contains an Raspbian image.

=back

=head1 DESCRIPTION

Given a Raspbian image, B<pi_sdcard_setup.bash> will modify the image to:

=over 8

=item Enable SSH

SSH is turned off by default in a Raspbian image.

=item Copy over a SSH key

This will allow logging into the RPi without using a password.

Make it something other than "raspberry".

=item Change the pi user password

=item Change the root password

This also enables the root account.

=item Disallow root from logging in via SSH.

Now that there is a root account, we shouldn't be able to login to it
from the network.

=back

When this updated image is burned to an sdcard, the RPi will have these changes before it runs the first time.

=head1 EXAMPLES

=over 8

Download and process the default (latest Raspbian) image:

=over 8

C<pi_sdcard_setup.bash -d>

=back

Process an image you've alread downloaded. Perhaps you've made a change to this script and want to re-run it.

=over 8

C<pi_sdcard_setup.bash raspbian_image.zip>

=back

=back

=cut

POD
