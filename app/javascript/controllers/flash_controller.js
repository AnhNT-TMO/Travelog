import { Controller } from "@hotwired/stimulus"

const AUTO_DISMISS_MS = 5000

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), AUTO_DISMISS_MS)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.remove()
  }
}
