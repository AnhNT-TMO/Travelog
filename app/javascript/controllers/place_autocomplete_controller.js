import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "list", "status", "placeId", "address",
    "district", "city", "lat", "lng", "placeType"
  ]

  static values = {
    autocompleteUrl: String,
    detailsUrl: String,
    biasLat: Number,
    biasLng: Number,
    submitOnSelect: { type: Boolean, default: false },
    errorMessage: String
  }

  connect() {
    this.timer = null
    this.predictions = []
    this.activeIndex = -1
    this.sessionToken = null
    this.inputTarget.dataset.selectedValue = this.inputTarget.value
    this.closeOnOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.#hideResults()
    }
    document.addEventListener("pointerdown", this.closeOnOutsideClick)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.autocompleteRequest?.abort()
    this.detailsRequest?.abort()
    document.removeEventListener("pointerdown", this.closeOnOutsideClick)
  }

  search() {
    const input = this.inputTarget.value.trim()
    if (input !== this.inputTarget.dataset.selectedValue) this.#clearSelection()

    clearTimeout(this.timer)
    this.autocompleteRequest?.abort()

    if (input.length < 3) {
      this.#hideResults()
      return
    }

    this.timer = setTimeout(() => this.#loadPredictions(input), 300)
  }

  navigate(event) {
    if (this.resultsTarget.hidden || this.predictions.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.#activate((this.activeIndex + 1) % this.predictions.length)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.#activate((this.activeIndex - 1 + this.predictions.length) % this.predictions.length)
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      this.#choose(this.activeIndex)
    } else if (event.key === "Escape") {
      this.#hideResults()
    }
  }

  select(event) {
    event.preventDefault()
    this.#choose(Number(event.currentTarget.dataset.index))
  }

  async #loadPredictions(input) {
    this.sessionToken ||= crypto.randomUUID()
    this.autocompleteRequest = new AbortController()

    const url = new URL(this.autocompleteUrlValue, window.location.origin)
    url.searchParams.set("q", input)
    url.searchParams.set("session_token", this.sessionToken)
    if (this.hasBiasLatValue) url.searchParams.set("lat", this.biasLatValue)
    if (this.hasBiasLngValue) url.searchParams.set("lng", this.biasLngValue)

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.autocompleteRequest.signal
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.error)

      this.predictions = payload.suggestions || []
      this.#renderPredictions()
    } catch (error) {
      if (error.name !== "AbortError") this.#showError(error.message)
    }
  }

  #renderPredictions() {
    this.listTarget.replaceChildren()
    this.activeIndex = -1

    this.predictions.forEach((prediction, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.role = "option"
      button.dataset.index = index
      button.dataset.action = "click->place-autocomplete#select"
      button.className = "block w-full border-b border-line-soft px-2.5 py-2 text-left last:border-b-0 hover:bg-surface-2 focus:bg-surface-2 focus:outline-none"

      const main = document.createElement("span")
      main.className = "block text-sm font-semibold text-ink"
      main.textContent = prediction.main_text || prediction.text
      button.appendChild(main)

      if (prediction.secondary_text) {
        const secondary = document.createElement("span")
        secondary.className = "mt-0.5 block text-xs text-muted"
        secondary.textContent = prediction.secondary_text
        button.appendChild(secondary)
      }

      this.listTarget.appendChild(button)
    })

    const visible = this.predictions.length > 0
    this.resultsTarget.hidden = !visible
    this.inputTarget.setAttribute("aria-expanded", visible.toString())
    this.#hideStatus()
  }

  #activate(index) {
    this.activeIndex = index
    Array.from(this.listTarget.children).forEach((option, optionIndex) => {
      const active = optionIndex === index
      option.setAttribute("aria-selected", active.toString())
      option.classList.toggle("bg-surface-2", active)
    })
  }

  async #choose(index) {
    const prediction = this.predictions[index]
    if (!prediction) return

    this.inputTarget.value = prediction.main_text || prediction.text
    this.#hideResults()
    this.detailsRequest?.abort()
    this.detailsRequest = new AbortController()

    const url = new URL(this.detailsUrlValue, window.location.origin)
    url.searchParams.set("place_id", prediction.place_id)
    url.searchParams.set("session_token", this.sessionToken)

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.detailsRequest.signal
      })
      const details = await response.json()
      if (!response.ok) throw new Error(details.error)

      this.inputTarget.value = details.display_name
      this.inputTarget.dataset.selectedValue = details.display_name
      this.#setTarget("placeId", details.place_id)
      this.#setTarget("address", details.address)
      this.#setTarget("district", details.district)
      this.#setTarget("city", details.city)
      this.#setTarget("lat", details.lat)
      this.#setTarget("lng", details.lng)
      this.#setTarget("placeType", details.place_type)
      this.sessionToken = null
      this.#hideStatus()

      if (this.submitOnSelectValue) this.element.requestSubmit()
    } catch (error) {
      if (error.name !== "AbortError") this.#showError(error.message)
    }
  }

  #setTarget(name, value) {
    if (value === null || value === undefined) return
    const hasTarget = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
    if (!this[hasTarget]) return
    const target = this[`${name}Target`]
    target.value = value
  }

  #clearSelection() {
    if (this.hasPlaceIdTarget) this.placeIdTarget.value = ""
  }

  #hideResults() {
    this.resultsTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
  }

  #showError(message) {
    this.#hideResults()
    this.statusTarget.textContent = message || this.errorMessageValue
    this.statusTarget.hidden = false
  }

  #hideStatus() {
    this.statusTarget.hidden = true
    this.statusTarget.textContent = ""
  }
}
