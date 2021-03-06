#!/bin/sh
#
# Copyright (c) 2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

# This script will build a container image with a golang1.16.6 binary installed
# The SBOM for the golang binary is created by hand (but it could be the output of
# a golang release.

# We create a container image using buildah from the previously built debian:10 image
echo starting...
ctr=$(buildah from localhost:5000/debian:10)
buildah unshare buildah mount $ctr
echo building container...
# Install golang
buildah unshare buildah run $ctr /bin/bash -c "apt-get update && apt-get install -y wget && wget https://golang.org/dl/go1.16.6.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.16.6.linux-amd64.tar.gz && apt-get remove -y wget"
buildah config --env PATH=/bin:/usr/local/go/bin $ctr
# Create our golang image
img=$(buildah commit $ctr localhost:5000/golang:1.16.6)

# Upload the golang image with the corresponding sboms
oras pull localhost:5000/debian-sbom:10 -a
buildah push --tls-verify=false localhost:5000/golang:1.16.6
oras push localhost:5000/golang-sbom:1.16.6 debian-sbom:application/json golang1.16.6-sbom:application/json

# Clean up all the containers
buildah rm --all
echo ready
