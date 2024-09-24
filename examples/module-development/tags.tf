locals {
  dynamic_tags = {
    "Environment" = var.env
    "LastUpdated" = formatdate("DDMMYYYY:hhmmss", timestamp())

  }

  tags = merge(var.static_tags, local.dynamic_tags)
}

variable "static_tags" {
  type        = map(string)
  description = "The tags variable"
  default = {
    "CostCentre" = "671888"
    "ManagedBy"  = "Terraform"
    "Contact"    = "info@cyber.scot"
  }
}
