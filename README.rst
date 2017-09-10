-  `NAME <#NAME>`__
-  `SYNOPSIS <#SYNOPSIS>`__
-  `OPTIONS <#OPTIONS>`__
-  `DESCRIPTION <#DESCRIPTION>`__
-  `EXAMPLES <#EXAMPLES>`__

NAME
====

pi\_sdcard\_setup - Tighten up a Raspbian Pi sdcard image

SYNOPSIS
========

pi\_sdcard\_setup [options] [file ...]

::

     Options:
       -h             brief help message
       -m             full documentation
       -d|--download <download URL>

OPTIONS
=======

**-h\|--hhelp**
    Print a brief help message and exits.

**-m\|--mman**
    Prints the manual page and exits.

**-d\|--download** *URL to download image*
    Downloads a Raspbian Pi image to process. If the URL is not given,
    the default location is
    https://downloads.raspberrypi.org/raspbian_latest If this option is
    not used, you will need to supply the name of a .zip file that
    contains an Raspbian image.

DESCRIPTION
===========

Given a Raspbian image, **pi\_sdcard\_setup.bash** will modify the image
to:

Enable SSH
Copy over a SSH key
    This will allow logging into the RPi without using a password.

Change the pi user password
Change the root password
Disallow root from logging in via SSH.

When this updated image is burned to an sdcard, the RPi will have these
changes before it runs the first time.

EXAMPLES
========

Download and process the default (latest Raspbian) image:

Process an image you've alread downloaded. Perhaps you've made a change
to this script and want to re-run it.


