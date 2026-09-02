import { Controller } from "@hotwired/stimulus"

// Autosave nội dung review: debounce 1s rồi PATCH vào form (plan §12.3).
// Server là nguồn sự thật — controller chỉ quyết định KHI NÀO gửi.
export default class extends Controller {
  static values = { delay: { type: Number, default: 1000 } }

  connect() {
    this.timer = null
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  save() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
