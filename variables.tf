variable "cluster_configuration" {
  description = "values for the k3s cluster"
  type = object({
    name          = string
    image         = string
    type          = string
    location      = string
    k3s_version   = string
    network_range = string
    ssh_keys      = list(string)
    environment   = string
  })
}

variable "hcloud_token" {
  sensitive = true
}
