import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  connect() {
    this.timer = null
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  preview() {
    this.#renderLabel()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 300)
  }

  submit() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }

  #renderLabel() {
    if (!this.hasOutputTarget) return
    const km = Number(this.inputTarget.value) / 1000
    this.outputTarget.textContent = `${km.toFixed(1)} km`
  }
}
