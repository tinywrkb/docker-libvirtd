#!/bin/sh

[ $# -eq 1 ] ||
  { echo -e 'Usage:\n  start.sh <alpine|fedora>'; exit 1; }
DIST=$1 podman-compose -p libvirtd-pod up -d
