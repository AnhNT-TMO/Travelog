# Travelog

Web app nội bộ quản lý quán ăn / quán cafe / điểm tham quan: đã đến và muốn đến, kèm ảnh
của chính mình, album xuất PDF và trạng thái review Google.

Trạng thái: **đã setup xong techstack, chưa có tính năng** (Phase 1 trong bản brainstorm).

## Techstack

| Lớp | Lựa chọn |
| --- | --- |
| Runtime | Ruby 3.4.10, Rails 8.1.3.1 (MVC, `--css=tailwind --javascript=importmap`) |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS 4, Propshaft, importmap (không cần Node) |
| Database | PostgreSQL 17 + `pg_trgm`, `unaccent` |
| Jobs / Cache / Cable | Solid Queue, Solid Cache, Solid Cable (đều trên Postgres, không Redis) |
| Auth | Rails 8 authentication generator (`User`, `Session`, `Current`) |
| Storage | S3 thật ở mọi môi trường, qua `aws-sdk-s3` + Active Storage direct upload |
| PDF | `ferrum_pdf` (Chromium/CDP, pure Ruby) — **chưa cài Chromium trong image** |
| Khác | `geocoder`, `exifr`, `rubyzip`, `image_processing` |
| Deploy | Kamal 2 + Thruster (`config/deploy.yml`), PWA đã bật |

## Chạy ở local

Yêu cầu: Docker Desktop. Không cần cài Ruby trên máy.

```bash
cp .env.example .env      # sửa nếu cần
docker compose up
```

Lần đầu sẽ build image dev, `bundle install` vào volume `bundle`, rồi `bin/rails db:prepare`
tạo database và chạy migration.

| URL | |
| --- | --- |
| http://localhost:3000 | app (trang tạm hiển thị trạng thái setup) |
| http://localhost:3000/up | health check |
| `localhost:5433` | Postgres từ máy host |

### Các service trong compose

- `web` — Puma, chạy `db:prepare` trước khi boot.
- `css` — `tailwindcss:watch[always]` (biến thể `[always]` vì container không có TTY).
- `worker` — Solid Queue (`bin/jobs`), đợi `web` healthy vì `db:prepare` do `web` chạy.
- `db` — postgres:17-alpine, dữ liệu ở volume `pgdata`.

`bin/dev` (foreman) vẫn dùng được nếu chạy trực tiếp trên máy, nhưng ở Docker thì mỗi
process là một service riêng để đọc log dễ hơn.

### Lệnh hay dùng

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails test
docker compose exec web bin/rubocop
docker compose exec web bin/rails generate model Place ...
docker compose logs -f worker
docker compose down -v          # xoá luôn database + gem cache
```

## Ghi chú kiến trúc

**Platform ARM.** Compose pin `platform: ${DOCKER_PLATFORM:-linux/arm64}` — khớp cả Apple
Silicon lẫn EC2 `t4g`. Máy Intel thì đổi `DOCKER_PLATFORM=linux/amd64` trong `.env`.

**Một database duy nhất.** App, Solid Cache, Solid Queue và Solid Cable dùng chung một
database Postgres ở mọi môi trường (chốt 02.09.2026). Bảng `solid_*` là migration bình
thường trong `db/migrate` và nằm trong `db/structure.sql`. Pool phải rộng hơn số thread
web vì worker dùng chung pool — xem `config/database.yml`.

**Cấu hình theo môi trường.** `config/settings/{development,test,staging,production}.yml`,
nạp trong `config/application.rb`, đọc qua `Rails.application.config.settings`. Bí mật vẫn
để `ENV.fetch` bên trong file — file vào git. Riêng kết nối Postgres chỉ nằm ở
`config/database.yml`.

**S3 thật, kể cả ở local.** Không còn MinIO. Mỗi môi trường — development, staging,
production — có stack riêng dựng bằng `infra/terraform` (2 bucket + Lambda + CloudFront).
Trước khi chạy app lần đầu phải `terraform apply` cho `environment = "development"` rồi
đổ output vào `.env`: `S3_BUCKET_ORIGINALS`, `S3_BUCKET_DERIVATIVES`, `CDN_HOST`,
`AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`. Thiếu biến nào thì app raise
ngay lúc boot chứ không chạy rồi hỏng nửa chừng.

Lý do bỏ MinIO: bucket giả không tái hiện được CORS preflight, IAM policy hay hành vi
cache của CloudFront — đúng ba thứ hay hỏng nhất, và hỏng theo kiểu chỉ lộ ra khi lên thật.

**Ảnh.** Trình duyệt PUT thẳng lên S3 bằng presigned URL (Active Storage direct upload),
Original được gom theo `/places/:id`: `{place-id}/{image-name}.{ext}`. Lambda sinh bản
400 vào `{place-id}/thumb/{image-name}.webp` và bản 1200 vào
`{place-id}/preview/{image-name}.webp`; CloudFront phục vụ. Rails không chờ callback và
không fallback về ảnh gốc — thiếu derivative thì UI hiện icon lỗi. Xem `infra/README.md`.

**Chromium cho PDF.** Gem `ferrum_pdf` đã có trong Gemfile nhưng image chưa cài Chromium.
Khi làm Phase 3, thêm `chromium` vào `Dockerfile.dev` + `Dockerfile`, và tách một worker
Solid Queue riêng cho queue `pdf` với `threads: 1, processes: 1` (render PDF ăn ~1GB RAM).

**Trang chủ hiện tại** (`HomeController#index`) chỉ là trang tạm để kiểm tra layout,
Tailwind, importmap và kết nối DB. Phase 1 sẽ thay bằng trang "Bộ sưu tập".

## Production image

`Dockerfile` là image production do Rails sinh ra (Thruster + non-root user), dùng bởi
Kamal. Build thử ở local:

```bash
docker build -t travelog .
```

## Deploy

Một EC2 `t4g.small` chạy cả web lẫn Postgres, Kamal 2 lo phần deploy — runbook
đầy đủ ở [`infra/ec2/README.md`](infra/ec2/README.md).

```bash
bin/kamal deploy       # chạy ở HOST, Kamal trong Docker vì máy không có Ruby
bin/kamal app logs -f
bin/kamal rollback
```

`config/deploy.yml` còn placeholder `# SỬA` (Elastic IP, ECR account, CDN host,
tên bucket) — điền trước lần deploy đầu.
