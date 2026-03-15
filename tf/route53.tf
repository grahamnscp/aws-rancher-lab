# Route53 for instances

# dns entries
resource "aws_route53_record" "node" {
  zone_id = "${var.route53_zone_id}"
  count = "${var.node_count}"
  name = "node${count.index + 1}.${var.route53_subdomain}.${var.route53_domain}"
  type = "A"
  ttl = "300"
  records = ["${element(aws_eip.node-eip.*.public_ip, count.index)}"]
}

# rke cname
resource "aws_route53_record" "rke-alias" {
  zone_id = "${var.route53_zone_id}"
  count = "${var.node_count}"
  name = "rke${count.index + 1}.${var.route53_subdomain}.${var.route53_domain}"
  type = "CNAME"
  ttl = "60"
  records = ["${element(aws_route53_record.node.*.name, count.index)}"]
}

# rancher cname
resource "aws_route53_record" "rancher-alias" {
  zone_id = "${var.route53_zone_id}"
  count = "${var.node_count}"
  name = "rancher${count.index + 1}.${var.route53_subdomain}.${var.route53_domain}"
  type = "CNAME"
  ttl = "60"
  records = ["${element(aws_route53_record.node.*.name, count.index)}"]
}

