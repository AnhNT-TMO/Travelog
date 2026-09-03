import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "slide", "thumbnail", "thumbnailViewport", "position", "previous", "next"]
  static values = { initialIndex: { type: Number, default: 0 } }

  connect() {
    this.currentIndex = this.#boundedIndex(this.initialIndexValue)
    this.programmaticIndex = null
    this.scrollFrame = null
    this.scrollTimer = null
    this.viewportTarget.scrollTo({
      left: this.slideTargets[this.currentIndex].offsetLeft,
      behavior: "instant"
    })
    this.#render()
  }

  disconnect() {
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)
    if (this.scrollTimer) clearTimeout(this.scrollTimer)
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

  navigate(event) {
    if (event.key === "ArrowLeft") this.previous()
    else if (event.key === "ArrowRight") this.next()
    else return

    event.preventDefault()
  }

  scroll() {
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)

    this.scrollFrame = requestAnimationFrame(() => {
      if (this.programmaticIndex === null) this.#updateFromScroll()
      else this.#scheduleScrollEnd()
    })
  }

  scrollEnd() {
    if (this.scrollTimer) clearTimeout(this.scrollTimer)

    this.programmaticIndex = null
    this.#updateFromScroll()
  }

  show(index, { behavior = "smooth", emit = true } = {}) {
    this.#goTo(index, behavior, emit)
  }

  #goTo(index, behavior = "smooth", emit = true) {
    const nextIndex = this.#boundedIndex(index)
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const scrollBehavior = reducedMotion ? "instant" : behavior
    const targetLeft = this.slideTargets[nextIndex].offsetLeft

    this.currentIndex = nextIndex
    this.programmaticIndex = scrollBehavior === "smooth" && Math.abs(this.viewportTarget.scrollLeft - targetLeft) > 1 ? nextIndex : null
    this.viewportTarget.scrollTo({
      left: targetLeft,
      behavior: scrollBehavior
    })
    this.#render()
    if (emit) this.#announceChange()
  }

  #boundedIndex(index) {
    return Math.max(0, Math.min(index, this.slideTargets.length - 1))
  }

  #updateFromScroll() {
    const left = this.viewportTarget.scrollLeft
    const distances = this.slideTargets.map((slide) => Math.abs(slide.offsetLeft - left))
    const closest = distances.indexOf(Math.min(...distances))

    if (closest === this.currentIndex) return

    this.currentIndex = closest
    this.#render()
    this.#announceChange()
  }

  #scheduleScrollEnd() {
    if (this.scrollTimer) clearTimeout(this.scrollTimer)

    this.scrollTimer = setTimeout(() => this.scrollEnd(), 120)
  }

  #announceChange() {
    this.dispatch("change", { detail: { index: this.currentIndex } })
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

    const selectedThumbnail = this.thumbnailTargets[this.currentIndex]
    if (selectedThumbnail && this.hasThumbnailViewportTarget) {
      selectedThumbnail.scrollIntoView({
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth",
        block: "nearest",
        inline: "nearest"
      })
    }
  }
}
