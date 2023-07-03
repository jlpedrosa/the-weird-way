locals {
  disk_location = "/tmp/k8s_lab"
  nodes = {
    "test" = {}
    #"ctrl-plane-1" = {}
    #"ctrl-plane-2" = {}
    #"ctrl-plane-3" = {}
    #"wrkr-node-1" = {}
    #"wrkr-node-2" = {}
    #"wrkr-node-3" = {}
  }
}

resource "libvirt_pool" "disk_pool" {
  name = "k8s_lab"
  type = "dir"
  path = local.disk_location
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "ubuntu_cloud_image" {
  name   = "ubuntu-cloud-disk-qcow2"
  pool   = libvirt_pool.disk_pool.name
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "node_disk" {
  for_each       = local.nodes
  name           = "${each.key}-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_cloud_image.id
  format         = "qcow2"
  size           = "5368709120"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.yaml")
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance, you can add also meta_data field
resource "libvirt_cloudinit_disk" "cloud_init" {
  for_each       = local.nodes
  name           = "${each.key}-init.iso"
  user_data      = data.template_file.user_data.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.disk_pool.name
}

# Create the machine
resource "libvirt_domain" "node_vm" {
  for_each  = local.nodes
  name      = "${each.key}-node"
  memory    = "4096"
  vcpu      = 4
  cloudinit = libvirt_cloudinit_disk.cloud_init[each.key].id

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.node_disk[each.key].id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain
