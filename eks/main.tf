resource "aws_security_group" "cluster_sg" {
  name        = "cluster_sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Cluster Communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Communication from Nodes to Cluster"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.node_cluster_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.standard_tags, {
    Name = "cluster_sg"
  })

}

resource "aws_security_group" "node_cluster_sg" {
  name_prefix = "cluster_node"
  description = "Node to Cluster Security Group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.standard_tags, {
    Name = "node_cluster_sg"
  })


}

# Node Security Group
resource "aws_security_group" "node_sg" {
  name_prefix = "node"
  description = "Node Security Group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Access from the Cluster Security Group"
    from_port   = 0
    protocol    = -1
    to_port     = 0
    security_groups = [
      aws_security_group.cluster_sg.id
    ]
  }

  ingress {
    description = "TLS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }


  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Node Communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow outgoing access to the Cluster Security Group"
    from_port   = 0
    protocol    = -1
    to_port     = 0
    security_groups = [
      aws_security_group.cluster_sg.id
    ]
  }

  tags = merge(var.standard_tags, {
    Name = "node_sg"
  })

}


resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.cluster_role.arn
  version                   = "1.26"
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster_sg.id]
  }

  tags = var.standard_tags

  encryption_config {
    provider {
      key_arn = aws_kms_key.encrypt-cluster.arn
    }
    resources = ["secrets"]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    aws_kms_key.encrypt-cluster
  ]

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_kms_key" "encrypt-cluster" {
  description         = "CLUSTER ENCRYPTION CONFIG"
  enable_key_rotation = false
  policy              = data.aws_iam_policy_document.encrypt.json
  tags                = var.standard_tags
}

data "aws_iam_policy_document" "encrypt" {
  # Copy of default KMS policy that lets you manage it
  statement {
    actions = [
      "kms:*"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster_role.arn, aws_iam_role.node_iam_role.arn]
    }

  }
}

resource "aws_kms_alias" "encrypt-cluster" {
  name          = "alias/encryption-kms"
  target_key_id = aws_kms_key.encrypt-cluster.key_id
}


data "tls_certificate" "this" {
  depends_on = [aws_eks_cluster.this]
  url        = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  depends_on      = [data.tls_certificate.this]
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.this.certificates.*.sha1_fingerprint
  url             = data.tls_certificate.this.url
  tags            = var.standard_tags
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "aws_key_pair" "this" {
  depends_on      = [tls_private_key.this]
  key_name_prefix = var.cluster_name
  public_key      = tls_private_key.this.public_key_openssh
  tags            = var.standard_tags
}

resource "aws_kms_key" "ebs-kms" {
  description         = "EBS KMS KEY"
  enable_key_rotation = false
  policy              = data.aws_iam_policy_document.ebs.json
  tags                = var.standard_tags
}

data "aws_iam_policy_document" "ebs" {
  # Copy of default KMS policy that lets you manage it
  
  statement {
    actions = [
      "kms:*"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        aws_iam_role.cluster_role.arn, aws_iam_role.node_iam_role.arn                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
  }

}

resource "aws_kms_alias" "ebs-kms" {
  name          = "alias/ebs-kms"
  target_key_id = aws_kms_key.ebs-kms.key_id
}
resource "aws_launch_template" "main" {
  name = "akiro-launch-template"

  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 75
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs-kms.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  tags = var.standard_tags

  vpc_security_group_ids = [
    aws_security_group.node_sg.id,
  ]
}


resource "aws_eks_node_group" "this" {
  cluster_name         = aws_eks_cluster.this.name
  node_group_name      = "node-group-1"
  node_role_arn        = aws_iam_role.node_iam_role.arn
  subnet_ids           = var.subnet_ids
  ami_type             = "AL2_x86_64"
  instance_types       = var.eks_instance_types
  force_update_version = true
  scaling_config {
    desired_size = "1"
    max_size     = "2"
    min_size     = "1"
  }

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }
  update_config {
    max_unavailable = 1
  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_key_pair.this,
    aws_eks_addon.kube-proxy,
    aws_eks_addon.cni
  ]

  tags = merge(var.standard_tags, {
    "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
  })
}
resource "aws_eks_addon" "coredns" {
  depends_on        = [aws_eks_node_group.this]
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "coredns"
  addon_version     = "v1.9.3-eksbuild.2" #e.g., previous version v1.8.7-eksbuild.2 and the new version is v1.8.7-eksbuild.3
  resolve_conflicts = "OVERWRITE"
  tags              = var.standard_tags
}

resource "aws_eks_addon" "kube-proxy" {
  depends_on        = [aws_eks_cluster.this]
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "kube-proxy"
  addon_version     = "v1.24.10-eksbuild.2" #e.g., previous version v1.8.7-eksbuild.2 and the new version is v1.8.7-eksbuild.3
  resolve_conflicts = "OVERWRITE"
  tags              = var.standard_tags
}

resource "aws_eks_addon" "cni" {
  depends_on        = [aws_eks_cluster.this]
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "vpc-cni"
  addon_version     = "v1.12.5-eksbuild.2" #e.g., previous version v1.8.7-eksbuild.2 and the new version is v1.8.7-eksbuild.3
  resolve_conflicts = "OVERWRITE"
  configuration_values = jsonencode({
    env = {
      POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
      ANNOTATE_POD_IP                   = "true"
    }
  })
  tags = var.standard_tags
}

