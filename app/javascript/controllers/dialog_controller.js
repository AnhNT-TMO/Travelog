import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.element.open) this.element.close()
    this.element.showModal()
  }

  disconnect() {
    if (this.element.open) this.element.close()
  }
}
