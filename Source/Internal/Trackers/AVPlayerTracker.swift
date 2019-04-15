import AVFoundation
import ObjectiveC

internal final class AVPlayerTracker: NSObject {

    private var itemDidPlayToEndTimeObserver: NSObjectProtocol?
    private let parent: MediaTracker
    private var pauseDetectionTimer: Timer?
    private var playbackState = PlaybackState.stopped
    private weak var player: AVPlayer?
    private var playerTimeObserver: AnyObject?
    private var positionTimer: Timer?
    private var seekCompletionTimer: Timer?

    private init(player: AVPlayer, parentTracker: MediaTracker) {
        checkIsOnMainThread()

        self.parent = parentTracker
        self.player = player

        super.init()

        setUpObservers(player: player)

        parent.trackAction(.initialize)
        updatePlaybackState()
    }

    deinit {
        if let itemDidPlayToEndTimeObserver = itemDidPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(itemDidPlayToEndTimeObserver)
        }

        pauseDetectionTimer?.invalidate()
        positionTimer?.invalidate()

        let lastKnownPlaybackTime = self._lastKnownPlaybackTime
        let parent = self.parent
        let playbackState = self.playbackState

        onMainQueue(synchronousIfPossible: true) {
            switch playbackState {
            case .paused, .pausedOrSeeking, .playing, .seeking:
                if let time = self.player?.currentTime() {
                    parent.mediaProperties.position = CMTimeGetSeconds(time)
                } else if let lastKnownPlaybackTime = lastKnownPlaybackTime {
                    parent.mediaProperties.position = lastKnownPlaybackTime
                }

                parent.trackAction(.stop)

            case .finished, .stopped:
                break
            }
        }

        onMainQueue(synchronousIfPossible: true) {
            if let player = self.player, let playerTimeObserver = self.playerTimeObserver {
                player.removeTimeObserver(playerTimeObserver)
            }
        }
    }

    private var _lastKnownPlaybackTime: TimeInterval?
    private var lastKnownPlaybackTime: TimeInterval? {
        checkIsOnMainThread()

        if let time = player?.currentTime() {
            _lastKnownPlaybackTime = CMTimeGetSeconds(time)
        }

        return _lastKnownPlaybackTime
    }

    fileprivate func onPlayerDeinit() {
        onMainQueue(synchronousIfPossible: true) {
            if let playerTimeObserver = self.playerTimeObserver {
                self.playerTimeObserver = nil

                self.player?.removeTimeObserver(playerTimeObserver)
            }

            self.updatePlaybackState()
        }
    }

    private func setUpObservers(player: AVPlayer) {
        checkIsOnMainThread()

        let mainQueue = OperationQueue.main
        let notificationCenter = NotificationCenter.default

        itemDidPlayToEndTimeObserver = notificationCenter.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                                      object: nil,
                                                                      queue: mainQueue) { [weak self] notification in
            guard let `self` = self, let player = self.player,
                  let object = notification.object as?  AVPlayerItem,
                      object === player.currentItem else {
                return
            }

            self.updateToPlaybackState(.finished)
        }

        self.playerTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(60, preferredTimescale: 1),
                                                                 queue: nil) { [weak self] currentTime in
            guard let `self` = self, let player = self.player else {
                return
            }

            switch self.playbackState {
            case .finished, .paused, .pausedOrSeeking, .seeking, .stopped:
                if !player.isPlaying {
                    self.updateToPlaybackState(.seeking)

                    self.seekCompletionTimer?.invalidate()
                    self.seekCompletionTimer = Timer.scheduledTimerWithTimeInterval(1) { [weak self] in
                        guard let `self` = self else {
                            return
                        }

                        self.seekCompletionTimer = nil

                        guard self.playbackState == .seeking, let player = self.player else {
                            return
                        }

                        self.updateToPlaybackState(player.isPlaying ? .playing : .paused)
                    }
                }

            case .playing:
                break
            }

            self.updatePlaybackState()
        } as AnyObject?
    }

    internal static func track(player: AVPlayer, with tracker: MediaTracker) {
        checkIsOnMainThread()

        player.trackers.add(AVPlayerTracker(player: player, parentTracker: tracker))
    }

    private func updateMediaProperties() {
        checkIsOnMainThread()

        guard let player = player, let item = player.currentItem else {
            return
        }

        if let bandwidth = item.accessLog()?.events.last?.indicatedBitrate, bandwidth >= 1 {
            parent.mediaProperties.bandwidth = bandwidth
        }

        if item.duration != CMTime.indefinite {
            parent.mediaProperties.duration = CMTimeGetSeconds(item.duration)
        }

        if let lastKnownPlaybackTime = lastKnownPlaybackTime {
            parent.mediaProperties.position = lastKnownPlaybackTime
        }

        let volume = AVAudioSession.sharedInstance().outputVolume * player.volume
        parent.mediaProperties.soundIsMuted = abs(volume) < 0.000001
        parent.mediaProperties.soundVolume = Double(volume)
    }

    private func updatePlaybackState() {
        checkIsOnMainThread()

        let playerIsPlaying = self.player?.isPlaying ?? false

        switch playbackState {
        case .finished, .paused, .pausedOrSeeking, .seeking, .stopped:
            if playerIsPlaying {
                updateToPlaybackState(.playing)
            }

        case .playing:
            if !playerIsPlaying {
                updateToPlaybackState(.pausedOrSeeking)
            }
        }
    }

    private func updatePositionTimer() {
        checkIsOnMainThread()

        if playbackState == .playing {
            if positionTimer == nil {
                if #available(iOS 10.0, *), #available(tvOS 10.0, *) {
                    positionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {_ in
                        guard self.playbackState == .playing else {
                            return
                        }

                        self.updateMediaProperties()
                        self.parent.trackAction(.position)
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
        } else {
            if let timer = positionTimer {
                timer.invalidate()
                positionTimer = nil
            }
        }
    }

    private func updateToPlaybackState(_ playbackState: PlaybackState) {
        checkIsOnMainThread()

        guard playbackState != self.playbackState else {
            return
        }

        self.playbackState = playbackState

        pauseDetectionTimer?.invalidate()
        pauseDetectionTimer = nil

        seekCompletionTimer?.invalidate()
        seekCompletionTimer = nil

        if playbackState == .pausedOrSeeking {
            pauseDetectionTimer = Timer.scheduledTimerWithTimeInterval(0.5) { [weak self] in
                guard let `self` = self else {
                    return
                }

                self.pauseDetectionTimer = nil

                guard self.playbackState == .pausedOrSeeking else {
                    return
                }

                self.updateToPlaybackState(.paused)
            }
        }

        updateMediaProperties()

        switch playbackState {
        case .finished: parent.trackAction(.finish)
        case .paused:   parent.trackAction(.pause)
        case .playing:  parent.trackAction(.play)
        case .seeking:  parent.trackAction(.seek)
        case .stopped:  parent.trackAction(.stop)
        case .pausedOrSeeking: break
        }

        updatePositionTimer()
    }

    private enum PlaybackState {

        case finished
        case paused
        case pausedOrSeeking
        case playing
        case seeking
        case stopped
    }
}

fileprivate extension AVPlayer {

    struct AssociatedKeys {

        fileprivate static var trackers = UInt8()
    }

    var isPlaying: Bool {
        checkIsOnMainThread()

        return abs(rate) >= 0.000001
    }

    var trackers: Trackers {
        checkIsOnMainThread()

        return objc_getAssociatedObject(self, &AssociatedKeys.trackers) as? Trackers ?? {
            let trackers = Trackers()
            objc_setAssociatedObject(self, &AssociatedKeys.trackers, trackers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return trackers
        }()
    }

    final class Trackers {

        private var trackers = [AVPlayerTracker]()

        deinit {
            for tracker in trackers {
                tracker.onPlayerDeinit()
            }
        }

        fileprivate func add(_ tracker: AVPlayerTracker) {
            trackers.append(tracker)
        }
    }
}
