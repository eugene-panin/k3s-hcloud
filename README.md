# k3s-hcloud-install

Terraform module for installing a k3s cluster in the Hetzner cloud

- Create (one for now) virtual server.
- A private network and placement group for the server is created.
- A key pair is created for the internal operation of the deployment.
- The k3s cluster is installed on the created server
- The module returns the configuration for subsequent access to the cluster, as well as cluster_ca_certificate, client_certificate and client_key for use in other providers (for example helm)

## Usage

```hcl
module "k3s" {
  source = "git::https://github.com/eugene-panin/terraform-hcloud-k3s-cluster.git?ref=v0.0.1""
  cluster_configuration = {
    name            = "k3s-cluster"
    k3s_version     = "v1.28.7+k3s1"
    image           = "ubuntu-22.04"
    type            = "cx21"
    location        = "nbg1"
    network_range   = "10.0.0.0/16"
    environment     = "mgmt"
    ssh_keys        = []
  }
  hcloud_token = [hcloud_token]
}
```
