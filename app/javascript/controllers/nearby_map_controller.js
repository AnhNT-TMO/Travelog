import { Controller } from "@hotwired/stimulus"

const PILL_BY_STATUS = {
  visited: "pill--visited",
  wishlist: "pill--wish",
  out_of_radius: "pill--noreview"
}

let mapsSdkPromise
let sharedMap
let sharedCamera

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    apiKey: String,
    mapId: String,
    center: Object,
    radius: Number,
    places: Array,
    band: Array,
    customCenterLabel: String,
    statusLabels: Object
  }

  connect() {
    this.#setup()
  }

  canvasTargetConnected() {
    this.#setup()
  }

  async #setup() {
    if (this.building || !this.hasCanvasTarget) return
    if (!this.apiKeyValue || !this.mapIdValue) return

    this.building = true

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

    if (sharedMap && sharedMap.getDiv() === this.canvasTarget) {
      this.map = sharedMap
      this.#moveCamera()
    } else {
      this.map = new Map(this.canvasTarget, {
        center: this.centerValue,
        zoom: this.#zoomForRadius(this.radiusValue),
        mapId: this.mapIdValue,
        disableDefaultUI: true,
        zoomControl: true,
        gestureHandling: "greedy"
      })
      sharedMap = this.map
      sharedCamera = this.#camera()
    }

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
      zIndex: this.placesValue.length + 3,
      content: new PinElement({ background: "#0E6E63", borderColor: "#ffffff" })
    })
    this.centerMarker.addListener("dragend", (event) => this.#recentre(event.latLng))

    this.pins = [
      ...this.placesValue.map((point, index) => this.#buildPin(point, index + 1, AdvancedMarkerElement)),
      ...this.bandValue.map((point) => this.#buildPin(point, null, AdvancedMarkerElement))
    ]
    this.mapListeners = [
      this.map.addListener("idle", () => this.#scheduleLayout()),
      this.map.addListener("click", () => this.#select(null))
    ]

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

  #buildPin(point, order, AdvancedMarkerElement) {
    const numbered = order !== null

    const element = document.createElement("div")
    element.className = numbered ? "map-pin" : "map-pin map-pin--faint"
    element.dataset.status = point.status
    element.dataset.state = "idle"

    const dot = document.createElement("span")
    dot.className = "map-pin__dot num"
    if (numbered) dot.textContent = order
    element.appendChild(dot)

    const name = document.createElement("span")
    name.className = "map-pin__name"
    name.textContent = point.name
    element.appendChild(name)

    const card = document.createElement("span")
    card.className = "map-pin__card"
    const cardName = document.createElement("span")
    cardName.className = "map-pin__card-name"
    cardName.textContent = point.name
    const status = document.createElement("span")
    status.className = `pill ${PILL_BY_STATUS[point.status] || "pill--wish"}`
    status.textContent = this.statusLabelsValue[point.status] || ""
    card.append(cardName, status)
    element.appendChild(card)

    const zIndex = numbered ? this.placesValue.length - order : 0

    const marker = new AdvancedMarkerElement({
      map: this.map,
      position: { lat: point.lat, lng: point.lng },
      title: point.name,
      gmpClickable: true,
      zIndex,
      content: element
    })

    const pin = { point, order, marker, element, name, card, baseZIndex: zIndex }

    element.addEventListener("mouseenter", () => this.#emphasize(pin))
    element.addEventListener("mouseleave", () => this.#emphasize(null))
    element.addEventListener("click", (event) => {
      event.stopPropagation()
      this.#select(pin)
    })

    return pin
  }

  #select(pin) {
    this.selected = this.selected === pin ? null : pin
    this.#paint()

    if (this.selected) {
      this.#placeCard(this.selected)
      this.#revealRow(this.#row(this.selected))
    }
  }

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

  #emphasize(pin) {
    this.hovered = pin
    this.#paint()
  }

  #paint() {
    this.pins.forEach((pin) => {
      const selected = pin === this.selected
      const hovered = pin === this.hovered
      pin.element.dataset.state = selected ? "active" : hovered ? "hover" : "idle"
      pin.marker.zIndex = hovered
        ? this.placesValue.length + 2
        : selected ? this.placesValue.length + 1 : pin.baseZIndex
    })

    this.#paintRows(this.selected || this.hovered)
    this.#scheduleLayout()
  }

  #scheduleLayout() {
    if (this.layoutFrame) return

    this.layoutFrame = requestAnimationFrame(() => {
      this.layoutFrame = null
      this.#layoutLabels()
    })
  }

  #layoutLabels() {
    if (!this.pins?.length) return

    const projection = this.map.getProjection()
    if (!projection) return

    const scale = 2 ** this.map.getZoom()
    const canvasWidth = this.canvasTarget.clientWidth
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

  #camera() {
    return { lat: this.centerValue.lat, lng: this.centerValue.lng, radius: this.radiusValue }
  }

  #moveCamera() {
    const next = this.#camera()
    const previous = sharedCamera
    sharedCamera = next
    if (!previous) return

    if (previous.lat !== next.lat || previous.lng !== next.lng) this.map.panTo(this.centerValue)
    if (previous.radius !== next.radius) this.map.setZoom(this.#zoomForRadius(next.radius))
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
