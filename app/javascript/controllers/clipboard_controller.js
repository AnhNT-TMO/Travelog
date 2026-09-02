import { Controller } from "@hotwired/stimulus"

// Nút "Copy nội dung" của bộ kit review (plan §12.3).
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedLabel: { type: String, default: "Đã copy ✓" } }

  async copy(event) {
    event.preventDefault()
    if (!this.hasSourceTarget) return

    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.#flash()
    } catch {
      // clipboard API cần secure context; fallback để người dùng tự copy.
      this.sourceTarget.select?.()
    }
  }

  #flash() {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedLabelValue
    setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
