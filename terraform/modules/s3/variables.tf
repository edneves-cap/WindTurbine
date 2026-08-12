variable "bucket_name" {
    description = "The name of the main S3 bucket"
    type = string
    default = "windmill-pred-data"
}

variable "csv_s3_file_name" {
    description = "The name of the main S3 bucket"
    type = string
    default = "wind_raw"
}

variable "csv_source_file_name" {
    description = "The name of the main S3 bucket"
    type = string
    default = "wind_data.csv"
}