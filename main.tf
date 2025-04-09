
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true   # enable DNS, so instances get DNS names
  enable_dns_support   = true
  tags = {
    Name = "project-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "project-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]  # defined below in locals
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true   # instances in public subnet get public IP by default
  tags = {
    Name = "project-public-${count.index + 1}"  # e.g., project-public-1
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]  # defined below in locals
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "project-private-${count.index + 1}"
  }
}

locals {
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]    // adjust if needed
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "project-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "project-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}



// Security Group for EC2 instances (Web servers)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers (EC2 instances)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "web-sg" }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS MySQL database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description            = "Allow MySQL from web servers"
    from_port              = 3306
    to_port                = 3306
    protocol               = "tcp"
    security_groups        = [aws_security_group.web_sg.id]   // reference web SG as source
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}


resource "aws_db_subnet_group" "db_subnets" {
  name       = "project-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private[*] : subnet.id]  // include both private subnets
  tags = {
    Name = "project-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql_db" {
  identifier              = "project-mysql-db"        # name/ID of the DB instance
  engine                  = "mysql"
  engine_version          = "8.0"                     # MySQL version (adjust as needed)
  instance_class          = "db.t3.micro"             # instance size (use t2.micro for free tier)
  allocated_storage       = 20                        # 20 GB storage
  storage_type            = "gp2"
  username                = var.db_username           # master username (from input variable)
  password                = var.db_password           # master password (from input variable)
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]   # attach the RDS SG
  db_subnet_group_name    = aws_db_subnet_group.db_subnets.name  # use the private subnets
  multi_az                = false                     # (true for multi-AZ deployment if desired)
  publicly_accessible     = false                     # do not assign public IP
  skip_final_snapshot     = true                      # skip snapshot on destroy (to allow easy teardown)&#8203;:contentReference[oaicite:7]{index=7}

  tags = {
    Name = "project-mysql-db"
  }
}


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]  # Amazon-owned AMIs
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]   # Match Amazon Linux 2 AMI names
  }
}

resource "aws_instance" "web1" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true               # ensure it gets a public IP
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_name       # use the provided EC2 key pair for SSH
  tags = {
    Name = var.instance1_name  // tag the instance with the given name
  }
}

resource "aws_instance" "web2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[1].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_name
  tags = {
    Name = var.instance2_name
  }
}
