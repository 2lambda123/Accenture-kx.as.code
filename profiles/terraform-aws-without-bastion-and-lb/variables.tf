locals {
  raw_data    = jsondecode(file("profile-config.json"))
  raw_version = jsondecode(file("versions.json"))
  raw_users = fileexists("users.json") ? jsondecode(file("users.json")) : jsondecode("{\"config\":{\"owner\":{\"firstname\":\"Kx\",\"surname\":\"Hero\"},\"additionalUsers\":[]}}")

  owner_firstname = local.raw_users.config.owner.firstname
  owner_surname = local.raw_users.config.owner.surname

  owner_surname_length = length(local.owner_surname)
  firstname_substring_length = ( 8 - local.owner_surname_length ) < 1 ? 1 : ( 8 - local.owner_surname_length )

  userid = local.owner_firstname == "Kx" ? "kx.hero" : "${lower(substr(local.owner_surname, 0, 7))}${lower(substr(local.owner_firstname, 0, local.firstname_substring_length))}"

  aws_region                = local.raw_data.aws_region
  aws_availability_zone_one = local.raw_data.aws_availability_zone_one
  aws_availability_zone_two = local.raw_data.aws_availability_zone_two

  kx_main_ami_id = local.raw_data.vm_properties.kx_main_ami_id
  kx_node_ami_id = local.raw_data.vm_properties.kx_node_ami_id

  admin_main_node_instance_type   = local.raw_data.vm_properties.admin_main_node_instance_type
  replica_main_node_instance_type = local.raw_data.vm_properties.replica_main_node_instance_type
  worker_node_instance_type       = local.raw_data.vm_properties.worker_node_instance_type

  main_node_count   = local.raw_data.vm_properties.main_node_count
  worker_node_count = local.raw_data.vm_properties.worker_node_count

  vpc_id                  = local.raw_data.config.vpc_id
  subnet_id               = local.raw_data.config.subnet_id
  subnet_cidr_block       = local.raw_data.config.subnet_cidr_block
  security_group          = local.raw_data.config.security_group
  vpc_cidr_block          = local.raw_data.config.vpc_cidr_block
  private_subnet_cidr_one = local.raw_data.config.private_subnet_cidr_one
  private_subnet_cidr_two = local.raw_data.config.private_subnet_cidr_two
  public_subnet_cidr_one  = local.raw_data.config.public_subnet_cidr_one
  public_subnet_cidr_two  = local.raw_data.config.public_subnet_cidr_two
  remote_access_cidrs_admins     = local.raw_data.config.remote_access_cidrs_admins

  kx_as_code_domain             = local.raw_data.config.baseDomain
  prefix                        = local.raw_data.config.environmentPrefix == "ownerId" ? local.userid : local.raw_data.config.environmentPrefix
  mx_dns_record                 = local.raw_data.config.mxDnsRecord
  kx_version                    = local.raw_version.kxascode
  num_local_one_gb_volumes      = local.raw_data.config.local_volumes.one_gb
  num_local_five_gb_volumes     = local.raw_data.config.local_volumes.five_gb
  num_local_ten_gb_volumes      = local.raw_data.config.local_volumes.ten_gb
  num_local_thirty_gb_volumes   = local.raw_data.config.local_volumes.thirty_gb
  num_local_fifty_gb_volumes    = local.raw_data.config.local_volumes.fifty_gb
  local_storage_volume_size     =  floor(tonumber((local.raw_data.config.local_volumes.one_gb * 1.04) + ((local.raw_data.config.local_volumes.five_gb * 5) * 1.02) + ((local.raw_data.config.local_volumes.ten_gb * 10) * 1.02) + ((local.raw_data.config.local_volumes.thirty_gb * 30) * 1.02) + ((local.raw_data.config.local_volumes.fifty_gb * 50) * 1.02) + 1))
  glusterfs_storage_volume_size = local.raw_data.config.glusterFsDiskSize + 1

}
