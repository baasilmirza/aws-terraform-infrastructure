terraform {
  backend "s3" {
    bucket         = "baasilmirza-tfstate-us-east-1"
    key            = "project02/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
