import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3"
import sharp from "sharp"
import { derivativeKey } from "./derivative_key.mjs"

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
      console.error(JSON.stringify({ level: "error", key, message: error.message }))
      throw error
    }
  }

  return { processed: results.length }
}

async function processObject(bucket, key) {
  const original = await readObject(bucket, key)

  const image = sharp(original, { failOn: "none" }).rotate()

  await Promise.all(
    SIZES.map(async (size) => {
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
