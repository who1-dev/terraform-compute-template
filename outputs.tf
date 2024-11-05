output "details" {
  value = {
    ec2s = { for k, v in aws_instance.this : k => { id = v.id, private_ip = v.private_ip } }
    albs = { for k, v in aws_lb.this : k => { id = v.id, dns_name = v.dns_name } }
  }
}