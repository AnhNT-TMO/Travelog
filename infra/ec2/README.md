# Deploy Travelog lên một EC2 t4g.small

Web + Postgres trên **cùng một** instance, Kamal 2 lo phần deploy. Ảnh vẫn đi
S3 + CloudFront + Lambda như cũ (`infra/terraform/`) — box này không xử lý ảnh,
đó là lý do 2 GB RAM đủ.

## Kiến trúc trên box

```
                 ┌─ EC2 t4g.small (2 vCPU Graviton, 2 GB) ──────────┐
Internet :443 ──▶│ kamal-proxy ──▶ travelog-web  (Thruster + Puma)  │
                 │   TLS/ACME       1 process, 3 threads            │
                 │                  + Solid Queue trong Puma        │
                 │                        │ network `kamal`         │
                 │                        ▼                          │
                 │                  travelog-db (postgres:17-alpine) │
                 │                  /var/lib/travelog/postgres       │
                 └───────────────────────────────────────────────────┘
Browser ──▶ S3 (PUT trực tiếp) ──▶ Lambda ──▶ CloudFront ──▶ Browser
```

| Thành phần | RAM |
| --- | --- |
| OS + dockerd | ~250 MB |
| kamal-proxy | ~40 MB |
| Puma + Solid Queue | ~500 MB |
| Postgres | ~400 MB |
| **Dùng thật** | **~1.2 GB** |

Còn lại là page cache. Đỉnh RAM là **lúc deploy** (container cũ + mới chạy song
song ~30s, ~1.7 GB) — đó là lý do `bootstrap.sh` bắt buộc tạo swap 2 GB.

## Hai AWS account

EC2 nằm ở account **compute**, còn S3 + Lambda + CloudFront ở account **media**
(`infra/terraform/`). Việc này chạy được, và gần như không phải làm gì thêm —
lý do là hai tính chất đã có sẵn của kiến trúc:

1. **Rails vào S3 bằng access key tĩnh**, không phải instance profile:
   `config/storage.yml` truyền thẳng `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
   vào Active Storage. Key đó là của IAM user account media
   (`infra/terraform/iam.tf`), nên EC2 nằm ở account nào cũng không đổi gì.
   Không cần `sts:AssumeRole`, không cần bucket policy cross-account.
2. **Pipeline ảnh một chiều** (`CLAUDE.md`): Lambda ghi derivative rồi dừng, nó
   không gọi lại vào Rails. Nên không có đường nào từ account media cần quyền
   vào account compute cả.

Cái gì nằm ở account nào:

| Thứ | Account | Credential dùng |
| --- | --- | --- |
| EC2, Elastic IP, EBS, security group | compute | Console / CLI, profile compute |
| ECR repo `travelog` | compute | `ECR_PROFILE` mà `bin/kamal` dùng |
| S3 originals + derivatives, Lambda, CloudFront | media | `terraform`, profile media |
| Access key Rails dùng để ký direct upload | media | `.env.production` |

Cấu hình hai profile ở `~/.aws/config` (không nằm trong repo):

```ini
[profile travelog-compute]
region = ap-southeast-1
# EC2 + ECR

[profile travelog-media]
region = ap-southeast-1
# S3 + Lambda + CloudFront, dùng cho terraform
```

Rồi:

```bash
export ECR_PROFILE=travelog-compute            # bin/kamal đọc biến này
export AWS_PROFILE=travelog-media              # terraform đọc biến này
```

`ECR_REGION` (dùng cho ECR, account compute) và `AWS_REGION` trong
`config/deploy.yml` → `env.clear` (region của bucket, account media) là **hai
biến riêng biệt** — để được ở hai region khác nhau, đừng gộp lại.

Ba chỗ dễ nhầm khi tách account:

- **ECR repo phải tạo ở account compute**, cùng account với EC2. Kamal chạy
  `docker login` trên chính con EC2 bằng token mình truyền vào, nên đặt ECR ở
  account media cũng chạy được — nhưng lúc đó `ECR_PROFILE` phải là profile
  media, và `registry.server` phải là account id của media. Chọn một, đừng nửa
  nọ nửa kia.
- **Google Places API key khoá theo IP** = Elastic IP ở account compute. Key
  thì quản ở Google Cloud, không liên quan AWS account nào.
- **`cors_allowed_origins`** trong terraform (account media) vẫn phải có
  `https://travelog.com`. Nó khớp theo Origin của browser, không theo account.

Muốn bỏ hẳn access key tĩnh thì hướng đúng là: tạo IAM role ở account media cho
phép instance profile của EC2 (account compute) `sts:AssumeRole`, rồi bỏ hai
dòng key trong `config/storage.yml` để SDK tự đi credential chain. Đổi lại phải
sửa `storage.yml`, thêm instance profile, thêm trust policy — nhiều mảnh động
hơn, và `CLAUDE.md` đã xếp việc quay key vào loại giao cho người. Giữ key tĩnh
cho tới khi có lý do cụ thể.

## Việc phải làm tay (không script hoá)

Theo `CLAUDE.md`, tạo tài nguyên AWS và chạy deploy là việc của người, không
phải của agent.

### Bước 0 — repo phải có ít nhất một commit

Kamal lấy tag image từ `git rev-parse HEAD`. Repo này hiện **chưa có commit
nào**, nên `bin/kamal deploy` sẽ chết ngay với `fatal: ambiguous argument
'HEAD'`. Commit trước đã (kiểm tra `git status` xem có `.env*`,
`config/master.key`, `infra/terraform/terraform.tfstate*` lọt vào không —
`.gitignore` đã chặn nhưng vẫn nên nhìn).

Cần deploy từ cây làm việc chưa commit thì truyền tag tay:
`bin/kamal deploy --version="$(date -u +%Y%m%d%H%M%S)"`.

### Bước 1 — tài nguyên AWS (account **compute**)

```bash
# ECR repo chứa image — phải ở account compute, cùng account với EC2
aws ecr create-repository --repository-name travelog \
  --region ap-southeast-1 --profile travelog-compute
# Ghi lại registryId (= COMPUTE_ACCOUNT_ID) để điền vào config/deploy.yml
```

EC2, tạo bằng console hoặc CLI (vẫn ở account compute):

| Thiết lập | Giá trị |
| --- | --- |
| AMI | Ubuntu Server 24.04 LTS, **arm64** |
| Instance type | `t4g.small` |
| EBS | 30 GB gp3 (image Docker cũ + WAL + backup ăn đĩa nhanh) |
| Elastic IP | Có — Google Places API key khoá theo IP, IP đổi là app chết |
| Security group | 22 (chỉ IP nhà/office), 80 + 443 (0.0.0.0/0) |
| Credit specification | `standard` nếu muốn chặn hoá đơn CPU vượt mức; `unlimited` (mặc định) an toàn hơn cho lúc migrate |

Cổng 80 **bắt buộc** mở: Let's Encrypt xác thực qua HTTP-01.

Rồi: bản ghi DNS `A` của `travelog.com` → Elastic IP. Làm **trước** khi deploy,
nếu không ACME fail và app không lên.

### Bước 2 — chuẩn bị box

```bash
scp -i ~/.ssh/travelog-ec2.pem infra/ec2/bootstrap.sh ubuntu@<EIP>:/tmp/
ssh -i ~/.ssh/travelog-ec2.pem ubuntu@<EIP> 'sudo bash /tmp/bootstrap.sh'
```

Script tạo swap, cài Docker, giới hạn log Docker, tạo thư mục dữ liệu, cài cron
dọn image. Idempotent.

### Bước 3 — điền cấu hình ở máy Mac

**a. Sửa các chỗ `# SỬA` trong [config/deploy.yml](../../config/deploy.yml):**
`servers.web`, `accessories.db.host`, `proxy.host` (account compute),
`registry.server` (account id của compute), và `env.clear`
(`APP_HOST`, `CDN_HOST`, hai tên bucket, `MAILER_SENDER` — account media).
Lấy giá trị account media từ terraform:

```bash
cd infra/terraform && AWS_PROFILE=travelog-media terraform output
```

**b. Tạo `.env.production`** (bị `.gitignore` chặn, chỉ nằm trên máy Mac):

```bash
cat > .env.production <<'EOF'
# Mật khẩu superuser Postgres của accessory db. Sinh mới: openssl rand -hex 24
POSTGRES_PASSWORD=

# terraform output rails_access_key_id / terraform output -raw rails_secret_access_key
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# Server-side, khoá theo Elastic IP. KHÔNG bao giờ để lộ ra browser.
GOOGLE_MAPS_API_KEY=

# Nhúng vào trang, khoá theo HTTP referrer https://travelog.com/*
GOOGLE_MAPS_BROWSER_KEY=
EOF
```

**c. Tạo `.kamal/secrets`** nếu chưa có: `cp .kamal/secrets.example .kamal/secrets`

**d. Kiểm tra trước khi bắn:**

```bash
export ECR_PROFILE=travelog-compute   # profile của account chứa ECR + EC2
ssh-add ~/.ssh/travelog-ec2.pem       # Kamal trong Docker đi qua ssh-agent
bin/kamal config                      # config đã resolve — sai key là báo ở đây
bin/kamal secrets print               # in secret thật, đừng dán đi đâu
```

`bin/kamal` sẽ dừng ngay với thông báo rõ ràng nếu `ECR_PROFILE` trỏ sai
account, thay vì để hỏng ở bước `docker login` trên server.

### Bước 4 — deploy lần đầu

```bash
bin/kamal setup
```

Nó cài Kamal trên server, boot accessory `db`, build image ở máy Mac (arm64
native), push lên ECR, rồi boot app. `bin/docker-entrypoint` chạy `db:prepare`
→ nạp `db/structure.sql` (cả `cube`/`earthdistance`/`pg_trgm`/`unaccent` và
`immutable_unaccent`) rồi migrate.

Nếu lần đầu app fail vì Postgres còn đang `initdb` (mất vài giây), boot DB
trước rồi deploy:

```bash
bin/kamal accessory boot db
ssh ubuntu@<EIP> 'docker exec travelog-db pg_isready -U location_project'
bin/kamal deploy
```

Tạo user đầu tiên (seed **không** dùng ở production — nó tạo account dev):

```bash
bin/kamal console
# User.create!(email: "...", password: "...", password_confirmation: "...")
```

### Bước 5 — backup

```bash
scp infra/ec2/pg_backup.sh ubuntu@<EIP>:/tmp/
ssh ubuntu@<EIP> 'sudo install -m 0755 /tmp/pg_backup.sh /usr/local/bin/travelog-pg-backup'
ssh ubuntu@<EIP> "echo '0 19 * * * root /usr/local/bin/travelog-pg-backup' | sudo tee /etc/cron.d/travelog-backup"
ssh ubuntu@<EIP> 'sudo /usr/local/bin/travelog-pg-backup'   # chạy thử ngay
```

`0 19 UTC` = 2h sáng giờ VN. Đẩy lên S3 thì tạo `/etc/travelog-backup.env`
theo hướng dẫn trong `pg_backup.sh`; không thì bật EBS snapshot bằng Data
Lifecycle Manager. **Chỉ có bản dump local là chưa đủ** — mất EBS là mất cả hai.

## Vận hành hằng ngày

```bash
bin/kamal deploy                 # build + push + rolling restart
bin/kamal app logs -f            # log app
bin/kamal rollback               # về bản trước (retain_containers: 2)
bin/kamal console                # rails console
bin/kamal dbc                    # psql
bin/kamal app exec 'bin/rails db:migrate'
bin/kamal details                # container nào đang chạy
```

Xem RAM/swap thật:

```bash
ssh ubuntu@<EIP> 'free -h; docker stats --no-stream'
```

`swap used` bò lên đều đặn (không chỉ nhảy lúc deploy) là dấu hiệu box đã
chật: hạ `RAILS_MAX_THREADS` hoặc `shared_buffers`, hoặc lên `t4g.medium`.

## Những chỗ dễ vỡ

- **`Photos::ThumbnailUrl::SIZES` vs `image_sizes` của terraform.** Lệch là UI
  hiện icon lỗi và Rails không log gì cả. Xem `CLAUDE.md` → Cross-App Contracts.
- **`cors_allowed_origins` của terraform production** phải có
  `https://travelog.com`, nếu không direct upload chết ở CORS preflight.
- **Google Places key khoá theo IP** — dùng Elastic IP, và nhớ cập nhật
  restriction nếu thay instance.
- **SMTP chưa cấu hình.** `config/environments/production.rb` để phần
  `smtp_settings` ở dạng comment, nên Devise "quên mật khẩu" sẽ lỗi khi gửi mail.
  App vài người dùng thì có thể sống chung, nhưng đừng ngạc nhiên.
- **`config.hosts` chưa bật.** Muốn chặn DNS rebinding thì mở comment cuối
  `production.rb`, và **phải** giữ `host_authorization` loại trừ `/up`, nếu
  không healthcheck của kamal-proxy bị chặn và deploy fail.
- **Đừng build image trên EC2.** `bundle install` + `assets:precompile` trên
  2 GB sẽ thrash. Build ở Mac (arm64 native), đó là mặc định của `bin/kamal`.
