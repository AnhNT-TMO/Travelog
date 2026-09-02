const DIRECTORY_BY_SIZE = new Map([
  [400, "thumb"],
  [1200, "preview"]
])

export function derivativeKey(originalKey, size) {
  const directory = DIRECTORY_BY_SIZE.get(size)
  if (!directory) throw new Error(`Unsupported derivative size: ${size}`)

  const separator = originalKey.indexOf("/")
  if (separator <= 0 || separator === originalKey.length - 1) {
    throw new Error(`Original key must be <place-id>/<image-name>: ${originalKey}`)
  }

  const placeId = originalKey.slice(0, separator)
  const filename = originalKey.slice(separator + 1)
  if (!/^\d+$/.test(placeId) || filename.includes("/")) {
    throw new Error(`Invalid original key: ${originalKey}`)
  }

  const extensionAt = filename.lastIndexOf(".")
  const imageName = extensionAt > 0 ? filename.slice(0, extensionAt) : filename
  return `${placeId}/${directory}/${imageName}.webp`
}
