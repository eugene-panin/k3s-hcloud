terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.46.1"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "2.6.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  name                       = var.cluster_configuration.name
  image                      = var.cluster_configuration.image
  type                       = var.cluster_configuration.type
  location                   = var.cluster_configuration.location
  version                    = var.cluster_configuration.k3s_version
  environment                = var.cluster_configuration.environment
  range                      = var.cluster_configuration.network_range
  internal_ip                = one(hcloud_server.this.network[*]).ip
  external_ip                = hcloud_server.this.ipv4_address
  ssh_keys                   = concat([hcloud_ssh_key.this.id], var.cluster_configuration.ssh_keys)
  client_certificate_pem     = format("-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----", replace(base64decode(ssh_resource.retrieve_client_certificate.result), "/(.{64})/", "$1\n"))
  client_key_pem             = format("-----BEGIN PRIVATE KEY-----\n%s\n-----END PRIVATE KEY-----", replace(base64decode(ssh_resource.retrieve_client_key.result), "/(.{64})/", "$1\n"))
  cluster_ca_certificate_pem = format("-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----", replace(base64decode(ssh_resource.retrieve_cluster_ca_certificate.result), "/(.{64})/", "$1\n"))

}

resource "hcloud_placement_group" "this" {
  type = "spread"
  name = "${local.name}-${local.environment}"
  labels = {
    environment = local.environment
    creator     = "terraform"
  }
}

# --------Network configuration--------
resource "hcloud_network" "this" {
  name     = "${local.name}-network"
  ip_range = local.range
  labels = {
    environment = local.environment
    creator     = "terraform"
  }
}

# --------SSH keys--------
resource "tls_private_key" "deploy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "this" {
  name       = "k3s_deploy_key"
  public_key = tls_private_key.deploy.public_key_openssh
  labels = {
    environment = local.environment
    creator     = "terraform"
  }
}

# Create and install the k3s server
resource "hcloud_server" "this" {
  name               = "${local.name}-server"
  placement_group_id = hcloud_placement_group.this.id
  image              = local.image
  server_type        = local.type
  location           = local.location
  ssh_keys           = local.ssh_keys
  labels = {
    environment = local.environment
    creator     = "terraform"
  }
  public_net {
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.this.id
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
      "bash -c 'curl https://get.k3s.io | INSTALL_K3S_EXEC=\"server --node-external-ip ${local.external_ip} --node-ip ${local.internal_ip}\" INSTALL_K3S_VERSION=${local.version} sh -'"
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = tls_private_key.deploy.private_key_pem
    }
  }

  depends_on = [hcloud_network_subnet.this]
}

# -----------------Retrieve K3s configuration-----------------
resource "ssh_resource" "retrieve_config" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = hcloud_server.this.ipv4_address
  commands = [
    "sudo sed \"s/127.0.0.1/${hcloud_server.this.ipv4_address}/g\" /etc/rancher/k3s/k3s.yaml"
  ]
  user        = "root"
  private_key = tls_private_key.deploy.private_key_pem
}

# -----------------------------------------------------------------------
# Сохраняем необходимые данные для подключения провайдера к кластеру
# Retrieve client certificate
resource "ssh_resource" "retrieve_client_certificate" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = hcloud_server.this.ipv4_address
  commands = [
    "sudo grep 'client-certificate-data' /etc/rancher/k3s/k3s.yaml | awk '{print $2}'"
  ]
  user        = "root"
  private_key = tls_private_key.global.private_key_pem
}

# Retrieve client key
resource "ssh_resource" "retrieve_client_key" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = hcloud_server.this.ipv4_address
  commands = [
    "sudo grep 'client-key-data' /etc/rancher/k3s/k3s.yaml | awk '{print $2}'"
  ]
  user        = "root"
  private_key = tls_private_key.global.private_key_pem
}

# Retrieve cluster CA certificate
resource "ssh_resource" "retrieve_cluster_ca_certificate" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = hcloud_server.this.ipv4_address
  commands = [
    "sudo grep 'certificate-authority-data' /etc/rancher/k3s/k3s.yaml | awk '{print $2}'"
  ]
  user        = "root"
  private_key = tls_private_key.global.private_key_pem
}
