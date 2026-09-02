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
| EC2, Elastic IP, EBS, security group | compute (`757876532307`) | Console / CLI, profile `ladakh` |
| ECR repo `travelog` | compute | `ECR_PROFILE=ladakh`, mặc định trong `bin/kamal` |
| S3 originals + derivatives, Lambda, CloudFront | media | `terraform`, profile media |
| Access key Rails dùng để ký direct upload | media | `.env.production` |

Profile ở `~/.aws/config` (không nằm trong repo). Account compute dùng profile
`ladakh` — `bin/kamal` đã lấy đó làm mặc định nên không cần export gì:

```bash
ECR_PROFILE=khac bin/kamal deploy               # chỉ khi cần đổi
export AWS_PROFILE=<profile media>              # terraform đọc biến này
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
- **`cors_allowed_origins`** trong terraform (account media) phải khớp origin
  thật của app — hiện là `https://travelog-ac.duckdns.org`. Origin gồm **cả scheme
  và cổng**, nên đổi http→https hoặc IP→domain là phải apply lại terraform;
  không thì app vào được bình thường mà upload ảnh chết ở preflight.

Muốn bỏ hẳn access key tĩnh thì hướng đúng là: tạo IAM role ở account media cho
phép instance profile của EC2 (account compute) `sts:AssumeRole`, rồi bỏ hai
dòng key trong `config/storage.yml` để SDK tự đi credential chain. Đổi lại phải
sửa `storage.yml`, thêm instance profile, thêm trust policy — nhiều mảnh động
hơn, và `CLAUDE.md` đã xếp việc quay key vào loại giao cho người. Giữ key tĩnh
cho tới khi có lý do cụ thể.

## Việc phải làm tay (không script hoá)

Theo `CLAUDE.md`, tạo tài nguyên AWS và chạy deploy là việc của người, không
phải của agent.

### Bước 0 — repo phải có ít nhất một commit ✔

Kamal lấy tag image từ `git rev-parse HEAD`; repo không có commit thì
`bin/kamal deploy` chết ngay với `fatal: ambiguous argument 'HEAD'`.
**Đã xong** — commit `84109c8`.

Cần deploy từ cây làm việc chưa commit thì truyền tag tay:
`bin/kamal deploy --version="$(date -u +%Y%m%d%H%M%S)"`.

### Bước 1 — tài nguyên AWS (account **compute**)

```bash
# ECR repo chứa image — phải ở account compute, cùng account với EC2
aws ecr create-repository --repository-name travelog \
  --region ap-southeast-1 --profile ladakh
```

Instance đang dùng: `18.139.214.198`, **Amazon Linux 2023 aarch64** (kiểm tra
bằng `uname -m` → `aarch64`, khớp `builder.arch: arm64`).

| Thiết lập | Giá trị |
| --- | --- |
| AMI | Amazon Linux 2023, **arm64** (user `ec2-user`) |
| Instance type | `t4g.small` |
| EBS | 30 GB gp3 (image Docker cũ + WAL + backup ăn đĩa nhanh) |
| IP | Nên là Elastic IP — bản ghi A trỏ vào nó, và Google Places key khoá theo IP. IP đổi là phải sửa cả hai. |
| Security group | 22 (chỉ IP nhà/office) + **80** + **443** (0.0.0.0/0) |
| Credit specification | `standard` nếu muốn chặn hoá đơn CPU vượt mức; `unlimited` (mặc định) an toàn hơn cho lúc migrate |

Cổng **80 phải mở dù app chạy HTTPS**: nó không phục vụ app mà để Let's
Encrypt xác thực HTTP-01, cả lần cấp đầu lẫn mỗi lần gia hạn.

### DNS — chỗ dễ mất nửa ngày

Domain là `travelog-ac.duckdns.org`. Điều kiện duy nhất được tính là:

```bash
dig +short travelog-ac.duckdns.org A   # phải ra 18.139.214.198
```

**"Đã tạo bản ghi A trong Route53" KHÔNG đồng nghĩa với việc nó phân giải.**
Chỉ nameserver được delegate mới được hỏi. Kiểm tra bằng:

```bash
dig +short <domain> NS                    # ai đang authoritative
dig +short @<ns đó> <host> A             # câu trả lời thật
```

Hỏi thẳng nameserver Route53 (`@ns-345.awsdns-43.com`) sẽ ra IP ngay cả khi
domain chưa delegate cho Route53 — **đó không phải bằng chứng DNS đã xong.**

**Tạo hosted zone KHÔNG cho mình quyền sở hữu domain.** Hosted zone chỉ là cấu
hình một máy chủ DNS: "nếu ai hỏi tôi về domain này thì tôi trả lời thế này".
Quyền sở hữu đến từ việc *đăng ký* domain với nhà đăng ký, và delegation nằm ở
registry của TLD. Đã mất nửa ngày vì lẫn hai thứ này: một hosted zone được tạo
cho một domain không thuộc về mình, nên mọi bản ghi trong đó không bao giờ
được hỏi tới — và vẫn bị tính $0.50/tháng.

**Domain đang dùng: `travelog-ac.duckdns.org`** (DuckDNS, miễn phí). Lý do chọn
DuckDNS thay vì `sslip.io`/`nip.io`: DuckDNS **có trong Public Suffix List**,
nên mỗi subdomain có quota chứng chỉ Let's Encrypt riêng. Hai tên kia không có
trong PSL, tức 50 cert/tuần dùng chung cho toàn bộ người dùng dịch vụ — cert
có thể trượt vì người lạ đã dùng hết quota, và mình không làm gì được.

Kiểm tra bằng chính PSL:

```bash
curl -s https://publicsuffix.org/list/public_suffix_list.dat | grep -ix duckdns.org
```

Đổi IP của bản ghi: đăng nhập `duckdns.org`, sửa ô **current ip**. Đổi sang
domain riêng thì mua qua Route53 (`.click` $3/năm, AWS vừa là nhà đăng ký vừa
là DNS nên nó tự set delegation, không phải xin ai).

### Bước 2 — chuẩn bị box

Hai biến dùng cho mọi lệnh ssh/scp trong file này — đặt một lần mỗi phiên
terminal:

```bash
export KEY=/Users/tienanh/Desktop/anhnt_sing_key.pem
export BOX=ec2-user@18.139.214.198
chmod 600 "$KEY"   # ssh từ chối key rộng hơn 0600
```

```bash
scp -i "$KEY" infra/ec2/bootstrap.sh "$BOX":/tmp/
ssh -i "$KEY" "$BOX" 'sudo bash /tmp/bootstrap.sh'
```

Script tự nhận distro (Amazon Linux 2023 hoặc Ubuntu), tạo swap, cài Docker,
giới hạn log Docker, tạo thư mục dữ liệu, cài cron dọn image. Idempotent.

Kamal thì **không** đọc `-i`: `bin/kamal` chạy trong Docker và chỉ mount
ssh-agent, không mount `~/.ssh`. Nên key phải nằm trong agent:

```bash
ssh-add --apple-use-keychain "$KEY"
ssh-add -l                          # phải thấy key trong danh sách
```

### Bước 3 — điền cấu hình ở máy Mac

**a. `config/deploy.yml` đã điền xong** ✔ — IP, ECR registry, CDN, hai bucket,
`APP_HOST`, `APP_PROTOCOL: http`. Đối chiếu lại với terraform khi cần:

```bash
cd infra/terraform && AWS_PROFILE=<profile media> terraform output
```

**a2. CORS của bucket phải khớp origin.** Đây là bước dễ quên nhất và nó chỉ
hỏng lúc upload ảnh, không hỏng lúc deploy:

```bash
cd infra/terraform
terraform workspace select production
terraform workspace show    # PHẢI in: production
AWS_PROFILE=<profile media> terraform apply -var-file=vars/production.tfvars
```

⚠️ **Luôn kèm `-var-file`.** `terraform.tfvars` vẫn ghi
`environment = "development"`; apply nó trong workspace `production` sẽ đổi tên
bucket, tức **destroy hai bucket production đang có thật**.

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
ssh-add --apple-use-keychain "$KEY"   # Kamal trong Docker đi qua ssh-agent
bin/kamal config                      # config đã resolve — sai key là báo ở đây
bin/kamal secrets print               # in secret thật, đừng dán đi đâu
```

`ECR_PROFILE` mặc định là `ladakh` trong `bin/kamal`, không cần export.

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
ssh -i "$KEY" "$BOX" 'docker exec travelog-db pg_isready -U travelog'
bin/kamal deploy
```

Tạo user đầu tiên (seed **không** dùng ở production — nó tạo account dev):

```bash
bin/kamal console
# User.create!(email: "...", password: "...", password_confirmation: "...")
```

### Bước 5 — backup

```bash
scp -i "$KEY" infra/ec2/pg_backup.sh "$BOX":/tmp/
ssh -i "$KEY" "$BOX" 'sudo install -m 0755 /tmp/pg_backup.sh /usr/local/bin/travelog-pg-backup'
ssh -i "$KEY" "$BOX" "echo '0 19 * * * root /usr/local/bin/travelog-pg-backup' | sudo tee /etc/cron.d/travelog-backup"
ssh -i "$KEY" "$BOX" 'sudo /usr/local/bin/travelog-pg-backup'   # chạy thử ngay
```

`0 19 UTC` = 2h sáng giờ VN. Đẩy lên S3 thì tạo `/etc/travelog-backup.env`
theo hướng dẫn trong `pg_backup.sh`; không thì bật EBS snapshot bằng Data
Lifecycle Manager. **Chỉ có bản dump local là chưa đủ** — mất EBS là mất cả hai.

## Đổi tên database + role sang `travelog` (một lần, trên box đang chạy)

Repo đã đổi sang `travelog_production` / `travelog` ở `config/deploy.yml`,
`config/database.yml` và `infra/ec2/pg_backup.sh`. Database trên box thì
**chưa** — và deploy sẽ fail nếu chạy DDL sau khi deploy.

Lý do phải làm tay: image `postgres` chỉ chạy `initdb` khi `PGDATA` rỗng. Data
dir ở `/var/lib/travelog/postgres` đã có dữ liệu, nên `POSTGRES_USER` và
`POSTGRES_DB` mới **bị bỏ qua hoàn toàn** — không role nào được tạo. App boot
lên, `db:prepare` gặp `FATAL: role "travelog" does not exist`, container chết,
healthcheck 120s timeout, deploy fail.

Thứ tự bắt buộc — **DDL trước, deploy sau**:

```bash
KEY=~/.ssh/travelog-ec2.pem
BOX=ec2-user@18.139.214.198

# 1. Dump trước đã. Đây là bước không được bỏ.
ssh -i "$KEY" "$BOX" 'sudo /usr/local/bin/travelog-pg-backup && ls -la /var/lib/travelog/backups | tail -3'

# 2. Ngắt app. ALTER DATABASE ... RENAME từ chối chạy nếu còn session nào
#    đang kết nối vào database đó — Puma giữ tới 8 connection (DB_POOL).
bin/kamal app stop

# 3. Rename. Chạy từ database `postgres`, không phải từ database đang đổi tên.
ssh -i "$KEY" "$BOX" 'docker exec -i travelog-db psql -U location_project -d postgres -v ON_ERROR_STOP=1' <<'SQL'
ALTER DATABASE location_project_production RENAME TO travelog_production;
ALTER ROLE location_project RENAME TO travelog;
SQL

# 4. Đặt LẠI mật khẩu. Postgres 17 mặc định scram-sha-256 nên hash sống sót
#    qua rename, nhưng nếu server đang ở md5 thì hash bị xoá (md5 băm kèm cả
#    username) và role không đăng nhập được nữa. Đặt lại thì đúng trong cả hai
#    trường hợp — dùng CHÍNH giá trị POSTGRES_PASSWORD trong .kamal/secrets.
ssh -i "$KEY" "$BOX" "docker exec -i travelog-db psql -U travelog -d postgres -c \"ALTER ROLE travelog PASSWORD '\$POSTGRES_PASSWORD';\""

# 5. Kiểm tra trước khi deploy.
ssh -i "$KEY" "$BOX" 'docker exec travelog-db psql -U travelog -d travelog_production -c "\\conninfo" -c "SELECT count(*) FROM user_places;"'

# 6. Backup script mới (DB=travelog_production, DB_USER=travelog) — cron đang
#    trỏ tên cũ, không thay là backup fail âm thầm từ đêm nay.
scp -i "$KEY" infra/ec2/pg_backup.sh "$BOX":/tmp/
ssh -i "$KEY" "$BOX" 'sudo install -m 0755 /tmp/pg_backup.sh /usr/local/bin/travelog-pg-backup && sudo /usr/local/bin/travelog-pg-backup'

# 7. Giờ mới deploy.
bin/kamal deploy
```

Nếu bước 3 báo `database "location_project_production" is being accessed by
other users`: còn container nào đang kết nối. `bin/kamal app stop` rồi
`ssh -i "$KEY" "$BOX" 'docker ps'` để chắc chắn chỉ còn `travelog-db`.

Đường lùi: `ALTER DATABASE travelog_production RENAME TO
location_project_production;` cộng `ALTER ROLE travelog RENAME TO
location_project;`, rồi `git revert` phần đổi tên. Dump ở bước 1 chứa owner
`location_project`, nên restore vào role mới phải kèm `--no-owner`.

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
ssh -i "$KEY" "$BOX" 'free -h; docker stats --no-stream'
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
- **Hai cái bẫy của việc chạy Kamal trong Docker trên macOS**, cả hai đã xử lý
  trong `bin/kamal` và `bin/kamal-secret` — đừng vô tình đảo lại:
  - `$SSH_AUTH_SOCK` của macOS nằm dưới `/private/tmp/com.apple.launchd.*` và
    Docker Desktop **không bind-mount được** đường dẫn đó (`operation not
    supported`). Phải mount `/run/host-services/ssh-auth.sock`.
  - Image `ghcr.io/basecamp/kamal` là **Alpine không có bash**. Script nào được
    `.kamal/secrets` gọi phải là POSIX `sh`; shebang `#!/bin/bash` trả 127 và
    secret thành chuỗi rỗng **mà không báo lỗi** — deploy vẫn chạy, app boot
    với `POSTGRES_PASSWORD` trống. Luôn chạy `bin/kamal secrets print` trước
    khi deploy và nhìn xem có giá trị nào rỗng không.
- **Khai `proxy.host` là mất luôn đường vào bằng IP.** kamal-proxy chỉ nhận
  request có Host header đúng domain; gõ IP sẽ nhận 404 từ proxy với
  `"service":"","target":""` trong log. Nên khi DNS chưa phân giải mà đã bật
  `ssl: true` + `host:` thì app không vào được bằng bất kỳ URL nào. Xem log
  cert bằng `bin/kamal proxy logs` — dấu hiệu là
  `acme/autocert: ... no viable challenge type found` và `missing certificate`.
- **Let's Encrypt chặn 5 lần xác thực thất bại / giờ** cho mỗi hostname. Sau
  khi DNS lan xong thì thử **một lần**; nếu vẫn lỗi thì chờ ~1 tiếng chứ đừng
  F5 liên tục, vì mỗi lần thử là một lần thất bại bị tính.
