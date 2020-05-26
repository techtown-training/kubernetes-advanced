data "template_file" "eks_bastion_bootstrap" {
  template = file("eks_bastion_bootstrap.sh")
  vars = {
    K8S_ENDPOINT = module.eks.cluster_endpoint
    K8S_CA_DATA = module.eks.cluster_certificate_authority_data
    K8S_ROLE_ARN = module.eks.cluster_iam_role_arn
    K8S_CLUSTER_NAME = local.cluster_name
    VPC_ID = module.vpc.vpc_id
    IAM_ALB = aws_iam_role.eks_alb_role.arn
    VELERO_BUCKET = aws_s3_bucket.velero.bucket
    user = "ec2-user"
    user_group = "users"
  }
}

resource "aws_instance" "eks_bastion_host" {
  ami                    = "ami-0323c3dd2da7fb37d"
  instance_type          = "t2.micro"
  key_name               = "aspe-k8s-advanced"
  monitoring             = true
  vpc_security_group_ids = [module.eks_bastion_sg.this_security_group_id]
  subnet_id              = module.vpc.public_subnets.0
  iam_instance_profile   = aws_iam_instance_profile.eks_bastion_profile.name
  user_data              = data.template_file.eks_bastion_bootstrap.rendered

  associate_public_ip_address = true

  tags = {
    Name = "${local.cluster_name}-bastion"
  }
}

module "eks_bastion_sg" {
  name        = "${local.cluster_name}-sg"
  source      = "terraform-aws-modules/security-group/aws"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule    = "all-all"
    }
  ]
}

resource "aws_iam_instance_profile" "eks_bastion_profile" {
  name = "${local.cluster_name}-profile"
  role = aws_iam_role.eks_bastion_role.name
}

resource "aws_iam_role_policy" "eks_bastion_policy" {
  name = "EKSBastionPolicy"
  role = aws_iam_role.eks_bastion_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "${aws_s3_bucket.velero.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "${aws_s3_bucket.velero.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "eks_bastion_role" {
  name = "${local.cluster_name}-bastion"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}