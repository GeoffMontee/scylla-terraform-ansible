provider "google" {
  project = var.project_id
  region  = var.region
}

provider "random" {
  // Nothing to do here
}

resource "google_compute_instance" "scylla-loader" {
  count        = 3
  name         = "faisal-scylla-loader-${format("%02d", count.index + 1)}"
  machine_type = "n2-highmem-2"
  zone         = var.zone
  min_cpu_platform = "Intel Ice Lake"
  tags = ["keep", "alive", "ssh"]

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
    ]
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_public_key_path)
      host        = self.network_interface.0.access_config.0.nat_ip
    }
  }

  boot_disk {
      initialize_params {
        image = "ubuntu-2204-lts"
      }
  }

  scratch_disk {
    interface = "NVME"
  }

  network_interface {
    network = "default"

    access_config {
    }
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-${random_id.firewall_suffix.hex}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "random_id" "firewall_suffix" {
  byte_length = 2
}

output "internal_ips" {
  value = google_compute_instance.scylla-loader[*].network_interface.0.network_ip
  description = "Iternal IP addresses of the instances"
}

output "public_ips" {
  value = google_compute_instance.scylla-loader[*].network_interface.0.access_config.0.nat_ip
  description = "Public IP addresses of the instances"
}