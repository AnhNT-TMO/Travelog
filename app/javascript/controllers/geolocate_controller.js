import { Controller } from "@hotwired/stimulus"

const POSITION_OPTIONS = { enableHighAccuracy: false, timeout: 5000, maximumAge: 300000 }

export default class extends Controller {
  static targets = ["lat", "lng", "centerInput", "status", "message"]
  static values = {
    currentLocationLabel: String,
    auto: Boolean,
    unavailableMessage: String
  }

  connect() {
    if (this.autoValue) this.#request()
  }

  locate(event) {
    event.preventDefault()
    this.#request()
  }

  #request() {
    if (!navigator.geolocation) return this.#reportUnavailable()
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.#clearStatus()
    navigator.geolocation.getCurrentPosition(
      (position) => this.#recentre(position.coords),
      () => this.#reportUnavailable(),
      POSITION_OPTIONS
    )
  }

  #recentre(coords) {
    if (!this.hasLatTarget || !this.hasLngTarget) return

    this.latTarget.value = coords.latitude
    this.lngTarget.value = coords.longitude
    if (this.hasCenterInputTarget) this.centerInputTarget.value = this.currentLocationLabelValue
    this.element.requestSubmit()
  }

  #reportUnavailable() {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = this.unavailableMessageValue
    this.statusTarget.hidden = false
  }

  #clearStatus() {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = ""
    this.statusTarget.hidden = true
  }
}
