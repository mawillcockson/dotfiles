# This file should be somewhere in a profile.d/ directory; usually
# /etc/profile.d/ and $HOME/.profile.d/
#
# $ENV is a special environment variable that points to a file that the
# shell will only source when it's in an interactive mode:
# https://pubs.opengroup.org/onlinepubs/9799919799/utilities/sh.html#tag_20_110_08
ENV=/etc/profile.interactive
export ENV

# /etc/profile.interactive should be placed by one of my setup scripts or
# programs
