
variable "file_ingestion_api_dns_name" { }
variable "file_ingestion_api_stage" { 
  type=string 
  default="v1" 
}
variable "client_name" { }
variable "client_partition" { }
variable "client_system_vpc_cidr" {
  type=string 
  default="192.168.0.0/16" 
}
variable "client_system_subnet_cidrs" {
  type=list(string)
  default = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24" ]
}