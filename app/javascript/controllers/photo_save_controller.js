import { Controller } from "@hotwired/stimulus"

const GAP_MS = 800

export default class extends Controller {
  static targets = ["button", "label"]
  static values = { url: String, progress: String, ready: String, empty: String }

  connect() {
    this.#reset()
  }

  disconnect() {
    this.#reset()
  }

  async start() {
    if (this.busy) return
    this.busy = true

    if (this.shareable) {
      await this.#share()
    } else {
      await this.#prepare()
    }

    this.busy = false
    this.#enable()
  }

  async #prepare() {
    this.#disable()
    this.#state("loading")

    const listed = await this.#list()

    if (listed.length === 0) return this.#flash(this.emptyValue)

    const files = await this.#toFiles(listed)

    if (files && this.#canShare(files)) {
      this.shareable = files
      this.#state("ready")
      this.#label(files.length > 1 ? `${this.readyValue} (${files.length})` : this.readyValue)
    } else {
      await this.#downloadEach(listed)
    }
  }

  async #share() {
    try {
      await navigator.share({ files: this.shareable })
    } catch (error) {
      if (error.name === "AbortError") return
    }

    this.shareable = null
    this.#idle()
  }

  async #list() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return []

      const { files } = await response.json()
      return files || []
    } catch {
      return []
    }
  }

  async #toFiles(listed) {
    if (!this.#shareSupported()) return null

    const files = []

    for (let index = 0; index < listed.length; index++) {
      this.#progress(index + 1, listed.length)

      const file = await this.#toFile(listed[index])
      if (!file) return null

      files.push(file)
    }

    return files
  }

  async #toFile({ url, name }) {
    try {
      const response = await fetch(url)
      if (!response.ok) return null

      const blob = await response.blob()
      return new File([ blob ], name, { type: blob.type })
    } catch {
      return null
    }
  }

  #shareSupported() {
    if (!navigator.canShare) return false
    if (!this.#touchDevice) return false

    return navigator.canShare({ files: [ new File([ "" ], "probe.jpg", { type: "image/jpeg" }) ] })
  }

  get #touchDevice() {
    return navigator.maxTouchPoints > 0 || window.matchMedia("(pointer: coarse)").matches
  }

  #canShare(files) {
    return files.length > 0 && navigator.canShare({ files })
  }

  async #downloadEach(listed) {
    for (let index = 0; index < listed.length; index++) {
      this.#progress(index + 1, listed.length)
      this.#download(listed[index])
      await this.#wait(GAP_MS)
    }

    this.#idle()
  }

  #download({ url, name }) {
    const anchor = document.createElement("a")

    anchor.href = url
    anchor.download = name
    anchor.rel = "noopener"
    anchor.dataset.turbo = "false"
    document.body.append(anchor)
    anchor.click()
    anchor.remove()
  }

  async #flash(text) {
    this.#label(text)
    await this.#wait(GAP_MS * 2)
    this.#idle()
  }

  #reset() {
    this.busy = false
    this.shareable = null
    if (this.hasLabelTarget) this.idleLabel ||= this.labelTarget.textContent.trim()
    this.#state("idle")
  }

  #idle() {
    this.#state("idle")
    this.#label(this.idleLabel)
  }

  #progress(done, total) {
    this.#label(total > 1 ? `${this.progressValue} ${done}/${total}` : this.progressValue)
  }

  #state(name) {
    this.element.dataset.state = name
  }

  #label(text) {
    if (this.hasLabelTarget) this.labelTarget.textContent = text
  }

  #disable() {
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
  }

  #enable() {
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
  }

  #wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }
}
