public protocol TrackingEventWithMediaProperties: TrackingEvent {
	var mediaProperties: MediaProperties { get mutating set }
}
