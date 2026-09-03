import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "viewport", "slide", "carousel"]
  static values = { initialIndex: { type: Number, default: 0 } }

  connect() {
    this.currentIndex = this.initialIndexValue
    this.close()
  }

  disconnect() {
    document.documentElement.classList.remove("overflow-hidden")
  }

  open(event) {
    if (!this.hasPanelTarget) return

    this.currentIndex = Number.parseInt(event.currentTarget.dataset.lightboxIndex, 10) || 0

    this.panelTarget.hidden = false
    document.documentElement.classList.add("overflow-hidden")
    this.#lightboxCarousel()?.show(this.currentIndex, { behavior: "instant", emit: false })
    this.viewportTarget.focus()
  }

  sync(event) {
    this.currentIndex = event.detail.index
    if (event.target === this.element) return

    this.#previewCarousel()?.show(this.currentIndex, { behavior: "instant", emit: false })
  }

  close() {
    if (!this.hasPanelTarget) return

    this.panelTarget.hidden = true
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeOnBackdrop(event) {
    if (event.target.closest("img, button, a")) return

    this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  #previewCarousel() {
    return this.application.getControllerForElementAndIdentifier(this.element, "carousel")
  }

  #lightboxCarousel() {
    if (!this.hasCarouselTarget) return null

    return this.application.getControllerForElementAndIdentifier(this.carouselTarget, "carousel")
  }
}
