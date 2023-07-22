# 🍻 Relaxed RMRR Mapping for Linux 3.17+
[![Build and Publish Docker Image](https://github.com/Aterfax/relax-intel-rmrr/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/Aterfax/relax-intel-rmrr/actions/workflows/docker-publish.yml)
[![Build kernel debs](https://github.com/Aterfax/relax-intel-rmrr/actions/workflows/build-kernel-debs.yml/badge.svg)](https://github.com/Aterfax/relax-intel-rmrr/actions/workflows/build-kernel-debs.yml)
![Docker Image Size (tag)](https://img.shields.io/docker/image-size/aterfax/relaxable-rmrr-proxmox-kernel-builder/latest)
![Docker Pulls](https://img.shields.io/docker/pulls/aterfax/relaxable-rmrr-proxmox-kernel-builder)
## Note - this fork uses a different patching method / Docker based builds now functional.

This fork has been amended to patch the required iommu source files using ``sed`` rather than ``patch``. This is achieved by using ``sed`` to amend the pve-kernel **Makefile** using several further ``sed`` commands to edit the iommu source file during the make process as this make process pulls the source files (chicken/egg problem.)

The key ``sed`` commands can be found at:

-  [relax-intel-rmrr/patches/relaxable-rmrr-patch-sed.txt](patches/relaxable-rmrr-patch-sed.txt)
-  [relax-intel-rmrr/build/proxmox/build.sh#L157](build/proxmox/build.sh#L157)


## 🐧💨 Now you can use PCI passthrough on broken platforms

### TL;DR
When you try to use PCI/PCIe passthrough in KVM/QEMU/Proxmox you get:
```
vfio-pci 0000:01:00.1: Device is ineligible for IOMMU domain attach due to platform RMRR requirement. Contact your platform vendor.
```
followed by `vfio: failed to set iommu for container: Operation not permitted`.

This kernel patch fixes the problem **on kernels v3.17 and up** (tested up to 5.9.1). You can skip to "[Installation](README.md#installation)" 
section if you don't care about the rest. Reading of "[Disclaimers](README.md#disclaimers)" section to understand the 
risks, and "[Solutions & hacks](deep-dive.md#other-solutions--hacks)" to get the idea of different alternatives is 
highly recommended.

---

### Table of Contents
1. [Installation](README.md#installation)
    - [Proxmox - premade packages](README.md#proxmox---premade-packages-easy)
    - [Docker - building from sources](README.md#docker---build-packages-from-sources-intermediate)
    - [Proxmox - building from sources](README.md#proxmox---building-from-sources-advanced)
    - [Other distros](README.md#other-distros)
2. [Configuration](README.md#configuration)
3. [Deep Dive](deep-dive.md) - *a throughout research on the problem written for mortals*
    - [Technical details](deep-dive.md#technical-details)
        - [How virtual machines use memory?](deep-dive.md#how-virtual-machines-use-memory)
        - [Why do we need VT-d / AMD-Vi?](deep-dive.md#why-do-we-need-vt-d--amd-vi)
        - [How PCI/PCIe actually work?](deep-dive.md#how-pcipcie-actually-work)
        - [RMRR - the monster in a closet](deep-dive.md#rmrr---the-monster-in-a-closet)
        - [What vendors did wrong?](deep-dive.md#what-vendors-did-wrong)
    - [Other solutions & hacks](deep-dive.md#other-solutions--hacks)
        - [Contact your platform vendor](deep-dive.md#contact-your-platform-vendor)
        - [Use OS which ignores RMRRs](deep-dive.md#use-os-which-ignores-rmrrs)
        - [Attempt HPE's pseudofix (if you use HP)](deep-dive.md#attempt-hpes-pseudofix-if-you-use-hp)
        - [The comment-the-error-out hack (v3.17 - 5.3)](deep-dive.md#the-comment-the-error-out-hack-v317---53)
        - [Long-term solution - utilizing relaxable reservation regions (>=3.17)](deep-dive.md#long-term-solution---utilizing-relaxable-reservation-regions-317)
          - [Why commenting-out the error is a bad idea](deep-dive.md#why-commenting-out-the-error-is-a-bad-idea)
          - [The kernel moves on quickly](deep-dive.md#the-kernel-moves-on-quickly)
          - [What this patch actually does](deep-dive.md#what-this-patch-actually-does)
          - [Why kernel patch and not a loadable module?](deep-dive.md#why-kernel-patch-and-not-a-loadable-module)
        - [The future](deep-dive.md#the-future)    
4. [Disclaimers](README.md#disclaimers)
5. [Acknowledgments & References](README.md#acknowledgments--references)
6. [License](README.md#license)

---

### Installation

#### Proxmox - premade packages (easy)
As I believe in *[eating your own dog food](https://en.wikipedia.org/wiki/Eating_your_own_dog_food)* I run the kernel
described here. Thus, I publish precompiled packages.

1. Go to the [releases tab](https://github.com/Aterfax/relax-intel-rmrr/releases) and pick appropriate packages
2. Download `release.zip`, unzip it and `cd` down to the bottom of the directory tree. (You can copy links and use `wget https://...` and `unzip release.zip` on the server itself)
3. *(OPTIONAL)* Verify the release signature on ``release.zip`` as discussed here: https://github.com/Aterfax/relax-intel-rmrr/discussions/16
4. Install all using `dpkg -i *.deb` in the folder where you downloaded the debs
5. *(OPTIONAL)* Verify the kernel works with the patch disabled by rebooting and checking if `uname -r` shows a version 
   ending with `-pve-relaxablermrr`
6. [Configure the kernel](README.md#configuration)

---
#### Docker - build packages from sources (intermediate)

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
   
4. Now you can [install debs like you would premade packages](README.md#proxmox---premade-packages-easy).

5. [Configure the kernel](README.md#configuration)
   
Note: If you want to build specific versions you can override the entrypoint from `bash -c "cd /build/proxmox/ && ./build_latest.sh"` to a script version of your choosing e.g. `bash -c "cd /build/proxmox/ && ./build7.1-10.sh"`

6. Navigate to your `proxmox-kernel` directory and remove the build files to save space (if desired.)

---

#### Proxmox - building from sources (advanced)
If you're running a version of Proxmox with [no packages available](README.md#proxmox---premade-packages-easy) you can
[compile the kernel yourself using patches provided](build/proxmox/).

---

#### Other distros
1. Download kernel sources appropriate for your distribution
2. Apply an appropriate patch to the source tree
    - Go to the folder with your kernel source
    - For Linux 3.17 - 5.7: `patch -p1 < ../patches/add-relaxable-rmrr-below-5_8.patch`
    - For Linux >=5.8: `patch -p1 < ../patches/add-relaxable-rmrr-5_8_and_up.patch`
3. Follow your distro kernel compilation & installation instruction:
    - [Debian](https://wiki.debian.org/BuildADebianKernelPackage)
    - [Ubuntu](https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel)

---

### Configuration
By default, after the kernel is installed, the patch will be *inactive* (i.e. the kernel will behave like this patch was
never applied). To activate it you have to add `intel_iommu=relax_rmrr` to your Linux boot args.

In most distros (including Proxmox) you do this by:
1. Opening `/etc/default/grub` (e.g. using `nano /etc/default/grub`)
2. Editing the `GRUB_CMDLINE_LINUX_DEFAULT` to include the option:
    - Example of old line:   
        ```
        GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt intremap=no_x2apic_optout"
        ```
    - Example of new line:
        ```
        GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on,relax_rmrr iommu=pt intremap=no_x2apic_optout"
        ```
    - *Side note: these are actually options which will make your PCI passthrough work and do so efficiently*
3. Running `proxmox-boot-tool kernel list` to list your available kernels and then 'pinning' your chosen version with `proxmox-boot-tool` e.g. `proxmox-boot-tool kernel pin 6.2.11-1-pve-relaxablermrr` (Make sure to keep updating your kernels and repinning new releases!)
4. Rebooting

To verify if the the patch is active execute `dmesg | grep 'Intel-IOMMU'` after reboot. You should see a result similar
 to this:
 
```
root@sandbox:~# dmesg | grep 'Intel-IOMMU'
[    0.050195] DMAR: Intel-IOMMU: assuming all RMRRs are relaxable. This can lead to instability or data loss
root@sandbox:~# 
```

---

### Disclaimers
 - I'm not a kernel programmer by any means, so if I got something horribly wrong correct me please :)
 - This path should be safe, as long as you don't try to remap devices which are used by the IPMI/BIOS, e.g.
   - Network port shared between your IPMI and OS
   - RAID card in non-HBA mode with its driver loaded on the host
   - Network card with monitoring system installed on the host (e.g. [Intel Active Health System Agent](https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-c04781229))
 - This is not a supported solution by any of the vendors. In fact this is a direct violation of Intel's VT-d specs 
   (which Linux already violates anyway, but this is increasing the scope). It may cause crashes or major instabilities.
   You've been warned.

---

### Acknowledgments & References
 - [Comment-out hack research by dschense](https://forum.proxmox.com/threads/hp-proliant-microserver-gen8-raidcontroller-hp-p410-passthrough-probleme.30547/post-155675)
 - [Proxmox kernel compilation & patching by Feni](https://forum.proxmox.com/threads/compile-proxmox-ve-with-patched-intel-iommu-driver-to-remove-rmrr-check.36374/) 
 - [Linux IOMMU Support](https://www.kernel.org/doc/html/latest/x86/intel-iommu.html)
 - [RedHat RMRR EXCLUSION Whitepaper](https://access.redhat.com/sites/default/files/attachments/rmrr-wp1.pdf)
 - [Intel® Virtualization Technology for Directed I/O (VT-d)](https://software.intel.com/content/www/us/en/develop/articles/intel-virtualization-technology-for-directed-io-vt-d-enhancing-intel-platforms-for-efficient-virtualization-of-io-devices.html)
 - [Intel® Virtualization Technology for Directed I/O Architecture Specification](https://software.intel.com/content/www/us/en/develop/download/intel-virtualization-technology-for-directed-io-architecture-specification.html)
 
--- 
 
### License
This work (patches & docs) is dual-licensed under MIT and GPL 2.0 (or any later version), which should be treated as an 
equivalent of Linux `Dual MIT/GPL` (i.e. pick a license you prefer).
