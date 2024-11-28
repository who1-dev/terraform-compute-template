data "terraform_remote_state" "this" {
  for_each = var.remote_data_sources
  backend  = "s3"
  config = {
    bucket = each.value.bucket
    key    = each.value.key
    region = var.region
  }
}


data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  default_tags  = merge(var.default_tags, { "AppRole" : var.app_role, "Environment" : upper(var.env), "Project" : var.namespace })
  name_prefix   = "${var.namespace}-${var.env}"
  remote_states = { for k, v in data.terraform_remote_state.this : k => v.outputs }
  ec2s          = merge(var.bastion_hosts, var.public_instances, var.private_instances)
  test          = { for k, v in var.security_group_ingress_ssh : k => v.description }
}

resource "aws_security_group" "this" {
  for_each    = var.security_groups
  name        = each.value.name
  description = each.value.description
  vpc_id      = local.remote_states["network"].details.vpcs[each.value.vpc_key].id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    local.default_tags, {
      Name = "${local.name_prefix}-${each.value.name}"
    }
  )
}

resource "aws_key_pair" "this" {
  for_each   = var.key_pairs
  key_name   = each.value.key_name
  public_key = file(each.value.public_key_location)
  tags = merge(
    local.default_tags, {
      Name = "${local.name_prefix}-${each.value.name}"
    }
  )
}

resource "aws_instance" "this" {
  for_each                    = local.ec2s
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = each.value.instance_type
  key_name                    = aws_key_pair.this[each.value.key_name].key_name
  subnet_id                   = local.remote_states["network"].details.subnets[each.value.subnet_key]
  vpc_security_group_ids      = [aws_security_group.this[each.value.sg_key].id]
  associate_public_ip_address = each.value.is_public
  user_data                   = each.value.user_data != "" ? file(each.value.user_data) : ""
  tags = merge(
    local.default_tags, {
      Name = "${local.name_prefix}-${each.value.name}"
    }
  )
  depends_on = [aws_security_group.this, aws_key_pair.this]
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  for_each          = var.security_group_ingress_ssh
  security_group_id = aws_security_group.this[each.key].id
  description       = each.value.description
  cidr_ipv4         = (each.value.source) == "all" ? "0.0.0.0/0" : (each.value.is_local) ? "${aws_instance.this[each.value.source].private_ip}/32" : "${local.remote_states[each.value.remote_key].details.ec2s[each.value.source].private_ip}/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  depends_on        = [aws_instance.this]
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ec2" {
  for_each          = var.security_group_ingress_http_ec2
  security_group_id = aws_security_group.this[each.key].id
  description       = each.value.description
  cidr_ipv4         = (each.value.source == "all") ? "0.0.0.0/0" : "${aws_instance.this[each.value.source].private_ip}/32"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  depends_on        = [aws_instance.this, aws_security_group.this]
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_sg" {
  for_each                     = var.security_group_ingress_http_to_ec2_using_sg
  security_group_id            = aws_security_group.this[each.key].id
  description                  = each.value.description
  referenced_security_group_id = aws_security_group.this[each.value.source].id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  depends_on                   = [aws_instance.this]
}


#=====================================================================================================================================
resource "aws_lb_target_group" "this" {
  for_each = var.alb_target_groups
  name     = each.value.name
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = local.remote_states[each.value.remote_key].details.vpcs[each.value.vpc_key].id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = each.value.protocol
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = var.alb_target_group_attachments
  target_group_arn = aws_lb_target_group.this[each.value.alb_tg_key].arn
  target_id        = aws_instance.this[each.value.ec2_key].id
  port             = 80
}

resource "aws_lb" "this" {
  for_each                   = var.albs
  name                       = each.value.name
  internal                   = each.value.is_internal
  load_balancer_type         = "application"
  security_groups            = [for sg in each.value.security_groups : aws_security_group.this[sg].id]
  subnets                    = [for subnet in each.value.subnets : local.remote_states[each.value.remote_key].details.subnets[subnet]]
  enable_deletion_protection = false

  tags = merge(
    local.default_tags, {
      Name = "${local.name_prefix}-${each.value.name}"
    }
  )
}

resource "aws_lb_listener" "this" {
  for_each          = var.albs
  load_balancer_arn = aws_lb.this[each.key].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  }
}

resource "aws_launch_template" "this" {
  for_each      = var.launch_templates
  name          = each.value.name
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.this[each.value.key_name].id
  user_data     = filebase64(each.value.user_data)
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [for sg in each.value.security_groups : aws_security_group.this[sg].id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.default_tags, each.value.tags)
  }
}

resource "aws_autoscaling_group" "this" {
  for_each         = var.auto_scaling_groups
  name             = each.value.name
  desired_capacity = each.value.desired_capacity
  max_size         = each.value.max_size
  min_size         = each.value.min_size
  launch_template {
    id      = aws_launch_template.this[each.value.launch_template_key].id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = [for subnet in each.value.vpc_zone_identifier_subnets : local.remote_states[each.value.remote_key].details.subnets[subnet]]
  target_group_arns         = [aws_lb_target_group.this[each.value.target_group_arns].arn]
  tag {
    key                 = "Name"
    value               = "Webserver-ASG"
    propagate_at_launch = true
  }



  depends_on = [aws_lb.this, aws_launch_template.this]
}