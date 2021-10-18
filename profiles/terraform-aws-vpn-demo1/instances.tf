resource "aws_key_pair" "kx-key" {
  key_name   = "kx-key"
  public_key = file(".ssh/id_rsa.pub")
}

resource "aws_instance" "kx-main" {
  depends_on = [ aws_security_group.kx-as-code-main_sg, aws_key_pair.kx-key ]
  ami = var.KX_MAIN_AMI_ID
  key_name = aws_key_pair.kx-key.key_name
  instance_type = var.MAIN_INSTANCE_TYPE
  vpc_security_group_ids = [ aws_security_group.kx-as-code-main_sg.id ]
  subnet_id = aws_subnet.private_one.id
  source_dest_check = false
  availability_zone = var.AVAILABILITY_ZONE
  user_data_base64 = data.template_cloudinit_config.config-main.rendered

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_type = "gp2"
    volume_size = var.LOCAL_KUBE_VOLUMES_DISK_SIZE
  }

  ebs_block_device {
    device_name = "/dev/xvdc"
    volume_type = "gp2"
    volume_size = var.GLUSTERFS_KUBE_VOLUMES_DISK_SIZE
  }

  tags = {
    Name     = "KX.AS.CODE Main"
    Hostname = "kx-main.${var.KX_DOMAIN}"
  }
}

resource "aws_instance" "kx-worker" {
  depends_on = [ aws_instance.kx-main, aws_security_group.kx-as-code-worker_sg, aws_key_pair.kx-key ]
  ami = var.KX_WORKER_AMI_ID
  key_name = aws_key_pair.kx-key.key_name
  instance_type = var.WORKER_INSTANCE_TYPE
  vpc_security_group_ids = [ aws_security_group.kx-as-code-worker_sg.id ]
  subnet_id = aws_subnet.private_one.id
  source_dest_check = false
  count = var.NUM_KX_WORKER_NODES
  availability_zone = var.AVAILABILITY_ZONE
  user_data_base64 = data.template_cloudinit_config.config-worker[count.index].rendered


  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_type = "gp2"
    volume_size = var.LOCAL_KUBE_VOLUMES_DISK_SIZE
  }

  tags = {
    Name     = "KX.AS.CODE Worker ${count.index + 1}"
    Hostname = "kx-worker${count.index + 1}.${var.KX_DOMAIN}"
  }

}