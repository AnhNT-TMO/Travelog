# infra — pipeline ảnh

Hai thứ, chạy ngoài Rails:

- `lambda/` — hàm Node 20 nhận sự kiện S3 `ObjectCreated` trên bucket originals, sinh webp cho từng size, ghi vào bucket derivatives. Hết. Không gọi ngược về Rails.
- `terraform/` — hai bucket, CORS cho direct upload, Lambda + trigger, IAM tối thiểu, và CloudFront đứng trước bucket derivatives.

**Không có gì ở đây được apply tự động.** Tạo hoặc sửa tài nguyên AWS là việc của người, không phải của agent — xem "Hand these back to a human" trong `CLAUDE.md`.

## Luồng

```
trình duyệt ──presigned PUT──> S3 originals ──ObjectCreated──> Lambda
                                                                      │
                                                          PUT {size}/{key}.webp
                                                                      │
                                                                      ▼
                                                             S3 derivatives
                                                                      │
                                                       CloudFront (CDN_HOST)
                                                                      │
                                                                      ▼
                                                        <img srcset> trong app
```

Luồng một chiều, không có đường quay lại. `Photos::ThumbnailUrl` dựng URL tất định từ route-facing place id và tên ảnh. Rails **không cần biết** Lambda đã xong hay chưa: có file thì ảnh hiện ra, chưa có thì `photo_image_tag` hiện icon lỗi. App nội bộ cố ý không fallback về original để pipeline hỏng không bị che giấu.

Từng có một webhook HMAC báo ngược để bật cột `thumb_ready`. Đã bỏ (chốt 02.09.2026): icon lỗi đã cho biết derivative chưa sẵn sàng, còn một endpoint không xác thực bằng Devise là thứ phải bảo vệ mãi mãi chỉ để đổi lại một cột boolean.

## Hợp đồng phải sửa cùng lúc

Ba nơi giữ cùng một danh sách kích thước. Lệch một con số là 404 âm thầm, chỉ thấy trong DevTools:

| Nơi | Giá trị |
| --- | --- |
| `config/settings/<env>.yml` → `photo_sizes` | `[400, 1200]` |
| `Photos::ThumbnailUrl::SIZES` | đọc từ settings |
| `infra/terraform/variables.tf` → `image_sizes` | `[400, 1200]` |

Key được gom theo id trên route `/places/:id` (trong data model là `user_place_id`) và giữ được nhiều ảnh mà không ghi đè nhau:

| Loại | Key |
| --- | --- |
| Original | `{place-id}/{image-name}-{unique-suffix}.{ext}` |
| Thumb 400 | `{place-id}/thumb/{image-name}-{unique-suffix}.webp` |
| Preview 1200 | `{place-id}/preview/{image-name}-{unique-suffix}.webp` |

Direct upload đi qua endpoint đã xác thực `/places/:place_id/direct_uploads` để mint key trước khi browser PUT thẳng lên S3. Không dùng lại generic Active Storage direct-upload endpoint cho ảnh.

## Build Lambda

`sharp` có binary theo kiến trúc. Build trên macOS rồi zip lên sẽ lỗi `Could not load the sharp module` — hàm chạy trên `arm64` (Graviton, rẻ hơn x86 ~20%).

```bash
cd infra/lambda
npm run build   # npm ci --omit=dev --os=linux --cpu=arm64 --libc=glibc
```

Terraform tự zip thư mục `infra/lambda/` (`data "archive_file"`), nên không cần zip tay. Quên `npm run build` thì `terraform plan` dừng ngay với `Chua build Lambda` thay vì deploy một function chết lúc chạy.

Runtime handler là `src/index.handler`: Lambda nhận **tên file không có phần mở rộng** và tên export, ngăn cách bởi dấu chấm. File thật vẫn là `src/index.mjs` và export `handler`; cấu hình `src/index.mjs.handler` sẽ làm runtime tìm sai module và báo `Runtime.HandlerNotFound`.

## Apply

Mỗi môi trường là một stack riêng. Dùng **workspace** để ba stack không đè state lên nhau —
apply `staging` trong workspace của `development` sẽ phá bucket development.

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # rồi sửa
terraform init

terraform workspace new development     # lần sau: terraform workspace select development
terraform plan                          # ĐỌC plan trước khi apply
terraform apply
```

Sang môi trường khác thì đổi cả workspace lẫn `terraform.tfvars`:

```bash
terraform workspace new staging
# sửa environment = "staging" và cors_allowed_origins trong terraform.tfvars
terraform apply
```

Xong thì lấy giá trị cho Rails:

```bash
terraform output cdn_host
terraform output s3_bucket_originals
terraform output s3_bucket_derivatives
terraform output rails_access_key_id
terraform output -raw rails_secret_access_key
```

Đổ vào biến môi trường của môi trường tương ứng: `CDN_HOST`, `S3_BUCKET_ORIGINALS`, `S3_BUCKET_DERIVATIVES`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — `config/settings/<env>.yml` đọc đúng những tên này.

**Development cũng là một stack thật.** Chạy `terraform apply` với `environment = "development"` để có bucket + CloudFront riêng cho máy của bạn. Không còn MinIO: một bucket giả lập không tái hiện được CORS preflight, IAM policy hay hành vi cache của CloudFront — đúng ba thứ hay hỏng nhất, và hỏng theo kiểu chỉ lộ ra khi lên thật.

## Những chỗ dễ sai

- **`terraform.tfstate` chứa IAM secret access key.** Coi nó như file mật; đã nằm trong `.gitignore`.
- **CORS thiếu thì direct upload chết ở preflight**, và lỗi chỉ hiện trong console trình duyệt, không có gì trong log Rails. `ETag` bắt buộc phải nằm trong `expose_headers`.
- **CloudFront cache 404 trong 5 giây** (`custom_error_response`). Mặc định là 10 phút, nghĩa là ảnh vừa upload sẽ vỡ suốt 10 phút dù Lambda đã xong từ lâu.
- **`depends_on = [aws_lambda_permission.allow_s3]`** trong `aws_s3_bucket_notification` là bắt buộc. Thiếu nó, S3 từ chối với `Unable to validate the following destination configurations`.
- Bucket originals bật **versioning**: ảnh gốc là thứ duy nhất không tái tạo được. Derivatives thì không — sinh lại lúc nào cũng được.

## Kiểm tra sau khi apply

```bash
# 1. Upload một ảnh qua giao diện, rồi xem Lambda có chạy không
aws logs tail /aws/lambda/travelog-thumbnailer-development --follow

# 2. Derivative đã được ghi chưa
aws s3 ls s3://travelog-derivatives-development/<place-id>/thumb/

# 3. CloudFront phục vụ được chưa
curl -I "$(cd infra/terraform && terraform output -raw cdn_host)/<place-id>/thumb/<image-name>.webp"
```

Icon lỗi vẫn hiện sau khi Lambda chạy xong thì gần như luôn là một trong bốn: original key không theo `{place-id}/{image-name}.{ext}`, `image_sizes` lệch `photo_sizes`, `CDN_HOST` có dấu `/` ở cuối, hoặc CloudFront còn cache bản 404 cũ.
