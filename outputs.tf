output alb_url {
  value = "http://${aws_lb.elb.dns_name}"
}

output alb {
  value = aws_lb.elb
}

output s3_bucket_name {
  value = aws_s3_bucket.codedeploy_s3.bucket
}