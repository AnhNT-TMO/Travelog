import { Controller } from "@hotwired/stimulus"

// Segmented control là các <a> dẫn tới ?state=… và Turbo Frame lo phần còn lại.
// Controller này CHỈ cập nhật aria-selected ngay khi bấm để nút không "chết"
// trong lúc chờ response. Server vẫn là nguồn sự thật cho state và số đếm.
export default class extends Controller {
  select(event) {
    const clicked = event.currentTarget
    this.element.querySelectorAll("[role=tab]").forEach((tab) => {
      tab.setAttribute("aria-selected", String(tab === clicked))
    })
  }
}
