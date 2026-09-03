import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "form", "name", "kind"]

  connect() {
    this.close()
  }

  disconnect() {
    document.documentElement.classList.remove("overflow-hidden")
  }

  open(event) {
    this.kindTargets.forEach((input) => {
      input.checked = input.value === event.params.kind
    })

    this.panelTarget.hidden = false
    document.documentElement.classList.add("overflow-hidden")
    this.nameTarget.focus()
  }

  close() {
    this.panelTarget.hidden = true
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  closeOnSuccess(event) {
    if (!event.detail.success) return

    this.formTarget.reset()
    this.close()
  }
}
