# Output Values:

# Domain
output "domainname" {
  value = "${var.route53_subdomain}.${var.route53_domain}"
}

# Instances
output "node-instance-private-ips" {
  value = ["${aws_instance.node.*.private_ip}"]
}
output "node-instance-public-ips" {
  value = ["${aws_eip.node-eip.*.public_ip}"]
}
output "node-instance-names" {
  value = ["${aws_route53_record.node.*.name}"]
}
output "rke-instance-names" {
  value = ["${aws_route53_record.rke-alias.*.name}"]
}
output "rancher-instance-names" {
  value = ["${aws_route53_record.rancher-alias.*.name}"]
}

