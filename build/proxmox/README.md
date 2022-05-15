## Proxmox - building from sources

If you're running a version of Proxmox with [no packages available](../../README.md#proxmox---premade-packages-easy), or
for some reason you don't/can't trust precompiled packages you can compile the kernel yourself using patches provided.

The easiest way to do it is to clone this repository and use the build script provided, alongside this `README.md` file 
([`build/proxmox/build_latest.sh`](build_latest.sh))


### How to do it WITHOUT Docker?
This is mostly intended if you want to build & run on your Proxmox host. Jump to [Docker-ized](README.md#how-to-do-it-with-docker)
guide if you want to build packages in an isolated environment.

#### Prerequisites
1. Proxmox 6/7 install (recommended) or Debian Buster/Bullseye <small>*(it WILL fail on Ubuntu!)*</small>
2. Root access.
3. ~40GB of free space.

#### Steps
1. Clone the repo and `cd` to the `build/proxmox/` directory. 
2. Run the [`build_latest.sh`](build.sh) script from terminal:  
   `RMRR_AUTOINSTALL=1 bash ./build_latest.sh`  
   <small>*You can also manually execute commands in the script step-by-step. To facilitate that the script contains 
   extensive comments for every step.*</small>

3. *(OPTIONAL)* Verify the kernel works with the patch disabled by rebooting and checking if `uname -r` shows a version
   ending with `-pve-relaxablermrr`
4. [Configure the kernel](../../README.md#configuration)

This process will also leave precompiled `*.deb` packages, in case you want to copy them to other Proxmox hosts you have.

---

### How to do it WITH Docker?
This is mostly intended for building packages for later use (and/or when you don't want to mess with your OS).

#### Prerequisites
1. Docker installed (tested on Ubuntu 22.04 & Debian 10).
2. ~40GB of free space.
3. Git clone of this repo (if building the image yourself.)

#### Steps

1. (Optional) Build the container image yourself from the top level of the cloned repo (Dockerfile will be present):  

   `docker build -t relaxable-rmrr-proxmox-kernel-builder  .`

2. Run the Docker image with an appropriate host file system binding (you can just pull the image direct from DockerHub, adjust the command below to the correct image name if you are building yourself):

   `docker run --name relaxable-rmrr-proxmox-kernel-builder -v /mnt/scratch/proxmox-kernel-build-area/proxmox-kernel:/build/proxmox/proxmox-kernel -it aterfax/relaxable-rmrr-proxmox-kernel-builder:latest`

3. Wait until the build finishes (30 - 300 minutes depending on hardware used) and find the debs on your host file system path e.g. 

   `/mnt/scratch/proxmox-kernel-build-area/proxmox-kernel/debs`
   
4. Now you can [install debs like you would premade packages](../../README.md#proxmox---premade-packages-easy).

5. [Configure the kernel](README.md#configuration)
   
Note: If you want to build specific versions you can override the entrypoint from `bash -c "cd /build/proxmox/ && ./build_latest.sh"` to a script version of your choosing e.g. `bash -c "cd /build/proxmox/ && ./build7.1-10.sh"`



