packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

locals {
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

source "amazon-ebs" "ubuntu-prod" {
  ami_name        = "prod-lightsail-${local.timestamp}"
  ami_description = "Ubuntu 24.04 - Node.js, Docker, MongoDB, Nginx, Supabase-ready"
  instance_type   = "t3.small"
  region          = var.region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  ssh_username = "ubuntu"

  tags = {
    Name        = "prod-lightsail-${local.timestamp}"
    BuildDate   = local.timestamp
    Environment = "production"
    ManagedBy   = "packer"
  }
}

build {
  name    = "prod-lightsail"
  sources = ["source.amazon-ebs.ubuntu-prod"]

  provisioner "shell" {
    script          = "scripts/install_packages.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_node.sh"
    execute_command = "sudo -u ubuntu bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_mongodb.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_nginx.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_security.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_swap.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/config.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/setup_pm2.sh"
    execute_command = "sudo -u ubuntu bash {{.Path}}"
  }

  provisioner "shell" {
    script          = "scripts/cleanup.sh"
    execute_command = "sudo bash {{.Path}}"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
