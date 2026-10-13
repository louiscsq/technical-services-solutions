terraform {
  required_version = "~> 1.3"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.117" # >= 1.117 required for UC file events: 1.88 fixed provided_sqs.queue_url being cleared on update, 1.117 fixed enable_file_events = false being dropped on create
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.76, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
