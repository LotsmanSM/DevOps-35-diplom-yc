terraform {
  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket = "lsm-diplom-bucket"
    region = "ru-central1"
    key = "lsm-diplom-bucket/terraform.tfstate"
    skip_region_validation = true
    skip_credentials_validation = true
  }
}