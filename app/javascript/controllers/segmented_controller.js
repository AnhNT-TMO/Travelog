import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    const clicked = event.currentTarget
    this.element.querySelectorAll("[role=tab]").forEach((tab) => {
      tab.setAttribute("aria-selected", String(tab === clicked))
    })
  }
}
