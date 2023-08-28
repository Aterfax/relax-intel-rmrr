# vim:set ft=dockerfile:

# This Dockerfile builds the newest kernel with RMRR patch
#
# TODO Add support for custom branch of build
FROM debian:bullseye

RUN mkdir -p /build
WORKDIR /build

RUN set -x \
  && apt update && apt install -y ca-certificates wget

# apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7BF2812E8A6E88E0
RUN   apt -y install gnupg &&   wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg && \
  echo 'deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription' > /etc/apt/sources.list.d/pve.list

RUN apt -y update

RUN apt -y install git nano screen patch fakeroot build-essential devscripts libncurses5 libncurses5-dev libssl-dev bc \
 flex bison libelf-dev libaudit-dev libgtk2.0-dev libperl-dev asciidoc xmlto gnupg gnupg2 rsync lintian debhelper \
 libdw-dev libnuma-dev libslang2-dev sphinx-common asciidoc-base automake cpio dh-python file gcc kmod libiberty-dev \
 libpve-common-perl libtool perl-modules python3-minimal python3-dev sed tar zlib1g-dev lz4 curl zstd dwarves 

#Need pahole 1.16 or above
RUN TEMP_DEB="$(mktemp)" && \
 wget -O "$TEMP_DEB" http://archive.ubuntu.com/ubuntu/pool/universe/d/dwarves-dfsg/dwarves_1.21-0ubuntu1~20.04.1_amd64.deb && \
 dpkg -i "$TEMP_DEB" && \
 rm -f "$TEMP_DEB" 

# Copy both folders into docker root filepath.
COPY build /build
COPY patches /patches

#ENTRYPOINT ["tail", "-f", "/dev/null"]
ENTRYPOINT bash -c "cd /build/proxmox/ && ./build_latest.sh"
