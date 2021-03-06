#!/bin/sh
#
# Copyright (c) 2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

# This script will build a container image with an SBoM from the previously built
# debian:10 image and previously generated sbom1 image.
# On successful completion we should have a debian image with python installed,
# and SBOM file called "sbom1" and a config file called sbom_config2.json

# We create a container image using buildah from the previously built debian:10 image

echo starting...
# let's verify if that image is signed:
cosign verify -key ~/cosign/cosign.pub localhost:5000/debian:20210914T205414Z
echo verified image
# Assuming this image has been signed, let's start building a
# container
echo building container...
ctr=$(buildah from localhost:5000/debian:20210914T205414Z)
mnt=$(buildah unshare buildah mount $ctr)

# Let's install some stuff
buildah unshare buildah run $ctr /bin/bash -c "apt-get update && apt-get install -y python3"

# Let's commit this "python" container
img=$(buildah commit $ctr localhost:5000/python:3)

# Let's now download our image's corresponding sbom
cosign verify -key ~/cosign/cosign.pub localhost:5000/debian:20210914T205414Z-sbom
echo verified sbom
oras pull localhost:5000/debian:20210914T205414Z-sbom -a

# We now provide this mount point to tern with the previous sbom
tern report --live $mnt -f spdxjson -ctx debian-sbom -o python-sbom

# We can now push the python image and the corresponding sbom
buildah push --tls-verify=false localhost:5000/python:3
# We push both the sboms so we have one tag referencing all the sboms
# related to this image
oras push localhost:5000/python:3-sbom debian-sbom:application/json python-sbom:application/json

# Let's sign our new artifacts
cosign sign -key ~/cosign/cosign.key localhost:5000/python:3
cosign sign -key ~/cosign/cosign.key localhost:5000/python:3-sbom

# Clean up all the containers
buildah rm --all
echo ready
