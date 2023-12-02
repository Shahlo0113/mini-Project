resource "aws_key_pair" "key" {
  key_name   = "$(var.prefix)-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_vpc" "vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "$(var.prefix)-vpc"
  }
}

resource "aws_subnet" "subnet" {
  for_each          = var.subnet
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = join("-", [var.prefix, each.key])
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "$[var.prefix]-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix}-rtb"
  }
}

resource "aws_route_table_association" "rta" {
  for_each       = var.subnet
  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.rt.id
}

resource "aws_eip" "eip" {
  for_each = var.ec2
  instance = aws_instance.server[each.key].id
  domain   = "vpc"
  # depends_on                = [aws_internet_gateway.gw]
}
output "my_eip" {
  value = { for k, v in aws_eip.eip : k => v.public_ip }
}

resource "aws_instance" "server" {

  for_each      = var.ec2
  ami           = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.key.key_name

  subnet_id = aws_subnet.subnet[each.value.subnet].id
  #vpc_security_group_ids = [module.security_groups.security_group_id["cloud_2023_sg"]] 
  vpc_security_group_ids = [module.security-groups.security_group_id["Mini_project_sg"]]
  user_data              = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> HELLO from ${each.value.server_name} </h1>" > /var/www/html/index.html                  
              EOF
  tags = {
    Name = join("_", [var.prefix, each.key])
  }
}

module "security-groups" {
  source          = "app.terraform.io/summercloud/security-groups/aws"
  version         = "3.0.0"
  vpc_id          = aws_vpc.vpc.id
  security_groups = var.security_groups

}







