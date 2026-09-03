import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "slide", "thumbnail", "position", "previous", "next"]

  connect() {
    this.currentIndex = 0
    this.scrollFrame = null
    this.#render()
  }

  disconnect() {
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)
  }

  select(event) {
    this.#goTo(Number.parseInt(event.currentTarget.dataset.carouselIndex, 10))
  }

  previous() {
    this.#goTo(this.currentIndex - 1)
  }

  next() {
    this.#goTo(this.currentIndex + 1)
  }

  scroll() {
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)

    this.scrollFrame = requestAnimationFrame(() => {
      const left = this.viewportTarget.scrollLeft
      const distances = this.slideTargets.map((slide) => Math.abs(slide.offsetLeft - left))
      const closest = distances.indexOf(Math.min(...distances))

      if (closest !== this.currentIndex) {
        this.currentIndex = closest
        this.#render()
      }
    })
  }

  #goTo(index) {
    const nextIndex = Math.max(0, Math.min(index, this.slideTargets.length - 1))
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this.currentIndex = nextIndex
    this.viewportTarget.scrollTo({
      left: this.slideTargets[nextIndex].offsetLeft,
      behavior: reducedMotion ? "auto" : "smooth"
    })
    this.#render()
  }

  #render() {
    this.thumbnailTargets.forEach((thumbnail, index) => {
      thumbnail.setAttribute("aria-pressed", String(index === this.currentIndex))
    })

    if (this.hasPositionTarget) {
      this.positionTarget.textContent = `${this.currentIndex + 1} / ${this.slideTargets.length}`
    }
    if (this.hasPreviousTarget) this.previousTarget.disabled = this.currentIndex === 0
    if (this.hasNextTarget) this.nextTarget.disabled = this.currentIndex === this.slideTargets.length - 1

    this.thumbnailTargets[this.currentIndex]?.scrollIntoView({ block: "nearest", inline: "nearest" })
  }
}
