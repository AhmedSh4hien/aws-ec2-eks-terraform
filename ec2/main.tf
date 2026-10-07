resource "aws_key_pair" "deployer_key" {
  key_name   = "terraform-ec2-key"
  public_key = file("C:/Users/ahmed/.ssh/terraform-ec2-key.pub")
}

resource "aws_instance" "my_server" {
  ami           = "ami-0303e2e4a29f041a3"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer_key.key_name

  tags = {
    Name = "terraform-learning-server"
  }
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]  
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["178.115.80.100/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}