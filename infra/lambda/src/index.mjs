import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3"
import sharp from "sharp"
import { derivativeKey } from "./derivative_key.mjs"

// Thumbnailer: S3 ObjectCreated trên bucket originals → sinh webp cho mỗi size
// → ghi vào bucket derivatives theo key gom theo địa điểm:
//   `{place-id}/thumb/{image-name}.webp` (400)
//   `{place-id}/preview/{image-name}.webp` (1200)
//
// Hàm này KHÔNG gọi ngược về Rails. Rails dựng URL tất định từ place id + tên
// file; derivative thiếu thì UI nội bộ hiện icon lỗi, không fallback original.
//
// Key phải khớp Photos::ThumbnailUrl. Lệch một ký tự là 404 âm thầm, chỉ nhìn
// thấy trong DevTools — xem "Cross-App Contracts" trong CLAUDE.md.

const s3 = new S3Client({})

const DERIVATIVES_BUCKET = process.env.DERIVATIVES_BUCKET
const SIZES = (process.env.IMAGE_SIZES ?? "400,1200").split(",").map((n) => parseInt(n.trim(), 10))
const WEBP_QUALITY = parseInt(process.env.WEBP_QUALITY ?? "82", 10)

export const handler = async (event) => {
  const results = []

  for (const record of event.Records ?? []) {
    const bucket = record.s3.bucket.name
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "))

    try {
      results.push(await processObject(bucket, key))
    } catch (error) {
      // Log key chứ không log body: object là ảnh riêng tư của người dùng.
      console.error(JSON.stringify({ level: "error", key, message: error.message }))
      throw error // để Lambda retry theo chính sách của nó
    }
  }

  return { processed: results.length }
}

async function processObject(bucket, key) {
  const original = await readObject(bucket, key)

  // rotate() không tham số = áp EXIF Orientation rồi xoá thẻ đó đi. Thiếu nó là
  // ảnh chụp dọc bằng điện thoại sẽ nằm ngang.
  const image = sharp(original, { failOn: "none" }).rotate()

  await Promise.all(
    SIZES.map(async (size) => {
      // withoutEnlargement: ảnh nhỏ hơn size thì giữ nguyên, không phóng to ra
      // cho mờ. resize theo cạnh dài nhất, giữ tỉ lệ.
      const body = await image
        .clone()
        .resize({ width: size, height: size, fit: "inside", withoutEnlargement: true })
        .webp({ quality: WEBP_QUALITY })
        .toBuffer()

      await s3.send(new PutObjectCommand({
        Bucket: DERIVATIVES_BUCKET,
        Key: derivativeKey(key, size),
        Body: body,
        ContentType: "image/webp",
        // Derivative là bất biến: key đã mang size trong đường dẫn nên không bao
        // giờ cần invalidate.
        CacheControl: "public, max-age=31536000, immutable"
      }))
    })
  )

  return key
}

async function readObject(bucket, key) {
  const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }))
  return Buffer.concat(await response.Body.toArray())
}
