packer {
  required_plugins {
    sshkey = {
      version = ">= 1.0.1"
      source  = "github.com/ivoronin/sshkey"
    }
    libvirt = {
      version = ">= 0.5.0"
      source  = "github.com/thomasklein94/libvirt"
    }
  }
}

variable "pool_name" {
  type = string
}

variable "image_name" {
  type = string
}


data "sshkey" "install" {
}

source "libvirt" "ubuntu" {
  libvirt_uri = "qemu:///system"
  vcpu   = 4
  memory = 4096
  network_address_source = "lease"

  network_interface {
    type  = "managed"
    alias = "communicator"
  }

  # https://developer.hashicorp.com/packer/plugins/builders/libvirt#communicators-and-network-interfaces
  communicator {
    communicator         = "ssh"
    ssh_username         = "ubuntu"
    ssh_private_key_file = data.sshkey.install.private_key_path
  }

  volume {
    alias = "artifact"
    pool  = var.pool_name
    name  = var.image_name
    source {
      type = "external"
      urls = ["https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"]
    }
    capacity   = "10G"
    bus        = "sata"
    format     = "qcow2"
  }

  volume {
    source {
      type = "cloud-init"
      pool  = var.pool_name
      user_data = format("#cloud-config\n%s", jsonencode({
        package_update = true
        ssh_authorized_keys = [ data.sshkey.install.public_key ]
        apt = local.apt
        packages = local.packages
       # users = local.users
      }))
    }
    bus        = "sata"
  }
  shutdown_mode = "acpi"
}

build {
  sources = ["source.libvirt.ubuntu"]
  provisioner "shell" {
    inline = [
      "ip -br a",
      "echo if you want to connect via SSH use the following key: ${data.sshkey.install.private_key_path}",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init'; while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done; echo 'Done'",
    ]
  }

#  provisioner "breakpoint" {
#    note = "You can examine the created domain with virt-manager, virsh or via SSH"
#  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
    ]
  }

#  post-processor "manifest" {
#    output = "manifest.json"
#  }
}
