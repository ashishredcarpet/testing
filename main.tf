provider "aws" {
  region  = "ap-south-1"
  profile = "default"
}


resource "aws_vpc" "terraform-vpc" {
  cidr_block                       = "10.10.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "terraform-subnet-01" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "terraform-subnet-01"
  }
}
resource "aws_subnet" "terraform-subnet-02" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "terraform-subnet-02"
  }
}
resource "aws_subnet" "terraform-subnet-03" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "ap-south-1c"
  tags = {
    Name = "terraform-subnet-03"
  }
}

resource "aws_internet_gateway" "terraform-ig" {
  vpc_id = aws_vpc.terraform-vpc.id
  tags = {
    Name = "terraform-ig"
  }
}



resource "aws_route_table" "terraform-router" {
  vpc_id = aws_vpc.terraform-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-ig.id
  }
  tags = {
    Name = "terraform-router"
  }
}

resource "aws_route_table_association" "terraform-attach-subnet" {
  subnet_id      = aws_subnet.terraform-subnet-01.id
  route_table_id = aws_route_table.terraform-router.id
}

resource "aws_eip" "random-ip" {
  vpc = true
  tags = {
    Name = "random-ip"
  }
}

resource "aws_nat_gateway" "terraform-nat-gw" {
  allocation_id = aws_eip.random-ip.id
  subnet_id     = aws_subnet.terraform-subnet-01.id

  tags = {
    Name = "terraform-nat-gw"
  }
}

resource "aws_route_table" "terraform-nat-gw-route-table" {
  vpc_id = aws_vpc.terraform-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.terraform-nat-gw.id
  }
}

resource "aws_route_table_association" "terraform-assign-nat-to-subnet" {
  subnet_id      = aws_subnet.terraform-subnet-02.id
  route_table_id = aws_route_table.terraform-nat-gw-route-table.id
}


resource "aws_security_group" "terraform-sg" {
  name        = "terraform-sg"
  description = "terraform security group"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description = "Inbound Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # for kubernetes api server
  ingress {
    description = "Inbound Rule"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Inbound Rule"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}

variable "ami" {
  type    = string
  default = "ami-04893cdb768d0f9ee"
}

resource "aws_key_pair" "terraform-key" {
  key_name   = "terraform-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4on3GTiWZsBS5XZCrottdyFZRnmBofdCkTvZDEx5p36NCHM6ba969XLMzoHKv+ArNqwhqQDxiTZ8gXAGcK0EcZ+uAJBCQaOmfl9qX+AWBJeC2d0Zbainw2ShLFxpXOyGQcc9MaiJAW0d+ADqvXiLkdtNdtWBRCOiv0YPa2aoq8FCLL9CaIw2u6sM+QlsKiwppRPiCJAslB5B+1Ti+x9Ce5nBZfQfcoZ+Cuf3cIRQv5GOijPoXENPO7+4N514nV7FCbJZq36sgVXgQGtmnDttj96UiBziPhfLAbzz6LvkKAbmuu4GG+C2RCBfv0SOs2Pkhf/ffWEExkYZbYmREW9TUybzn3XDSDfQROCBdlDUySr0ge/xbEOY2S3CcyKsV6221/Dc6CCyXRCJdueopIXoNfD+J0Koi0gMYzMwmHMusEkjdBzeqQhrw26ND8eBEZhUlzlOCTFutTqhgaJvKZ1G4c1BAEPEthwRE2KrtDh4KsI9rx08IulEpdwwmpHENuBk= getma@DESKTOP-59V52CL"
}



resource "aws_instance" "terraform-instance" {
  ami                         = var.ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.terraform-subnet-01.id
  security_groups             = [aws_security_group.terraform-sg.id]
  key_name                    = "terraform-key"
  associate_public_ip_address = true
  tags = {
    Name = "terraform-instance-25-03-2022"
  }
  provisioner "file" {
    source      = "script.sh"
    destination = "/home/ec2-user/script.sh"
  }
  provisioner "file" {
    source      = "master-ip.sh"
    destination = "/home/ec2-user/master-ip.sh"
  }
  provisioner "file" {
    source      = "credentials/k3s_ssh"
    destination = "/home/ec2-user/private_key"
  }

  provisioner "file" {
    source      = "worker_script.sh"
    destination = "/home/ec2-user/worker_script.sh"
  }
  provisioner "file" {
    source      = "worker_script2.sh"
    destination = "/home/ec2-user/worker_script2.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/script.sh",
      "sudo /home/ec2-user/script.sh",
      "sudo chmod +x /home/ec2-user/worker_script.sh",
      "sudo chmod +x /home/ec2-user/master-ip.sh",
      "sudo  /home/ec2-user/master-ip.sh > master.sh",
      "sudo chmod +x master.sh",
      "sudo chown ec2-user:root /home/ec2-user/worker_script.sh",
      "sudo chmod 400 /home/ec2-user/private_key",
      "sudo /home/ec2-user/worker_script.sh > /home/ec2-user/worker.sh",
      "sudo chmod +x /home/ec2-user/worker.sh",
      "sudo chmod +x /home/ec2-user/worker_script2.sh.sh",
      "sudo scp -o StrictHostKeyChecking=no -i private_key /home/ec2-user/worker.sh /home/ec2-user/master.sh ec2-user@${aws_instance.terraform-instance-private.private_ip}:/home/ec2-user/",
      "sudo ssh -o StrictHostKeyChecking=no -i private_key  ec2-user@${aws_instance.terraform-instance-private.private_ip} '/home/ec2-user/master.sh && /home/ec2-user/worker.sh && /home/ec2-user/worker_scipt2.sh && rm -rf worker.sh worker_scipt2.sh master.sh'  ",
      "rm -rf /home/ec2-user/script.sh /home/ec2-user/worker_script.sh /home/ec2-user/worker.sh /home/ec2-user/master-ip.sh "
    ]
  }
  connection {
    user        = "ec2-user"
    host        = self.public_ip
    type        = "ssh"
    private_key = file("credentials/k3s_ssh")
  }
}


resource "aws_security_group" "terraform-sg-private" {
  name        = "terraform-sg-private"
  description = "terraform security[private] group"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name = "terraform-sg-[private]"
  }
}



resource "aws_instance" "terraform-instance-private" {
  ami             = var.ami
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.terraform-subnet-02.id
  security_groups = [aws_security_group.terraform-sg-private.id]
  key_name        = "terraform-key"
  tags = {
    Name = "terraform-instance-25-03-2022-[private]"
  }
}

output "private-ip" {
  value = aws_instance.terraform-instance-private.private_ip
}



