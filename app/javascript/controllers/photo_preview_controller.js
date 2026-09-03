import { Controller } from "@hotwired/stimulus"

const PREVIEW_WIDTH = 1200

export default class extends Controller {
  static targets = ["input", "output", "template"]

  connect() {
    this.objectUrls = []
    this.run = 0
  }

  disconnect() {
    this.#clearPreviews()
  }

  preview() {
    this.#clearPreviews()

    const files = Array.from(this.inputTarget.files)
    this.outputTarget.hidden = files.length === 0

    const images = files.map((file, index) => {
      const preview = this.templateTarget.content.cloneNode(true)
      const image = preview.querySelector("[data-photo-preview-image]")
      const name = preview.querySelector("[data-photo-preview-name]")
      const remove = preview.querySelector("[data-photo-preview-remove]")

      name.textContent = file.name
      remove.dataset.photoPreviewIndex = index
      this.outputTarget.append(preview)
      return image
    })

    this.#fill(images, files, this.run)
  }

  remove(event) {
    const removedIndex = Number.parseInt(event.currentTarget.dataset.photoPreviewIndex, 10)
    const remainingFiles = Array.from(this.inputTarget.files)
      .filter((_file, index) => index !== removedIndex)
    const transfer = new DataTransfer()

    remainingFiles.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    this.preview()
  }

  async #fill(images, files, run) {
    for (let index = 0; index < files.length; index++) {
      const objectUrl = await this.#scaledUrl(files[index])

      if (run !== this.run) {
        URL.revokeObjectURL(objectUrl)
        return
      }

      this.objectUrls.push(objectUrl)
      images[index].alt = files[index].name
      images[index].src = objectUrl
    }
  }

  async #scaledUrl(file) {
    let bitmap

    try {
      bitmap = await createImageBitmap(file)
    } catch {
      return URL.createObjectURL(file)
    }

    const scale = Math.min(1, PREVIEW_WIDTH / bitmap.width)
    const canvas = document.createElement("canvas")

    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    bitmap.close()

    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/webp", 0.8))

    canvas.width = 0
    canvas.height = 0

    return blob ? URL.createObjectURL(blob) : URL.createObjectURL(file)
  }

  #clearPreviews() {
    this.run += 1
    this.objectUrls.forEach((objectUrl) => URL.revokeObjectURL(objectUrl))
    this.objectUrls = []
    if (this.hasOutputTarget) this.outputTarget.replaceChildren()
  }
}
