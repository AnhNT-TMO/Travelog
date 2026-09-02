variable "aws_region" {
  description = "Region cho toan bo stack. Ha Noi -> ap-southeast-1 la gan nhat."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "development, staging hoac production. Di vao ten bucket va ten function."
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment phai la development, staging hoac production."
  }
}

variable "name_prefix" {
  description = "Tien to ten tai nguyen. Ten bucket la global nen phai duy nhat."
  type        = string
  default     = "travelog"
}

variable "image_sizes" {
  description = "Cac canh dai Lambda sinh ra, px. 400 = thumb, 1200 = preview."
  type        = list(number)
  default     = [400, 1200]
}

variable "webp_quality" {
  description = "Chat luong webp 1-100. 82 la diem gay cua duong cong size/chat luong."
  type        = number
  default     = 82
}

variable "cors_allowed_origins" {
  description = "Origin duoc PUT thang vao bucket originals (direct upload)."
  type        = list(string)
}

variable "lambda_memory_mb" {
  description = "sharp an RAM theo dien tich anh. 1536MB xu ly anh 12MP trong ~1.5s."
  type        = number
  default     = 1536
}

variable "lambda_timeout_s" {
  description = "Timeout Lambda. Doc + resize 2 size + PUT + webhook."
  type        = number
  default     = 60
}

variable "originals_expiration_days" {
  description = "So ngay giu anh goc o Standard truoc khi chuyen sang IA. 0 = tat."
  type        = number
  default     = 90
}

variable "cloudfront_price_class" {
  description = "PriceClass_100 = US/EU, _200 them chau A. Nguoi dung o Ha Noi nen dung _200."
  type        = string
  default     = "PriceClass_200"
}
