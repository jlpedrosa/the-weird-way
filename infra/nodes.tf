locals {
  disk_pool_name     = "k8s_lab"
  disk_location      = "/tmp/${local.disk_pool_name}"
  disk_template_name = "k8s-node-base"
  nodes = {
    "ctrl-plane-1" = {}
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

# Run packer with cloud init
resource "null_resource" "node_base_image" {
  depends_on = [
    libvirt_pool.disk_pool
  ]

  provisioner "local-exec" {
    command = "packer build -var 'pool_name=${local.disk_pool_name}' -var 'image_name=${local.disk_template_name}' ${path.module}/images"
  }
}

# as provisioners destroy are not allowed variables only self, we use this
# intermediate volume to trigger the deletion of the image created by packer.
resource "libvirt_volume" "k8s_node_image" {
  name   = "node-image"
  pool   = libvirt_pool.disk_pool.name
  base_volume_name = local.disk_template_name
  format = "qcow2"

  depends_on = [
    null_resource.node_base_image
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "virsh vol-delete --pool ${self.pool} --vol ${self.base_volume_name}"
  }
}


resource "libvirt_volume" "node_disk" {
  for_each         = local.nodes
  name             = "${each.key}-disk.qcow2"
  base_volume_name = libvirt_volume.k8s_node_image.name
  pool             = libvirt_pool.disk_pool.name
  format           = "qcow2"
  size             = "12368709632"

  depends_on = [
    null_resource.node_base_image
  ]
}

# contents for network cloud-init
data "template_file" "network_config" {
  template = file("${path.module}/control-plane/network_config.cfg")
}

# contents for system cloud-init
data "template_file" "system_data" {
  for_each = local.nodes
  template = file("${path.module}/control-plane/cloud_init.yaml")
  vars = {
    hostname = each.key
  }
}

# Render a multi-part cloud-init config making use of the part above, and other source files
data "template_cloudinit_config" "cloud_init_config" {
  for_each      = local.nodes
  gzip          = false
  base64_encode = false

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.system_data[each.key].rendered
  }

  # Kubeadm
  #  part {
  #    filename     = "kubeadm-init.yaml"
  #    content_type = "text/cloud-config"
  #    content      = data.template_file.kubeadm_data[each.key].rendered
  #  }
}


# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance, you can add also meta_data field
resource "libvirt_cloudinit_disk" "cloud_init" {
  for_each       = local.nodes
  name           = "${each.key}-init.iso"
  user_data      = data.template_cloudinit_config.cloud_init_config[each.key].rendered
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
    network_name   = "default"
    hostname       = each.key
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
