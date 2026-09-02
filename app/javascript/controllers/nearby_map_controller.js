import { Controller } from "@hotwired/stimulus"

let mapsSdkPromise

// Bản đồ trang Quanh đây (D20, plan §9.5).
//
// Ba chỗ dễ sai nhất:
//   1. apiKey ở đây là GOOGLE_MAPS_BROWSER_KEY (restrict theo HTTP referrer),
//      KHÔNG phải GOOGLE_MAPS_API_KEY của server (restrict theo IP của EC2).
//   2. Thiếu mapId → AdvancedMarkerElement không render marker nào và KHÔNG
//      throw. Map ID phải là kiểu Vector.
//   3. Server là nguồn sự thật: kéo pin trung tâm thì submit lại form, không
//      lọc bằng JS — nếu không số đếm trên segmented control lệch với pin.
//
// Nhận dạng pin (đâu là quán nào) đi theo ba lớp, từ luôn-thấy đến theo-yêu-cầu:
//   • Số trên chấm khớp đúng số của dòng trong danh sách bên cạnh.
//   • Nhãn tên hiện ở những chấm CÒN CHỖ — #layoutLabels tự đo và ẩn nhãn nào
//     chồng lên chấm/nhãn khác, nên map dày mấy cũng không rối.
//   • Hover hoặc bấm vào chấm thì tên hiện lên bằng mọi giá (bấm ra thẻ tên +
//     trạng thái, đồng thời sáng dòng tương ứng trong danh sách).
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    apiKey: String,
    mapId: String,
    center: Object,
    radius: Number,
    places: Array,
    customCenterLabel: String,
    statusLabels: Object
  }

  async connect() {
    // Fallback bắt buộc: thiếu key/map id thì giữ nền grid, danh sách bên dưới
    // vẫn dùng được đầy đủ. Không để trang trắng vì map lỗi.
    if (!this.apiKeyValue || !this.mapIdValue) return

    let Map, AdvancedMarkerElement, PinElement
    try {
      await this.#loadSdk()
      const mapsLibrary = await google.maps.importLibrary("maps")
      const markerLibrary = await google.maps.importLibrary("marker")
      Map = mapsLibrary.Map
      AdvancedMarkerElement = markerLibrary.AdvancedMarkerElement
      PinElement = markerLibrary.PinElement
    } catch {
      return
    }

    this.map = new Map(this.canvasTarget, {
      center: this.centerValue,
      zoom: this.#zoomForRadius(this.radiusValue),
      mapId: this.mapIdValue,
      disableDefaultUI: true,
      zoomControl: true,
      gestureHandling: "greedy"
    })

    this.circle = new google.maps.Circle({
      map: this.map,
      center: this.centerValue,
      radius: this.radiusValue,
      strokeColor: "#0E6E63",
      strokeOpacity: 0.8,
      strokeWeight: 1.5,
      fillColor: "#0E6E63",
      fillOpacity: 0.07
    })

    this.centerMarker = new AdvancedMarkerElement({
      map: this.map,
      position: this.centerValue,
      gmpDraggable: true,
      // Trên mọi pin quán: đây là pin kéo được, mất tay cầm là mất chức năng.
      zIndex: this.placesValue.length + 3,
      content: new PinElement({ background: "#0E6E63", borderColor: "#ffffff" })
    })
    this.centerMarker.addListener("dragend", (event) => this.#recentre(event.latLng))

    // Thứ tự mảng đã là thứ tự khoảng cách do Postgres trả về, nên số hiệu
    // trùng số của dòng trong danh sách và pin gần hơn được ưu tiên nhãn.
    this.pins = this.placesValue.map((point, index) => this.#buildPin(point, index + 1, AdvancedMarkerElement))
    this.mapListeners = [
      this.map.addListener("idle", () => this.#scheduleLayout()),
      this.map.addListener("click", () => this.#select(null))
    ]

    // Nhãn chỉ đo được sau khi marker vào DOM, và Be Vietnam Pro tải xong thì
    // chiều rộng đổi lần nữa — ResizeObserver bắt cả hai, đo một lần trong
    // connect() thì mọi nhãn đều rộng 0 và bị ẩn hết.
    this.labelObserver = new ResizeObserver(() => this.#scheduleLayout())
    this.pins.forEach((pin) => this.labelObserver.observe(pin.name))

    this.#bindRows()
    this.#scheduleLayout()
  }

  disconnect() {
    this.pins?.forEach((pin) => { pin.marker.map = null })
    if (this.centerMarker) this.centerMarker.map = null
    this.circle?.setMap(null)
    this.labelObserver?.disconnect()
    if (this.layoutFrame) cancelAnimationFrame(this.layoutFrame)
    this.mapListeners?.forEach((listener) => listener.remove())
    this.rowListeners?.forEach(({ row, enter, leave }) => {
      row.removeEventListener("mouseenter", enter)
      row.removeEventListener("mouseleave", leave)
    })
    this.pins = null
    this.mapListeners = null
    this.rowListeners = null
    this.labelObserver = null
    this.layoutFrame = null
    this.selected = null
    this.hovered = null
  }

  // hoàng thổ = muốn đến, men ngọc = đã đến (khớp legend trong mockup D4)
  #buildPin(point, order, AdvancedMarkerElement) {
    const element = document.createElement("div")
    element.className = "map-pin"
    element.dataset.status = point.status
    element.dataset.state = "idle"

    const dot = document.createElement("span")
    dot.className = "map-pin__dot num"
    dot.textContent = order
    element.appendChild(dot)

    const name = document.createElement("span")
    name.className = "map-pin__name"
    name.textContent = point.name
    element.appendChild(name)

    // Thẻ khi được chọn. Mọi chuỗi cho người đọc đến từ server, JS chỉ gắn vào.
    const card = document.createElement("span")
    card.className = "map-pin__card"
    const cardName = document.createElement("span")
    cardName.className = "map-pin__card-name"
    cardName.textContent = point.name
    const status = document.createElement("span")
    status.className = point.status === "visited" ? "pill pill--visited" : "pill pill--wish"
    status.textContent = this.statusLabelsValue[point.status] || ""
    card.append(cardName, status)
    element.appendChild(card)

    const marker = new AdvancedMarkerElement({
      map: this.map,
      position: { lat: point.lat, lng: point.lng },
      title: point.name,
      gmpClickable: true,
      zIndex: this.placesValue.length - order,
      content: element
    })

    const pin = { point, order, marker, element, name, card, baseZIndex: this.placesValue.length - order }

    element.addEventListener("mouseenter", () => this.#emphasize(pin))
    element.addEventListener("mouseleave", () => this.#emphasize(null))
    element.addEventListener("click", (event) => {
      event.stopPropagation()
      this.#select(pin)
    })

    return pin
  }

  // Bấm lại pin đang chọn thì bỏ chọn — không cần nút đóng nên không cần chuỗi.
  #select(pin) {
    this.selected = this.selected === pin ? null : pin
    this.#paint()

    if (this.selected) {
      this.#placeCard(this.selected)
      this.#revealRow(this.#row(this.selected))
    }
  }

  // Thẻ mặc định nằm trên chấm và canh giữa; pin sát rìa thì khung bản đồ
  // (overflow-hidden) cắt mất thẻ, nên lật xuống dưới và đẩy ngang vừa khung.
  #placeCard(pin) {
    const canvas = this.canvasTarget.getBoundingClientRect()
    const dot = pin.element.getBoundingClientRect()

    pin.card.style.marginLeft = ""
    pin.card.dataset.place = "above"

    const above = pin.card.getBoundingClientRect()
    if (dot.top - canvas.top < above.height + 12) pin.card.dataset.place = "below"

    const box = pin.card.getBoundingClientRect()
    const pastRight = box.right - (canvas.right - 8)
    const pastLeft = canvas.left + 8 - box.left
    if (pastRight > 0) pin.card.style.marginLeft = `${-pastRight}px`
    else if (pastLeft > 0) pin.card.style.marginLeft = `${pastLeft}px`
  }

  // Chỉ cuộn khi dòng nằm trong một panel cuộn riêng KHÔNG chứa bản đồ — tức
  // panel danh sách ở desktop. Ở mobile danh sách nằm dưới bản đồ trong cùng
  // vùng cuộn, cuộn tới dòng sẽ đẩy bản đồ ra khỏi màn hình đúng lúc người
  // dùng vừa bấm vào nó; tên đã hiện trên thẻ nên không cần cuộn.
  #revealRow(row) {
    let panel = row?.parentElement

    while (panel && panel !== document.body) {
      const overflow = getComputedStyle(panel).overflowY
      const scrolls = (overflow === "auto" || overflow === "scroll") && panel.scrollHeight > panel.clientHeight
      if (scrolls) {
        if (!panel.contains(this.canvasTarget)) row.scrollIntoView({ block: "nearest", behavior: "smooth" })
        return
      }
      panel = panel.parentElement
    }
  }

  // Hover: tên hiện lên kể cả khi #layoutLabels đã ẩn nhãn vì hết chỗ. Hover
  // độc lập với chọn — đang mở thẻ một quán vẫn rê được sang quán khác.
  #emphasize(pin) {
    this.hovered = pin
    this.#paint()
  }

  // Một chỗ duy nhất dịch (đang chọn, đang hover) ra trạng thái của mọi pin:
  // chọn thắng hover, hover thắng bình thường.
  #paint() {
    this.pins.forEach((pin) => {
      const selected = pin === this.selected
      const hovered = pin === this.hovered
      pin.element.dataset.state = selected ? "active" : hovered ? "hover" : "idle"
      // Pin đang rê chuột lên trên cùng, kể cả trên thẻ của pin đang chọn —
      // nếu không thì thẻ che mất đúng cái tên người dùng đang tìm.
      pin.marker.zIndex = hovered
        ? this.placesValue.length + 2
        : selected ? this.placesValue.length + 1 : pin.baseZIndex
    })

    this.#paintRows(this.selected || this.hovered)
    this.#scheduleLayout()
  }

  // Gộp mọi yêu cầu xếp nhãn trong cùng một frame: ResizeObserver bắn một loạt
  // event lúc marker vào DOM, không gộp thì xếp lại tám lần liên tiếp.
  #scheduleLayout() {
    if (this.layoutFrame) return

    this.layoutFrame = requestAnimationFrame(() => {
      this.layoutFrame = null
      this.#layoutLabels()
    })
  }

  // Nhãn tên chỉ hiện ở chỗ còn trống: đo hộp thật của từng nhãn trong world
  // pixel rồi bỏ nhãn nào chồng lên chấm hoặc nhãn đã nhận trước. Chấm luôn
  // hiện, nên map dày vẫn đọc được — zoom vào là các tên còn lại xuất hiện.
  #layoutLabels() {
    if (!this.pins?.length) return

    const projection = this.map.getProjection()
    if (!projection) return

    const scale = 2 ** this.map.getZoom()
    const canvasWidth = this.canvasTarget.clientWidth
    // Gốc toạ độ màn hình để biết pin nào sát rìa phải — nhãn ở đó phải lật
    // sang trái, không thì bị khung bản đồ cắt mất một nửa cái tên.
    const centerWorld = projection.fromLatLngToPoint(this.map.getCenter())
    const originX = centerWorld.x * scale - canvasWidth / 2

    const placed = []
    const spots = this.pins.map((pin) => {
      const world = projection.fromLatLngToPoint({ lat: pin.point.lat, lng: pin.point.lng })
      return { pin, x: world.x * scale, y: world.y * scale }
    })

    spots.forEach(({ x, y }) => placed.push({ left: x - 14, top: y - 14, right: x + 14, bottom: y + 14 }))

    spots.forEach(({ pin, x, y }) => {
      const forced = pin === this.selected || pin === this.hovered
      const width = pin.name.offsetWidth
      const height = pin.name.offsetHeight
      const flipped = x - originX + 28 + width > canvasWidth
      const box = flipped
        ? { left: x - 26 - width, top: y - height / 2 - 2, right: x - 22, bottom: y + height / 2 + 2 }
        : { left: x + 24, top: y - height / 2 - 2, right: x + 28 + width, bottom: y + height / 2 + 2 }
      const free = width > 0 && !placed.some((other) => this.#overlaps(box, other))

      pin.name.dataset.side = flipped ? "left" : "right"
      pin.name.dataset.visible = String(forced || free)
      if (free) placed.push(box)
    })
  }

  #overlaps(box, other) {
    return box.left < other.right && box.right > other.left &&
           box.top < other.bottom && box.bottom > other.top
  }

  // Danh sách bên cạnh là nơi có khoảng cách, quận và link chi tiết — pin chỉ
  // trỏ về đúng dòng của nó chứ không lặp lại những thông tin đó.
  #bindRows() {
    this.rowListeners = Array.from(document.querySelectorAll("[data-place-row-id]")).map((row) => {
      const pin = this.pins.find((candidate) => String(candidate.point.id) === row.dataset.placeRowId)
      const enter = () => this.#emphasize(pin || null)
      const leave = () => this.#emphasize(null)
      row.addEventListener("mouseenter", enter)
      row.addEventListener("mouseleave", leave)
      return { row, enter, leave }
    })
  }

  #row(pin) {
    return document.querySelector(`[data-place-row-id="${CSS.escape(String(pin.point.id))}"]`)
  }

  #paintRows(pin) {
    const id = pin ? String(pin.point.id) : null
    this.rowListeners?.forEach(({ row }) => {
      row.classList.toggle("bg-primary-tint", row.dataset.placeRowId === id)
    })
  }

  // Dùng callback ready vì script.onload có thể chạy trước khi importLibrary
  // được bootstrap xong khi loading=async.
  #loadSdk() {
    if (window.google?.maps?.importLibrary) return Promise.resolve()
    if (mapsSdkPromise) return mapsSdkPromise

    mapsSdkPromise = new Promise((resolve, reject) => {
      const callbackName = "__travelogMapsReady"
      const script = document.createElement("script")
      script.src =
        `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}` +
        `&v=weekly&libraries=maps,marker&language=vi&region=VN&loading=async&callback=${callbackName}`
      script.async = true
      window[callbackName] = () => {
        delete window[callbackName]
        resolve()
      }
      script.onerror = (error) => {
        delete window[callbackName]
        mapsSdkPromise = null
        reject(error)
      }
      document.head.appendChild(script)
    })

    return mapsSdkPromise
  }

  #zoomForRadius(meters) {
    if (meters <= 500) return 16
    if (meters <= 1500) return 15
    if (meters <= 4000) return 14
    if (meters <= 10000) return 12
    return 11
  }

  #recentre(latLng) {
    const form = document.querySelector("#radius_form")
    if (!form) return

    form.querySelector("[name=lat]").value = latLng.lat().toFixed(6)
    form.querySelector("[name=lng]").value = latLng.lng().toFixed(6)
    const centerName = form.querySelector("[name=center_name]")
    if (centerName) centerName.value = this.customCenterLabelValue
    form.requestSubmit()
  }
}
