data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "devops-demo-dev-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "allow_ssh" {
    name        = "devops-demo-dev-ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_server" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  metadata_options {
    http_tokens = "required"
  }

    tags = {
    Name        = "devops-demo-dev-ec2"
    Project     = "devops-demo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}