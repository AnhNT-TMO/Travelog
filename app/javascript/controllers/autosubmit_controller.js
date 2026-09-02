import { Controller } from "@hotwired/stimulus"

// Input file "＋ Thêm ảnh" không có nút submit riêng — chọn ảnh xong là gửi
// luôn. requestSubmit() chứ không submit() để Turbo vẫn chặn được (plan §16).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
