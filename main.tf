# tell terraform which provider this project needs.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"     #the offical AWS provider plugin
      version = "~> 5.0"      # use any 5.x version
    }
   }
  }

#configure the aws provider: which region to build in.
# after telling terraform which providers we need for this project we configure it
 
provider "aws" {
region = "us-east-1"    # credentials come automaticall from ~/.aws
}

#no credentials here just region, provider finds key in aws/cred.. automatically



# Create a VPC — our own private, isolated network inside AWS.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"   # the address range for the whole network

  tags = {
    Name = "cloud-devsecops-vpc"   # a human-friendly name shown in the console
  }
}



#Create a  subnet - a slice of the VPC's address range.

resource "aws_subnet" "public" {
  vpc_id   = aws_vpc.main.id   #which VPC this subnet belongs to
  cidr_block = "10.0.1.0/24"   #a /24 slice of the VPC's /16

  tags = {
    Name = "cloud-devsecops-public-subnet"
  }
}

# Internet Gateway - the door between the VPC and the internet coming in

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id    #attach this gateway to our vpc


tags = { 

  Name = "cloud-devsecops-igw"

 }
}


# Route table — the directions: where does traffic go?
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id   # this route table belongs to our VPC

  route {
    cidr_block = "0.0.0.0/0"                      # "0.0.0.0/0" means ALL internet addresses
    gateway_id = aws_internet_gateway.main.id     # send that traffic to our internet gateway
  }

  tags = {
    Name = "cloud-devsecops-public-rt"
  }
}

# Association — attach the route table to our subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id            # which subnet
  route_table_id = aws_route_table.public.id       # which route table to attach to it
}



#Security Group. Bouncer at the door = allows what traffic comes in and out

resource "aws_security_group" "web" {
 name = "cloud-devsecops-sg"
 description = "Allowing SSH and HTTP inbound"
 vpc_id = aws_vpc.main.id                # this security group lives in our VPC


#Ingress rule #1: allow SSH (Port 22) so we can log in remotely

ingress {
 description = "SSH"
 from_port = 22
 to_port = 22
protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]    #from any IP (we'll tighen this later"

 }

#Ingress rule #2:  allow HTTP (port 80) so the web app is reachable

ingress {
 description = "HTTP"
 from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]      #from anywhere in the internet
 
}

#Egress: allow all outbound traffic

egress {
 from_port = 0
 to_port = 0
 protocol = "-1"          #means all protocols
 cidr_blocks = ["0.0.0.0/0"]      #to anywehere

}
 
tags = { 
 Name = "cloud-devsecops-web-sg"

 }
}


#Data Source - look up latest Ubuntu 22.04 image instead of hardcoding an AMI ID

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]    #canonical's offical AWS account (makes Ubuntu)

filter {
  name      = "name"
  values     = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
 }
}

#KEY PAIR - register our existing public SSH key with AWS so we can log in

resource "aws_key_pair" "main" {
  key_name     = "cloud-desecops-key"
  public_key   = file("~/.ssh/id_ed25519.pub")    #reads our public key from disk
} 


#EC2 INSTANCE - the actual virtual server.

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id   #the Ubuntu 22.04 image we looked up
  instance_type               = "t3.micro"            #Free-tier eligible size
  subnet_id                   = aws_subnet.public.id  #live in our public subnet
  vpc_security_group_ids      = [aws_security_group.web.id]    #guarded by our web bouncer
  key_name                    = aws_key_pair.main.key_name     #use our registered key
  associate_public_ip_address = true                       #give it a pub IP so we can reach it

  tags = {
    Name = "cloud-devsecops-web"
 }
}
