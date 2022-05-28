provider "aws" {
    # Expect AWS credentials from file or env
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  type = list
}

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      "Name" = "production"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
      "Name" = "prod"
    }
}

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = var.subnet_prefix[0].cidr_block
    availability_zone = "ap-southeast-1a"

    tags = {
        Name = var.subnet_prefix[0].name
    }
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = var.subnet_prefix[1].cidr_block
    availability_zone = "ap-southeast-1a"

    tags = {
        Name = var.subnet_prefix[1].name
    }
}

resource "aws_route_table_association" "name" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"
    description = "allow web traffic"
    vpc_id = aws_vpc.prod-vpc.id

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        description = "HTTPS"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        description = "HTTP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        description = "SSH"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        description = "Allow all egress" 
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow_web"
    }
}

resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [ aws_internet_gateway.gw ] # Sets an explicit dependency
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server-instance" {
    ami               = "ami-0750a20e9959e44ff"
    instance_type     = "t2.micro"
    availability_zone = "ap-southeast-1a"
    key_name          = "normans-private"
  
    network_interface {
      device_index           = 0 
      network_interface_id   = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #!bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first webserver > /var/www/html/index.html'
                EOF
    tags = {
        Name = "webserver"
    }
}

output "server_private_ip" {
    value = aws_instance.web-server-instance.private_ip
}

output "server_id" {
    value = aws_instance.web-server-instance.id
}