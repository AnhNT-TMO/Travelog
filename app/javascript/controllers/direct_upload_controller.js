import { Controller } from "@hotwired/stimulus"

// Thanh tiến trình cho direct upload, và khoá nút submit trong lúc ảnh đang
// bay lên S3 — submit sớm thì blob chưa tồn tại và Rails nhận signed id chết.
//
// Không có chuỗi hiển thị nào ở đây: phần trăm là con số, mọi nhãn đều đã nằm
// sẵn trong DOM do server render (xem app/javascript/CLAUDE.md).
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

  // `direct-upload:end` bắn cho cả thành công lẫn thất bại. Lỗi thật đi kèm
  // `direct-upload:error`, và Active Storage tự gắn data-direct-upload-error.
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
