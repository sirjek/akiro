resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/20"
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/23"
  availability_zone = "eu-central-1c"

  tags = merge(var.standard_tags,{
    Name = "Public_Subnet"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/23"
  availability_zone = "eu-central-1a"

  tags = merge(var.standard_tags,{
    Name = "Public_Subnet"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/23"
  availability_zone = "eu-central-1c"

  tags = merge(var.standard_tags,{
    Name = "Private_Subnet"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.6.0/23"
  availability_zone = "eu-central-1a"

  tags = merge(var.standard_tags,{
    Name = "Private_Subnet"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.standard_tags,{
    Name = "IGW"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "ig" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id

}

resource "aws_nat_gateway" "p_1" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public.id

  tags = merge(var.standard_tags,{
    Name = "NAT_1"
  })

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "p_2" {
  allocation_id = aws_eip.lb_1.id
  subnet_id     = aws_subnet.public_1.id

  tags = merge(var.standard_tags,{
    Name = "NAT_2"
  })

  depends_on = [aws_internet_gateway.gw]
}
resource "aws_eip" "lb" {
  #domain   = "vpc"
}

resource "aws_eip" "lb_1" {
  #domain   = "vpc"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.p_1.id
  }

}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.p_2.id
  }

}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}