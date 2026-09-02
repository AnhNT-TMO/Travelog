import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "bar", "percent", "submit"]

  connect() {
    this.pending = 0
    this.#renderIdle()
  }

  start() {
    this.pending += 1
    if (this.hasProgressTarget) this.progressTarget.hidden = false
    this.#lockSubmit(true)
  }

  progress(event) {
    const { progress } = event.detail
    if (this.hasBarTarget) this.barTarget.style.width = `${progress}%`
    if (this.hasPercentTarget) this.percentTarget.textContent = `${Math.round(progress)}%`
  }

  end() {
    this.pending = Math.max(0, this.pending - 1)
    if (this.pending === 0) this.#renderIdle()
  }

  #renderIdle() {
    if (this.hasProgressTarget) this.progressTarget.hidden = true
    if (this.hasBarTarget) this.barTarget.style.width = "0%"
    this.#lockSubmit(false)
  }

  #lockSubmit(locked) {
    this.submitTargets.forEach((button) => { button.disabled = locked })
  }
}
