variable "instance1_name" {
  description = "Name tag for the first EC2 instance"
  type        = string
    default = "instance2"

}

variable "instance2_name" {
  description = "Name tag for the second EC2 instance"
  type        = string
  default = "instance2"
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair to attach to the instances for SSH access"
  type        = string
  default      = "iac.ppk"
}

variable "db_username" {
  description = "Master username for the RDS MySQL database"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS MySQL database"
  type        = string
  sensitive   = true
}
