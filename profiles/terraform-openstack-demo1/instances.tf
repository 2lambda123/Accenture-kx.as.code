resource "openstack_compute_keypair_v2" "kx-keypair" {
  name = "kx-keypair"
}

# Create KX-Main Admin server
resource "openstack_compute_instance_v2" "kx-main-admin" {
  depends_on = [ 
    openstack_compute_keypair_v2.kx-keypair,
    openstack_networking_network_v2.kx-internal-network,
    openstack_networking_subnet_v2.kx-internal-network-subnet,
    openstack_blockstorage_volume_v3.kx-main-admin-local-storage,
    openstack_blockstorage_volume_v3.kx-main-admin-glusterfs-storage,
    openstack_networking_floatingip_v2.kx-main-admin-floating-ip,
    openstack_networking_secgroup_v2.kx_security_group,
    openstack_compute_flavor_v2.kx-main-flavor
  ]
  name      = "kx-main1"
  image_id  = local.kx_main_image_id
  region    = "RegionOne"
  flavor_id = openstack_compute_flavor_v2.kx-main-flavor.id
  key_pair  = openstack_compute_keypair_v2.kx-keypair.name
  security_groups = [ openstack_networking_secgroup_v2.kx_security_group.name ]
  user_data       = "#cloud-config\nhostname: kx-main1"

  block_device {
    boot_index            = 0
    delete_on_termination = true
    destination_type      = "volume"
    source_type           = "image"
    volume_size           = 40
    uuid                  = local.kx_main_image_id
  }

  network {
    uuid = openstack_networking_network_v2.kx-internal-network.id
    name = openstack_networking_subnet_v2.kx-internal-network-subnet.name
  }

  provisioner "local-exec" {
    command = "echo \"${self.network.0.fixed_ip_v4} ${self.name} ${self.name}.demo1.kx-as-code.local\"> hosts_file_entries.txt"
  }

}

# Create KX-Main Additional servers
resource "openstack_compute_instance_v2" "kx-main-additional" {
  depends_on = [
    openstack_compute_keypair_v2.kx-keypair,
    openstack_networking_network_v2.kx-internal-network,
    openstack_networking_subnet_v2.kx-internal-network-subnet,
    openstack_compute_instance_v2.kx-main-admin,
    openstack_blockstorage_volume_v3.kx-main-additional-local-storage,
    openstack_networking_floatingip_v2.kx-main-additional-floating-ip,
    openstack_networking_secgroup_v2.kx_security_group,
    openstack_compute_flavor_v2.kx-worker-flavor
  ]
  name = "kx-main${count.index + 2}"
  image_id = local.kx_worker_image_id
  flavor_id = openstack_compute_flavor_v2.kx-worker-flavor.id
  key_pair = openstack_compute_keypair_v2.kx-keypair.name
  region = "RegionOne"
  security_groups = [ openstack_networking_secgroup_v2.kx_security_group.name ]
  user_data = "#cloud-config\nhostname: kx-main${count.index + 2}"
  count = (local.main_node_count - 1) < 0 ? 0 : local.main_node_count - 1

  block_device {
    boot_index = 0
    delete_on_termination = true
    destination_type = "volume"
    source_type = "image"
    volume_size = 40
    uuid = local.kx_worker_image_id
  }

  network {
    uuid = openstack_networking_network_v2.kx-internal-network.id
    name = openstack_networking_subnet_v2.kx-internal-network-subnet.name
  }

  provisioner "local-exec" {
    command = "echo \"${self.network.0.fixed_ip_v4} ${self.name} ${self.name}.demo1.kx-as-code.local\">> hosts_file_entries.txt"
  }

}

# Create KX-Worker server
resource "openstack_compute_instance_v2" "kx-worker" {
  depends_on = [ 
    openstack_compute_keypair_v2.kx-keypair,
    openstack_networking_network_v2.kx-internal-network,
    openstack_networking_subnet_v2.kx-internal-network-subnet,
    openstack_compute_instance_v2.kx-main-admin,
    openstack_blockstorage_volume_v3.kx-worker-local-storage,
    openstack_networking_floatingip_v2.kx-worker-floating-ip,
    openstack_networking_secgroup_v2.kx_security_group,
    openstack_compute_flavor_v2.kx-worker-flavor
  ]
  name      = "kx-worker${count.index + 1}"
  image_id  = local.kx_worker_image_id
  flavor_id = openstack_compute_flavor_v2.kx-worker-flavor.id
  key_pair  = openstack_compute_keypair_v2.kx-keypair.name
  region = "RegionOne"
  security_groups = [ openstack_networking_secgroup_v2.kx_security_group.name ]
  user_data       = "#cloud-config\nhostname: kx-worker${count.index + 1}"
  count = local.worker_node_count

  block_device {
    boot_index            = 0
    delete_on_termination = true
    destination_type      = "volume"
    source_type           = "image"
    volume_size           = 40
    uuid                  = local.kx_worker_image_id
  }

  network {
    uuid = openstack_networking_network_v2.kx-internal-network.id
    name = openstack_networking_subnet_v2.kx-internal-network-subnet.name
  }

  provisioner "local-exec" {
    command = "echo \"${self.network.0.fixed_ip_v4} ${self.name} ${self.name}.demo1.kx-as-code.local\">> hosts_file_entries.txt"
  }

}


