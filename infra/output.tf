

output "instances" {
  value = {
    for k, inst in libvirt_domain.node_vm : k => {
      name              = inst.name
      address           = inst.network_interface[0].addresses[0]
      id                = inst.id
    }
  }
}