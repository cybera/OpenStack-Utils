# Copyright (c) 2011, Cybera and/or its affiliates. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   - Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   - Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#   - Neither the name of Cybera or the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# This software is provided by the copyright holders and contributors "as
# is" and any express or implied warranties, including, but not limited to,
# the implied warranties of merchantability and fitness for a particular
# purpose are disclaimed.  In no event shall the copyright owner or
# contributors be liable for any direct, indirect, incidental, special,
# exemplary, or consequential damages (including, but not limited to,
# procurement of substitute goods or services; loss of use, data, or
# profits; or business interruption) however caused and on any theory of
# liability, whether in contract, strict liability, or tort (including
# negligence or otherwise) arising in any way out of the use of this
# software, even if advised of the possibility of such damage.

#!/bin/sh
BASHRC="/dev/null"
LOGDIR="/scratch"
LOGFILE="console.txt"
LOGGING_PROMPT="echo \`date \"+%d %b %T\"\` --\`whoami\`-- \`history 1 | cut -f 3 | head -c 256\`"

# make a directory for the log file:
mkdir -p $LOGDIR
touch $LOGDIR/$LOGFILE
chmod -R 777 $LOGDIR

if grep -iq "centos" /etc/*release ; then
    BASHRC="/etc/bashrc"
elif grep -iq "ubuntu" /etc/*release ; then
    BASHRC="/etc/bash.bashrc"
else
    BASHRC="/dev/null"
fi

# if a PROMPT has already been set, then we need to add a separator 
# before appending our logging prompt.  Otherwise, let SEPARATOR
# be empty
if [ -n "$PROMPT" ]; then
    SEPARATOR=";"
fi

if [ `grep -c "$LOGGING_PROMPT" $BASHRC` -eq 0 ]; then
    echo "PROMPT_COMMAND=\$PROMPT_COMMAND'$SEPARATOR $LOGGING_PROMPT >> $LOGDIR/$LOGFILE'" >> $BASHRC
fi
grep  "$LOGDIR/$LOGFILE" $BASHRC

