import ".."
BarButton {
    required property var service
    text: service.error ? "NOT !" : service.count ? "NOT " + service.count : "NOT"
    textColor: service.error ? Theme.critical : service.count ? Theme.accent : Theme.secondary
    visible: service.enabled
}
