# bpre-requisites

## Ubuntu:
Pre-req: terraform, packer

qemu/libvirt: `sudo apt install qemu-kvm libvirt-daemon-system`

Ubuntu 22.04 found some permissions issues between TF and qemu, so I disabled apparmor in qemu:

```asciidoc
sudo vi /etc/libvirt/qemu.conf
security_driver = "none"
```