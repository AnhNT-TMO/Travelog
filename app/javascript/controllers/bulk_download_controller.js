import { Controller } from "@hotwired/stimulus"

const GAP_MS = 800

export default class extends Controller {
  static targets = ["button"]
  static values = { url: String, progress: String, empty: String }

  connect() {
    this.running = false
  }

  disconnect() {
    this.running = false
  }

  async start() {
    if (this.running) return

    this.running = true
    const label = this.buttonTarget.textContent
    this.buttonTarget.disabled = true

    const files = await this.#files()

    for (let index = 0; index < files.length && this.running; index++) {
      this.#label(`${this.progressValue} ${index + 1}/${files.length}`)
      this.#save(files[index])
      await this.#wait(GAP_MS)
    }

    if (this.running && files.length === 0) {
      this.#label(this.emptyValue)
      await this.#wait(GAP_MS * 2)
    }

    this.#label(label)
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
    this.running = false
  }

  async #files() {
    const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })

    if (!response.ok) return []

    const { files } = await response.json()
    return files || []
  }

  #save({ url, name }) {
    const anchor = document.createElement("a")

    anchor.href = url
    anchor.download = name
    anchor.rel = "noopener"
    anchor.dataset.turbo = "false"
    document.body.append(anchor)
    anchor.click()
    anchor.remove()
  }

  #label(text) {
    if (this.hasButtonTarget) this.buttonTarget.textContent = text
  }

  #wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }
}
