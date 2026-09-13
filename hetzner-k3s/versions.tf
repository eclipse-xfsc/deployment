terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.66"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
