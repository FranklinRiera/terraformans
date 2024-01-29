terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  ## Configuration options
  uri = "qemu:///system"
}

resource "libvirt_pool" "debianInstance" {
  name = "debianInstance"
  type = "dir"
  path = "/tmp/terraform-provider-libvirt-pool-debianInstance"
}

resource "libvirt_pool" "debianDB" {
  name = "debianDB"
  type = "dir"
  path = "/tmp/terraform-provider-libvirt-pool-debianDB"
}

# Defining VM Volume
resource "libvirt_volume" "debianInstance-qcow2" {
  name   = "debian12.qcow2"
  pool   = libvirt_pool.debianInstance.name # List storage pools using virsh pool-list
  #source = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  source = "./debian-12-generic-amd64.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "debianDB-qcow2" {
  name   = "debian12.qcow2"
  pool   = libvirt_pool.debianDB.name # List storage pools using virsh pool-list
  #source = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  source = "./debian-12-generic-amd64.qcow2"
  format = "qcow2"
}

# Use CloudInit to add our ssh-key to the instance
resource "libvirt_cloudinit_disk" "commoninitInstance" {
  name      = "commoninitInstance.iso"
  pool      = libvirt_pool.debianInstance.name #CHANGEME
  user_data = data.template_file.user_Instance.rendered
}

data "template_file" "user_Instance" {
  template = file("${path.module}/cloud_init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninitDB" {
  name      = "commoninitInstanceDB.iso"
  pool      = libvirt_pool.debianDB.name #CHANGEME
  user_data = data.template_file.user_DB.rendered
}

data "template_file" "user_DB" {
  template = file("${path.module}/cloud_init.cfg")
}

# Define KVM domain to create Instance
resource "libvirt_domain" "debianInstance" {
  name   = "debianInstance"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninitInstance.id

  network_interface {
    network_name   = "default" # List networks with virsh net-list
    hostname       = "debianInstance"
    wait_for_lease = true
  }

  disk {
    volume_id = "${libvirt_volume.debianInstance-qcow2.id}"
}

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Define KVM domain to create DB
resource "libvirt_domain" "debianDB" {
  name   = "debianDB"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninitDB.id

  network_interface {
    network_name   = "default" # List networks with virsh net-list
    hostname       = "debianDB"
    wait_for_lease = true
  }

  disk {
    volume_id = "${libvirt_volume.debianDB-qcow2.id}"
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}



resource "null_resource" "config_Instanceinventory"{
    depends_on = [
        libvirt_domain.debianInstance, 
        libvirt_domain.debianDB 
    ]
    provisioner "local-exec" {
    command = "sed 's/{{webip}}/${libvirt_domain.debianInstance.network_interface[0].addresses[0]}/' templates/inventory.yml.j2 | tee Instanceinventory.yml"
  }
}

resource "null_resource" "config_DBinventory"{
    depends_on = [
        #libvirt_domain.debianInstance, 
        #libvirt_domain.debianDB, 
        null_resource.config_Instanceinventory
    ]
    provisioner "local-exec" {
    command = "sed 's/{{DBip}}/${libvirt_domain.debianDB.network_interface[0].addresses[0]}/' templates/DBinventory.yml.j2 | tee DBinventory.yml"
  }
}

resource "null_resource" "config_myproject" {
  depends_on = [
      libvirt_domain.debianInstance, 
      libvirt_domain.debianDB
  ]
  provisioner "local-exec" {
    command = "sed 's/{{DBip}}/${libvirt_domain.debianDB.network_interface[0].addresses[0]}/' templates/myproject.py.j2 | tee myproject/myproject.py"
  }
}



resource "null_resource" "execute-playbook-Instance"{
    depends_on = [
        #libvirt_domain.debianInstance, 
        #libvirt_domain.debianDB, 
        null_resource.config_myproject, 
        null_resource.config_Instanceinventory 
    ]
    provisioner "local-exec" {
    command = "ansible-playbook playbook.yml -i Instanceinventory.yml"
  }
}

resource "null_resource" "execute-playbook-DB"{
    depends_on = [
        #libvirt_domain.debianInstance, 
        #libvirt_domain.debianDB, 
        null_resource.execute-playbook-Instance, 
        null_resource.config_DBinventory
    ]
    provisioner "local-exec" {
    command = "ansible-playbook DBplaybook.yml -i DBinventory.yml"
  }
}

# Output Instance IP
output "ipInstance" {
  value = libvirt_domain.debianInstance.network_interface[0].addresses[0]
}

# Output DB IP
output "ipDB" {
  value = libvirt_domain.debianDB.network_interface[0].addresses[0]
}
