import { Controller } from "@hotwired/stimulus"

// Slider bán kính. Debounce 300ms rồi submit form vào Turbo Frame — không
// reload trang (plan §9.3).
export default class extends Controller {
  static targets = ["input", "output"]

  connect() {
    this.timer = null
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // Cập nhật nhãn ngay, không đợi debounce.
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
