public protocol TrackingEventWithActionProperties: TrackingEvent {
	var actionProperties: ActionProperties { get mutating set }
}
