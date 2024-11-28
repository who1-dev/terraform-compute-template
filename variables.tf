variable "default_tags" {
  type        = map(any)
  description = "Default tags to be applied to all AWS resources"
}

variable "namespace" {
  type = string
}

variable "env" {
  type    = string
  default = "dev"
}

variable "app_role" {
  type    = string
  default = "Compute"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "remote_data_sources" {
  type = map(object({
    bucket = string
    key    = string
    region = string
  }))
  default = {
  }
}

variable "bastion_hosts" {
  type = map(object({
    name          = string
    is_public     = bool
    instance_type = string
    subnet_key    = string
    sg_key        = string
    key_name      = string
    has_user_data = bool
    user_data     = string
  }))
  default = {
  }
}

variable "public_instances" {
  type = map(object({
    name          = string
    is_public     = bool
    instance_type = string
    subnet_key    = string
    key_name      = string
    sg_key        = string
    has_user_data = bool
    user_data     = string
  }))
  default = {
  }
}



variable "private_instances" {
  type = map(object({
    name          = string
    is_public     = bool
    instance_type = string
    subnet_key    = string
    key_name      = string
    sg_key        = string
    has_user_data = bool
    user_data     = string
  }))
  default = {
  }
}

variable "key_pairs" {
  type = map(object({
    name                = string
    key_name            = string
    public_key_location = string
  }))
  default = {
  }
}


variable "security_groups" {
  type = map(object({
    name        = string
    vpc_key     = string
    description = string
  }))
}

variable "security_group_ingress_ssh" {
  type = map(object({
    description = string
    is_local    = bool
    remote_key  = string
    source      = string
  }))
  default = {
  }
}

variable "security_group_ingress_http_ec2" {
  type = map(object({
    description = string
    source      = string
  }))
  default = {
  }
}

variable "security_group_ingress_http_to_ec2_using_sg" {
  type = map(object({
    description = string
    source      = string
  }))
  default = {
  }
}


variable "alb_target_groups" {
  type = map(object({
    name       = string
    vpc_key    = string
    port       = number
    protocol   = string
    remote_key = string
  }))
  default = {
  }
}


variable "alb_target_group_attachments" {
  type = map(object({
    alb_tg_key = string
    ec2_key    = string
  }))
  default = {
  }
}

variable "albs" {
  type = map(object({
    name             = string
    is_internal      = bool
    target_group_key = string
    security_groups  = list(string)
    subnets          = list(string)
    remote_key       = string
  }))
  default = {
  }
}

variable "launch_templates" {
  type = map(object({
    name            = string
    instance_type   = string
    key_name        = string
    user_data       = string
    security_groups = list(string)
    tags = object({
      Name = string
    })
  }))
  default = {
  }
}

variable "auto_scaling_groups" {
  type = map(object({
    name                        = string
    desired_capacity            = number
    max_size                    = number
    min_size                    = number
    launch_template_key         = string
    vpc_zone_identifier_subnets = list(string)
    remote_key                  = string
    target_group_arns           = string
  }))
  default = {
  }
}


