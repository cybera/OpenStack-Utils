#!/usr/bin/env python
"""
This script creates an OpenStack development environment (a devstack) in an already existing cloud.
See devstack.org

1. assumes you have a cloud and sourced creds
2. assumes allocated IP and devstack keypair
3. chmodded 400 devstack.pem

"""

import os
import sys  
import time
import logging
from urlparse import urlparse
from pprint import pprint

import boto
import boto.ec2

import utils

try:
    import devstack_conf
except ImportError:
    raise IOError("devstack_conf.py is missing. Copy devstack_conf.py.template to devstack_conf.py and edit the values in the file.")

# goto http://pypi.python.org/packages/source/p/pip
# download the latest package
#   curl -O http://pypi.python.org/packages/source/p/pip/pip-1.0.2.tar.gz
# unzip
#   tar xvf pip-1.0.2.tar.gz
# change to new pip dir
#   cd pip-1.0.2
# sudo python setup.py install

logger = logging.getLogger('devstack')

def configure_logging():
    logger.setLevel(logging.DEBUG)

    fh = logging.FileHandler('devstack.log')
    fh.setLevel(logging.DEBUG)

    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)

    logger.addHandler(fh)
    logger.addHandler(ch)

def get_connection():
    EC2_URL = os.getenv("EC2_URL")
    EC2_ACCESS_KEY = os.getenv("EC2_ACCESS_KEY")
    EC2_SECRET_KEY = os.getenv("EC2_SECRET_KEY")

    if not (EC2_ACCESS_KEY and EC2_SECRET_KEY and EC2_URL):
        raise Exception("No cloud credentials found.  Source your rc file.")

    ec2_url_parsed = urlparse(EC2_URL)
    region=boto.ec2.regioninfo.RegionInfo(name = "nova", endpoint = ec2_url_parsed.hostname)
    secure = True if ec2_url_parsed.scheme == "https" else False

    conn = boto.connect_ec2(aws_access_key_id = EC2_ACCESS_KEY,
                            aws_secret_access_key = EC2_SECRET_KEY,
                            is_secure = secure,
                            region = region,
                            port = ec2_url_parsed.port,
                            path = ec2_url_parsed.path)

    logger.info("Connected to %(EC2_URL)s" % locals())

    return conn

def assert_config():
    try:
       open("localrc")
    except IOError as e:
       raise IOError("Copy localrc.template to localrc and edit the values in the file.")

    #TODO: assert existence of devstack keypair

def terminate_existing_instance(conn):
    reservations = conn.get_all_instances()

    for reservation in reservations:
        for instance in reservation.instances:
            if instance.public_dns_name == devstack_conf.IP:
                conn.disassociate_address(devstack_conf.IP)
                conn.terminate_instances([instance.id])

                logger.info("Terminated instance %s" % instance.id)

                return

def run_instance(conn):
    reservation = conn.run_instances(image_id = devstack_conf.AMI, key_name = devstack_conf.KEYPAIR, instance_type = devstack_conf.SIZE)
    instance = reservation.instances[0]

    logger.info("Starting instance %s" % instance.id)

    while instance.state != "running":
        time.sleep(2)
        instance.update()

    logger.info("Started instance %s" % instance.id)

    return instance

def associate_address(conn, instance):
    conn.associate_address(instance.id, devstack_conf.IP)

    logger.info("Associated address %s to instance %s" % (devstack_conf.IP, instance.id))

def get_ssh_context(instance):
    location="ubuntu@%s" % devstack_conf.IP
    options="-i devstack.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PasswordAuthentication=no"
    ssh="ssh %(options)s %(location)s" % locals()
    scp="scp %(options)s" % locals()

    while state != "ssh ready":
        time.sleep(2)

        logger.info("Waiting for ssh to start")

        stdout = utils.execute("%(ssh)s echo 'ssh ready'" % locals())[0]

        if stdout == "ssh ready"
            break

        logger.info("ssh Started")

    return (ssh, scp, location)

def main():
    try:
        configure_logging()
        assert_config()

        conn = get_connection()
        terminate_existing_instance(conn)
        instance = run_instance(conn)
        associate_address(conn, instance)

        return 0
    except Exception, e:
        logger.exception(e)
        return 1

if __name__ == "__main__":
    sys.exit(main())
