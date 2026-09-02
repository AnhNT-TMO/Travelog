# Bien cho stack production. LUON apply kem -var-file va kiem tra workspace:
#
#   terraform workspace select production
#   terraform workspace show    # PHAI in ra: production
#   AWS_PROFILE=<profile media> terraform apply -var-file=vars/production.tfvars
#
# VI SAO: terraform.tfvars van dang ghi environment = "development". Apply file
# do trong workspace production se doi ten bucket sang -development, tuc
# DESTROY hai bucket production dang co that (doi ten bucket = destroy+create).
#
# Moi environment la mot stack rieng: bucket rieng, lambda rieng, CloudFront
# rieng.

environment = "production"
aws_region  = "ap-southeast-1"

# Origin duoc PUT thang vao bucket originals (Active Storage direct upload).
# Thieu hoac sai la direct upload chet o CORS preflight.
#
# CONG LA MOT PHAN CUA ORIGIN: doi cong vao thanh 3000 (them proxy.run.http_port
# vao config/deploy.yml) thi dong nay phai thanh "http://18.139.214.198:3000".
# Co domain roi thi thanh "https://<domain>". Khong co dau / o cuoi.
cors_allowed_origins = ["http://18.139.214.198"]

# HOP DONG: phai khop Photos::ThumbnailUrl::SIZES va photo_sizes trong
# config/settings/production.yml. Lech mot con so la UI hien icon loi ma
# Rails khong log gi ca.
image_sizes = [400, 1200]
