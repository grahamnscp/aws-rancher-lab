# elastic ips

# Associate Elastic IPs to Instances
resource "aws_eip" "node-eip" {

  count = "${var.node_count}"
  instance = "${element(aws_instance.node.*.id, count.index)}"

  tags = {
    Name = "${var.prefix}_node${count.index + 1}"
  }

  depends_on = [aws_instance.node]
}

