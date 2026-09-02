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
# ORIGIN GOM CA SCHEME VA CONG. Doi tu http://<ip> sang https://<domain> la
# doi origin, nen PHAI apply lai terraform, khong thi upload anh chet o
# preflight du app van vao duoc binh thuong. Khong co dau / o cuoi.
#
# Phai khop proxy.host + APP_PROTOCOL trong config/deploy.yml.
cors_allowed_origins = ["https://travelog.anhnt.vn"]

# HOP DONG: phai khop Photos::ThumbnailUrl::SIZES va photo_sizes trong
# config/settings/production.yml. Lech mot con so la UI hien icon loi ma
# Rails khong log gi ca.
image_sizes = [400, 1200]
