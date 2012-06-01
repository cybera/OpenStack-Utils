#!/bin/bash

# This script creates an OpenStack development environment (a devstack) in an already existing cloud.
# See devstack.org

# TODO: make IP optional
# assumes you have a cloud and sourced creds
# assumes allocated IP and devstack keypair
# chmodded 400 devstack.pem
# assumes devstackrc and localrc
# assumes you have euca2ools installed, if not link

# Uncomment this to see *all* commands being run (great for debugging)
#set -o xtrace

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

# Make sure everything is in place
if [ ! -f $ABS_PATH/devstackrc ]; then
  echo "Copy $ABS_PATH/devstackrc.template to $ABS_PATH/devstackrc and edit the values in the file."
  exit 1
fi

if [ ! -f $ABS_PATH/localrc ]; then
  echo "Copy $ABS_PATH/localrc.template to $ABS_PATH/localrc and edit the values in the file."
  exit 1
fi

. $ABS_PATH/devstackrc
. $ABS_PATH/localrc

# If an instance with the IP already exists, terminate it
INSTANCE_ID=`euca-describe-instances | grep $IP | cut -f 2`

if [ "$INSTANCE_ID" != "" ]; then
  euca-disassociate-address $IP
  sleep 5
  euca-terminate-instances $INSTANCE_ID
fi

# Run a new instance and wait for it to be ready
INSTANCE_ID=`euca-run-instances -k devstack -t $SIZE $AMI | grep INSTANCE | cut -f 2`

echo "Instance: $INSTANCE_ID"

STATE=""

while [ "$STATE" != "running" ]; do
  sleep 2

  STATE=`euca-describe-instances | grep $INSTANCE_ID | cut -f 6`
  STATE=`echo $STATE` # trims whitespace
  echo "State: $STATE"
done

# Associate the IP with the new instance
while [ "$STATE" != "ADDRESS" ]; do
  sleep 2

  STATE=`euca-associate-address -i $INSTANCE_ID $IP | cut -f 1`
  STATE=`echo $STATE` # trims whitespace
  echo "State: $STATE"
done

if [ "$PRIVATE_CLOUD" == "True" ]; then
  IP=`euca-describe-instances | grep $INSTANCE_ID | cut -f 5`
fi

# Wait for ssh to be ready
LOCATION="ubuntu@$IP"
OPTIONS="-i $ABS_PATH/devstack.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PasswordAuthentication=no"
SSH="ssh $OPTIONS $LOCATION"
SCP="scp $OPTIONS"

while [ "$STATE" != "ssh ready" ]; do
  sleep 2

  STATE=`$SSH echo "ssh ready"`
  STATE=`echo $STATE` # trims whitespace

  if [ "$STATE" == "" ]; then
    STATE="ssh not ready"
  fi

  echo "State: $STATE"
done

# Install the software and deploy OpenStack
$SCP $ABS_PATH/install-command-logging.sh $LOCATION:
$SSH "sudo ./install-command-logging.sh"
$SSH sudo apt-get -qqy update
$SSH sudo apt-get -qqy install git

if [ "$DEVSTACK_BRANCH" != "" ]; then
  GIT="git clone https://github.com/openstack-dev/devstack.git -b $DEVSTACK_BRANCH devstack/"
  EXIT_STATUS=$?

  if [ $EXIT_STATUS -ne 0 ]; then
    echo "Branch $DEVSTACK_BRANCH does not exist."
    exit 1
  fi
else
  GIT="git clone https://github.com/openstack-dev/devstack.git"
fi

$SSH $GIT
$SCP $ABS_PATH/localrc $LOCATION:devstack/
$SSH "cd devstack; ./stack.sh"

$SSH sudo updatedb
$SSH "sed -i '$ a\. \`locate nova.bash_completion\`' .bashrc"
$SSH "sed -i '$ a\cd devstack; . openrc' .bashrc"

read -p "Press [Enter] to ssh to your new cloud."

$SSH