import { Controller } from "@hotwired/stimulus"

// Nút "Dùng vị trí hiện tại" của trang Quanh đây. Điền toạ độ vào form rồi
// submit — việc lọc vẫn do Postgres làm, không lọc bằng JS (plan §9.5).
export default class extends Controller {
  static targets = ["lat", "lng", "centerInput"]
  static values = { currentLocationLabel: String }

  locate(event) {
    event.preventDefault()
    if (!navigator.geolocation) return

    navigator.geolocation.getCurrentPosition((position) => {
      if (!this.hasLatTarget || !this.hasLngTarget) return
      this.latTarget.value = position.coords.latitude
      this.lngTarget.value = position.coords.longitude
      if (this.hasCenterInputTarget) this.centerInputTarget.value = this.currentLocationLabelValue
      this.element.requestSubmit()
    })
  }
}
