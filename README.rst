-  `OVERVIEW <#OVERVIEW>`__
-  `NAME <#NAME>`__
-  `SYNOPSIS <#SYNOPSIS>`__
-  `OPTIONS <#OPTIONS>`__
-  `DESCRIPTION <#DESCRIPTION>`__
-  `EXAMPLES <#EXAMPLES>`__

OVERVIEW
========

This is based on a script by Ken Fallon, as described in Hacker Public
Radio episode 2356: `Safely enabling ssh in the default Raspbian Image
<http://hackerpublicradio.org/eps.php?id=2356>`_. Thanks, Ken!

NAME
====

pi\_sdcard\_setup - Tighten up a Raspbian Pi sdcard image

SYNOPSIS
========

pi\_sdcard\_setup [options] [file ...]

::

     Options:
       -h|--help      brief help message
       -m|--man       full documentation
       -d|--download <download URL>

OPTIONS
=======

**-h\|--help**
    Print a brief help message and exits.

**-m\|--man**
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

1. Enable SSH
  SSH is turned off by default in a Raspbian image.

2. Copy over a SSH key
  This will allow logging into the RPi without using a password.

3. Change the pi user password
  Make it something other than "raspberry".

4. Change the root password
  This also enables the root account.

5. Disallow root from logging in via SSH.
  Now that there is a root account, we shouldn't be able to login to
  it from the network.

When this updated image is burned to an sdcard, the RPi will have these
changes before it runs the first time.

EXAMPLES
========

Download and process the default (latest Raspbian) image::

  pi_sdcard_setup.bash -d

Process an image you've alread downloaded. Perhaps you've made a change
to this script and want to re-run it::

  pi_sdcard_setup.bash raspbian_image.zip


