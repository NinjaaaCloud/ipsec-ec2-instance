# Configure the AWS provider - sets up AWS as the cloud provider with specified region
provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {}
}

resource "random_string" "rand" {
  length = 8
  lower  = true
  upper = false
  special = false 
  numeric = true
}

# Data source to get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu22" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role for AWS Systems Manager Session Manager access
resource "aws_iam_role" "session_manager_role" {
  name = "SessionManagerRole-${random_string.rand.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "session_manager_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.session_manager_role.name
}

resource "aws_iam_instance_profile" "session_manager_profile" {
  name = "SessionManagerProfile-${random_string.rand.result}"
  role = aws_iam_role.session_manager_role.name
}

# VPC for Wavelength Zone deployment
resource "aws_vpc" "region_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "region-vpc"
  }
}

# Internet Gateway for region VPC
resource "aws_internet_gateway" "region_igw" {
  vpc_id = aws_vpc.region_vpc.id

  tags = {
    Name = "region-internet-gateway"
  }
}


# Region subnet
resource "aws_subnet" "region_subnet" {
  vpc_id            = aws_vpc.region_vpc.id
  cidr_block        = "10.100.1.0/24"
  availability_zone = "${var.aws_region}a"  
  tags = {
    Name = "region-subnet"
  }
}

# Route table for region VPC
resource "aws_route_table" "region_rt" {
  vpc_id = aws_vpc.region_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.region_igw.id
  }

    route {
    cidr_block =     "10.0.0.0/8"  
    network_interface_id = module.ipsec-region.main_eni
  }

  route {
    cidr_block =     "172.16.0.0/12"  
    network_interface_id = module.ipsec-region.main_eni
  }

    route {
    cidr_block =     "192.168.0.0/16"  
    network_interface_id = module.ipsec-region.main_eni
  }


  tags = {
    Name = "region-route-table"
  }
}

# Associate route table with region subnet
resource "aws_route_table_association" "region_rt_assoc" {
  subnet_id      = aws_subnet.region_subnet.id
  route_table_id = aws_route_table.region_rt.id
}

# Create Elastic IP for the region instance
resource "aws_eip" "region_ip" {
  domain = "vpc"
  tags = {
    Name = "Region-Instance-EIP"
  }
}


# VPC for Wavelength Zone deployment
resource "aws_vpc" "wavelength_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "wavelength-vpc"
  }
}

# Carrier Gateway for Wavelength Zone
resource "aws_ec2_carrier_gateway" "wavelength_cgw" {
  vpc_id = aws_vpc.wavelength_vpc.id

  tags = {
    Name = "wavelength-carrier-gateway"
  }
}




# Route table for Wavelength subnet
resource "aws_route_table" "wavelength_rt-sub1" {
  vpc_id = aws_vpc.wavelength_vpc.id

  route {
    cidr_block         = "0.0.0.0/0"
    carrier_gateway_id = aws_ec2_carrier_gateway.wavelength_cgw.id
  }

  route {
    cidr_block =     "10.0.0.0/8"  
    network_interface_id = module.ipsec-wlz.main_eni
  }

  route {
    cidr_block =     "172.16.0.0/12"  
    network_interface_id = module.ipsec-wlz.main_eni
  }

    route {
    cidr_block =     "192.168.0.0/16"  
    network_interface_id = module.ipsec-wlz.main_eni
  }

  tags = {
    Name = "wavelength-route-table"
  }
}

# Wavelength subnet
resource "aws_subnet" "wavelength_subnet" {
  vpc_id            = aws_vpc.wavelength_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availabilityzone_wavelength

  tags = {
    Name = "wavelength-subnet"
  }
}

# Associate route table with Wavelength subnet
resource "aws_route_table_association" "wavelength_rt_assoc" {
  subnet_id      = aws_subnet.wavelength_subnet.id
  route_table_id = aws_route_table.wavelength_rt-sub1.id
}

# Create Elastic IP for the instance
resource "aws_eip" "wavelength_ip" {
  network_border_group = var.network_border_group
  tags = {
    Name = "IPSec-BGP-Instance-EIP"
  }
}




### TEST Multi VPC

# VPC-2 for Wavelength Zone deployment
resource "aws_vpc" "wavelength_vpc_2" {
  cidr_block           = "192.168.0.0/23"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "wavelength-vpc-2"
  }
}

# Wavelength subnet
resource "aws_subnet" "wavelength_subnet_vpc_2" {
  vpc_id            = aws_vpc.wavelength_vpc_2.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = var.availabilityzone_wavelength

  tags = {
    Name = "wavelength-subnet-vpc-2"
  }
}

# Route table for Wavelength subnet
resource "aws_route_table" "wavelength_rt-sub2" {
  vpc_id = aws_vpc.wavelength_vpc_2.id

  /*route {
    cidr_block         = "0.0.0.0/0"
    network_interface_id = module.ipsec-wlz.secondary_enis[0].eni_id
  }*/

    route {
    cidr_block =     "10.0.0.0/8"  
    network_interface_id = module.ipsec-wlz.secondary_enis[0].eni_id
  }

  route {
    cidr_block =     "172.16.0.0/12"  
    network_interface_id = module.ipsec-wlz.secondary_enis[0].eni_id
  }

    route {
    cidr_block =     "192.168.0.0/16"  
    network_interface_id = module.ipsec-wlz.secondary_enis[0].eni_id
  }

  tags = {
    Name = "wavelength-route-table-sub2"
  }
}

# Associate route table with Wavelength subnet
resource "aws_route_table_association" "wavelength_rt2_assoc" {
  subnet_id      = aws_subnet.wavelength_subnet_vpc_2.id
  route_table_id = aws_route_table.wavelength_rt-sub2.id
}


# Test instance in wavelength VPC 2
resource "aws_instance" "test_instance_vpc2" {
  ami           = data.aws_ami.ubuntu22.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.wavelength_subnet_vpc_2.id

  iam_instance_profile = aws_iam_instance_profile.session_manager_profile.name

  vpc_security_group_ids = [aws_security_group.test_sg.id]



  tags = {
    Name = "test-instance-vpc2"
  }
}



# Security group for test instance
resource "aws_security_group" "test_sg" {
  name        = "test-security-group"
  description = "Security group for test instance"
  vpc_id      = aws_vpc.wavelength_vpc_2.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test-security-group"
  }
}


# Test instance in Region
resource "aws_instance" "test_instance_region" {
  ami           = data.aws_ami.ubuntu22.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.region_subnet.id

  iam_instance_profile = aws_iam_instance_profile.session_manager_profile.name

  vpc_security_group_ids = [aws_security_group.testregion_sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "test-instance-region"
  }
}



# Security group for test instance Region
resource "aws_security_group" "testregion_sg" {
  name        = "test-security-group"
  description = "Security group for test instance"
  vpc_id      = aws_vpc.region_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tesregion-security-group"
  }
}



module "ipsec-wlz"  {
  source = "../"

  vpc_id              = aws_vpc.wavelength_vpc.id
  subnet_id           = aws_subnet.wavelength_subnet.id
  key_pair_name       = var.key_pair_name
  remote_public_ip   = aws_eip.region_ip.public_ip
  elastic_ip         = aws_eip.wavelength_ip.id
  remote_private_ip  = var.private_ip_2
  local_private_ip   = var.private_ip_1
  ipsec_psk          = var.ipsec_psk
  bgp_asn_local      = var.bgp_asn_local
  bgp_asn_remote     = var.bgp_asn_remote
  is_wlz             = true
  mark               = 1
  bgp_password       = "klghfdghlksfdghljk"

  # Multiple secondary VPCs configuration
  secondary_vpcs = [
    {
      vpc_id      = aws_vpc.wavelength_vpc_2.id
      subnet_id   = aws_subnet.wavelength_subnet_vpc_2.id
      description = "Cross-VPC ENI for VPC 1"
      security_group_rules = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["10.0.0.0/8"]
        }
      ]
    }
  ]

  depends_on = [ aws_eip.wavelength_ip, aws_eip.region_ip ]
}

module "ipsec-region"  {
  source = "../"

  vpc_id              = aws_vpc.region_vpc.id
  subnet_id           = aws_subnet.region_subnet.id
  key_pair_name       = var.key_pair_name
  remote_public_ip    = aws_eip.wavelength_ip.carrier_ip 
  elastic_ip         = aws_eip.region_ip.id
  remote_private_ip  = var.private_ip_1
  local_private_ip   = var.private_ip_2
  ipsec_psk          = var.ipsec_psk
  bgp_asn_local      = var.bgp_asn_remote
  bgp_asn_remote     = var.bgp_asn_local
  mark               = 1
  bgp_password       = "klghfdghlksfdghljk"

  depends_on = [ aws_eip.region_ip, aws_eip.wavelength_ip ]

}

