#!/bin/sh

[ $# -eq 1 ] ||
  { echo -e 'Usage:\n  build.sh <alpine|fedora>'; exit 1; }
podman build --build-arg=DIST=$1 -t tinywrkb/libvirtd:latest-$1 .
