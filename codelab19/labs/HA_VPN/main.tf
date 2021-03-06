provider "google" {}

provider "google-beta" {}

locals {
  prefix       = ""
  image        = "debian-cloud/debian-9"
  machine_type = "f1-micro"
}

#============================================
# VPC Demo Configuration
#============================================

# VPC Demo Network
#------------------------------

locals {
  vpc_demo_subnet_10_1_1 = "${local.prefix}vpc-demo-subnet-10-1-1"
  vpc_demo_subnet_10_3_1 = "${local.prefix}vpc-demo-subnet-10-3-1"
}

module "vpc_demo" {
  source  = "terraform-google-modules/network/google"
  version = "0.6.0"

  project_id   = "${var.project_id}"
  network_name = "${local.prefix}vpc-demo"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${local.vpc_demo_subnet_10_1_1}"
      subnet_ip             = "10.1.1.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
      subnet_flow_logs      = true
    },
    {
      subnet_name           = "${local.vpc_demo_subnet_10_3_1}"
      subnet_ip             = "10.3.1.0/24"
      subnet_region         = "us-east1"
      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]

  secondary_ranges = {
    "${local.vpc_demo_subnet_10_1_1}" = []
    "${local.vpc_demo_subnet_10_3_1}" = []
  }
}

resource "google_compute_firewall" "vpc_demo_ssh" {
  provider    = "google-beta"
  name        = "${local.prefix}vpc-demo-ssh"
  description = "VPC demo SSH FW rule"
  network     = "${module.vpc_demo.network_self_link}"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "vpc_demo_icmp" {
  provider    = "google-beta"
  name        = "${local.prefix}vpc-demo-icmp"
  description = "VPC demo ICMP FW rule"
  network     = "${module.vpc_demo.network_self_link}"

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# VM Instance
#-----------------------------------
module "vpc_demo_vm_10_1_1" {
  source                  = "../../modules/gce-public"
  project                 = "${var.project_id}"
  name                    = "${local.prefix}vpc-demo-vm-10-1-1"
  machine_type            = "${local.machine_type}"
  zone                    = "us-central1-a"
  metadata_startup_script = "${file("scripts/startup.sh")}"
  image                   = "${local.image}"
  subnetwork_project      = "${var.project_id}"
  subnetwork              = "${module.vpc_demo.subnets_self_links[0]}"
}

module "vpc_demo_vm_10_3_1" {
  source                  = "../../modules/gce-public"
  project                 = "${var.project_id}"
  name                    = "${local.prefix}vpc-demo-vm-10-3-1"
  machine_type            = "${local.machine_type}"
  zone                    = "us-east1-b"
  metadata_startup_script = "${file("scripts/startup.sh")}"
  image                   = "${local.image}"
  subnetwork_project      = "${var.project_id}"
  subnetwork              = "${module.vpc_demo.subnets_self_links[1]}"
}

#============================================
# VPC On-prem Configuration
#============================================

locals {
  vpc_onprem_subnet_10_128_1 = "${local.prefix}vpc-onprem-subnet-10-128-1"
}

module "vpc_onprem" {
  source       = "terraform-google-modules/network/google"
  version      = "0.6.0"
  project_id   = "${var.project_id}"
  network_name = "${local.prefix}vpc-onprem"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = "${local.vpc_onprem_subnet_10_128_1}"
      subnet_ip             = "10.128.1.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = false
      subnet_flow_logs      = false
    },
  ]

  secondary_ranges = {
    "${local.vpc_onprem_subnet_10_128_1}" = []
  }
}

resource "google_compute_firewall" "vpc_onprem_ssh" {
  provider    = "google-beta"
  name        = "${local.prefix}vpc-onprem-ssh"
  description = "VPC onprem SSH FW rule"
  network     = "${module.vpc_onprem.network_self_link}"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "vpc_onprem_icmp" {
  provider    = "google-beta"
  name        = "${local.prefix}vpc-onprem-icmp"
  description = "VPC onprem ICMP FW rule"
  network     = "${module.vpc_onprem.network_self_link}"

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# VM Instance
#-----------------------------------
module "vpc_onprem_vm" {
  source                  = "../../modules/gce-public"
  project                 = "${var.project_id}"
  name                    = "${local.prefix}vpc-onprem-vm"
  machine_type            = "${local.machine_type}"
  zone                    = "us-central1-a"
  metadata_startup_script = "${file("scripts/startup.sh")}"
  image                   = "${local.image}"
  subnetwork_project      = "${var.project_id}"
  subnetwork              = "${module.vpc_onprem.subnets_self_links[0]}"
}
