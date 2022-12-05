provider "aws" {
  region = "us-east-2"
  access_key = "AKIA6L4U3FEFMDNIME4V"
  secret_key = "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"
}
#1. Create VPC
resource "aws_vpc" "prod-vpc"{
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "ted-test"
  }
}

#2. Create Internet Gateway
resource "aws_internet_gateway" "prod-igw"{
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    "Name" = "ted-test"
  }
}

#3. Create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  tags = {
    "Name" = "ted-test"
  }
}

#4. Create a Subnet
resource "aws_subnet" "prod-subnet-public" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    "Name" = "ted-subnet"
  }
}

resource "aws_subnet" "prod-subnet-publicb" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2b"

  tags = {
    "Name" = "ted-subnetb"
  }
}
#5. Associate subnet with route table
resource "aws_route_table_association" "prod-rt-association" {
  subnet_id = aws_subnet.prod-subnet-public.id
  route_table_id = aws_route_table.prod-route-table.id
}

#6. Create security group to allow 22, 80, 443
resource "aws_security_group" "prod_allow" {
  name        = "new-web-traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "All Traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "new_web_traffic"
  }
}

#9. Create RHEL server
resource "aws_instance" "new_rhel" {
  ami = "ami-0d03b1ad793d7ac93"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "ted-key"
  associate_public_ip_address = true
  subnet_id = aws_subnet.prod-subnet-public.id
  security_groups = [aws_security_group.prod_allow.id]
  user_data = <<-EOF
              sudo dnf update -y
              sudo dnf install python3 -y
              sudo dnf -y groupinstall development
              EOF

  tags = {
    "Name" = "ted-test"
  }
}

#9. Create RHEL server
resource "aws_instance" "new_rhelb" {
  ami = "ami-0d03b1ad793d7ac93"
  instance_type = "t2.micro" 
  availability_zone = "us-east-2b"
  key_name = "ted-key"
  associate_public_ip_address = true
  subnet_id = aws_subnet.prod-subnet-publicb.id
  security_groups = [aws_security_group.prod_allow.id]
  user_data = <<-EOF
              sudo dnf update -y
              sudo dnf install python3 -y
              sudo dnf -y groupinstall development
              EOF

  tags = {
    "Name" = "ted-test"
  }
}

output "arn_data" {
  value = aws_vpc.prod-vpc.arn
}

resource "aws_db_instance" "tedrds" {
  allocated_storage    = 10
  db_name              = "tedrds"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_allow.id]
  subnets            = [aws_subnet.prod-subnet-public.id,aws_subnet.prod-subnet-publicb.id]

  enable_deletion_protection = true

  tags = {
    Environment = "ted-production"
  }
}