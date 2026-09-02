import { Controller } from "@hotwired/stimulus"

// Bottom sheet check-in — mockup M4. Sheet nằm sẵn trong DOM và chỉ bị ẩn,
// nên form vẫn submit được bình thường khi JavaScript không chạy: khi đó
// người dùng thấy nó ngay dưới trang thay vì thấy một nút chết.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.close()
  }

  disconnect() {
    document.documentElement.classList.remove("overflow-hidden")
  }

  open() {
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    document.documentElement.classList.add("overflow-hidden")
    this.panelTarget.querySelector("input, textarea, button")?.focus()
  }

  close() {
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = true
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
