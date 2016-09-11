//
//  VM2AudioPlayer.swift
//  OnTheFly
//
//  Created by sumiisan on 2016/09/08.
//
//

import Foundation
import AudioKit

let audioSampleRate: Double = 48000
let dummyAudioFileName = "space.mp4"

enum ProcessPhaseNames: String {
	case Idle = "idle"
	case WarmUp = "warmUp"
	case FileOpened = "fileOpened"
	case Preload = "preLoad"
	case WaitCue = "waitCue"
	case Play = "play"
	case Locked = "locked"
	case Done = "done"	//	added new in VM2
}


public class VM2PlayerBase: NSObject {
	
	private var timerOffset: NSTimeInterval = 0
	private var timePaused: NSTimeInterval = 0
	private var timer: dispatch_source_t? = nil
	private var timerIsRunning: Bool = false
	
	var currentTime: NSTimeInterval {
		get {
			if isPaused {
				return timePaused
			} else {
				return NSDate().timeIntervalSince1970 - timerOffset
			}
		}
		set {
			timerOffset = NSDate().timeIntervalSince1970 - newValue
		}
	}
	
	override init() {
		
	}
	
	public override var description: String {
		return ""
	}
	
	func initTimerWithInterval(interval: NSTimeInterval, callback:()->Void) {
		timer = dispatch_source_create(
			DISPATCH_SOURCE_TYPE_TIMER,
			0,
			0,
			dispatch_get_main_queue()
		)
		
		dispatch_source_set_timer(
			timer!,
			dispatch_time(DISPATCH_TIME_NOW, 0),
			UInt64( interval * NSTimeInterval(NSEC_PER_SEC)),
			0
		)
		
		dispatch_source_set_event_handler(timer!, callback)
	}
	
	func startTimer() {
		if let t = timer where !timerIsRunning {
			dispatch_resume(t)
			timerIsRunning = true
		}
	}
	
	func pauseTimer() {
		if let t = timer where timerIsRunning {
			dispatch_suspend(t)
			timerIsRunning = false
		}
	}
	
	func disposeTimer() {
		if let t = timer {
			/*			if !timerIsRunning {
			dispatch_resume(t)		//	timer must be RUNNING if you want to cancel it(?)
			}*/
			dispatch_source_cancel(t)
			//dispatch_release(t)
			timer = nil
		}
	}
	
	func resume() {
		currentTime = timePaused;
		timePaused = 0;
		startTimer()
	}
	
	func pause() {
		timePaused = currentTime
		pauseTimer()
	}
	
	var isPaused: Bool {
		return timePaused != 0
	}
	
	func stopTimer() {
		disposeTimer()
	}
}


public class VM2MultiTrackPlayer: VM2PlayerBase {
	private var mixer = AKMixer()
	private var limiter: AKDynamicsProcessor? = nil
	
	var limiterIndicator: UIView?
	var players = [VM2AudioPlayer]()
	
	init(numberOfPlayers: Int, dummyAudioPath: String) {
		if AKSettings.sampleRate != audioSampleRate {
			AKSettings.sampleRate = audioSampleRate
		}

		super.init()
		for i in 0..<numberOfPlayers {
			let player = VM2AudioPlayer(id: i, dummyAudioPath: dummyAudioPath)
			players.append(player)
			mixer.connect(player.player!)
		}
		
		limiter = AKDynamicsProcessor(mixer)
		limiter!.threshold = -18
	//	limiter!.attackTime = 0.0001
		limiter!.expansionRatio = 1
		limiter!.headRoom = 0
		limiter!.masterGain = 6

		AudioKit.output = limiter
		AudioKit.start()
		
		limiterIndicator = UIView()
		limiterIndicator!.backgroundColor = UIColor.redColor()
		
		initTimerWithInterval(0.03) {
			dispatch_async(dispatch_get_main_queue(), { 
				if let l = self.limiterIndicator {
					l.frame = CGRectMake(0, 60, CGFloat( self.limiter!.compressionAmount ) * 100, 20)
				}
			})
		}
		
		startTimer()
	}
	
	func switchLimiter(state: Bool) {
		if state {
			limiter!.start()
		} else {
			limiter!.stop()
		}
	}
	
	func requestFreeVM2AudioPlayer() -> VM2AudioPlayer? {
		for vm2ap in players {
			if !vm2ap.busy {
				return vm2ap
			}
		}
		return nil
	}
	
	func stopAllPlayers() {
		players.forEach({$0.stop()})
	}
	
	func audioPlayerWithIndex(index: Int) -> VM2AudioPlayer? {
		if players.count > index {
			return players[index]
		}
		return nil
	}
	
	func setVolume(volume: Float32) {
		players.forEach({$0.setVolume(volume)})
	}
	
	func anyPlayerRunning() -> Bool {
		var running = false
		players.forEach({running = running || $0.isPlaying})
		return running
	}
	
}

public class VM2AudioPlayer: VM2PlayerBase {
	var fragId: String = ""
	var playerId: Int = 0
	var fragDuration: NSTimeInterval = 0
	var fileDuration: NSTimeInterval = 0
	var offset: NSTimeInterval = 0
	
	
	var player: AKAudioPlayer? = nil
	private var processPhase = ProcessPhaseNames.Idle
	private var trackClosed = false
	private var filePathToRead: String = ""
	
	func loadedRatio() -> Float32 {
		return 1	//	we don't care about loaded ratio.
	}
	
	func setVolume(volume: Float32) {
		guard player != nil else { return }
		player!.volume = Double( volume )
	}
	
	var busy: Bool {
		return processPhase != .Idle
	}
	
	var isBusy: Bool {	//	for obj-c compatibility
		return busy
	}
	
	var playing: Bool {
		return processPhase == .Play
	}
	
	var isPlaying: Bool {	//	for obj-c compatibility
		return playing
	}
	
	var didPlay: Bool {	//	todo: consider define a new state: .Done
		return (processPhase == .Play) || (processPhase == .Idle)
	}
	
	//	MARK: - Lifecycle
	override init() {
		super.init()
		initTimerWithInterval(0.01) {	// 10ms resolution
			self.watcher()
		}
	}
	
	convenience init(id: Int, dummyAudioPath: String) {
		self.init()
		playerId = id
		openAudio(dummyAudioPath)
	}
	
	func close() {
		guard !trackClosed else { return }
		trackClosed = true
		guard player != nil else { return }
		player!.stop()
		processPhase = .Idle
	}
	
	
	//	MARK: - Audio File
	func openAudio(path: String?) -> Bool {
		guard path != nil else { return false }
		
		if let url = NSURL(string:
			path!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!) {
			do {
				let file = try AKAudioFile(forReading: url)
				do {
					if let p = player {
						//	we resuse AKAudioPlayer because it's already connected to output mixer.
						p.stop()
						try p.replaceFile(file)
						p.looping = false
					} else {
						//	new AKAudioPlayer
						player = try AKAudioPlayer.init(file: file, looping: false, completionHandler: { () in
							self.processPhase = .WaitCue
							self.player!.looping = false
						})
					}
				} catch {
					print("Could not init audio player with file at URL \(url.absoluteString)")
					return false
				}
			} catch {
				//	[VMException alert:@"Failed to open audio file." format:@"Audio file at path %@ status=%d", url, status];
				print("Failed to open audio file at URL \(url.absoluteString)")
				return false
			}
		} else {
			print("could not convert \(path!) to URL")
			return false
		}
		
		fileDuration = player!.duration
		if fragDuration == 0 {
			fragDuration = fileDuration
		}
		
		startTimer()
		
		return true
	}
	
	func preloadAudio(path: String, atTime time: NSTimeInterval) {
		processPhase = .WarmUp
		filePathToRead = path
		trackClosed = false
		currentTime = time
	}
	
	func openAudioAndReadInfo() {
		processPhase = .Locked
		if openAudio(filePathToRead) {
			if fileDuration == 0 {
				processPhase = .Idle
				return
			}
			createNewQueue()
			processPhase = .FileOpened
			if player!.audioFile.sampleRate != AKSettings.sampleRate {
				print ("SR Mismatch! file:\(player!.audioFile.sampleRate)")
			}
		} else {
			processPhase = .Idle
		}
	}
	
	func watcher() {
		switch (processPhase) {
		case .Locked:
			()						//	busy
		case .Idle:
			()						//	don't do anything
		case .WarmUp:
			if currentTime > 1 {
				stop()				//	too late
			}
			if currentTime > -2.5 {
				openAudioAndReadInfo()
			}

		case .FileOpened:
			if currentTime > -1.8 {
				processPhase = .Preload
			}
		case .Preload:
			//	apparently, AKAudioFile has no method for preload.
			processPhase = .WaitCue
		case .WaitCue:
			//	firing will be handled by the songplayer so that we don't have anything to do here.
			()
			
		default:
			()
		}
		
		if currentTime > fileDuration + 1 {
			stop()
		}		
	}
	
	override func pause() {
		super.pause()
		if let p = player {
			p.pause()
		}
	}
	
	override func resume() {
		super.resume()
		if let p = player {
			p.play()	//	not sure if it resumes from paused point
		}
	}
	
	func stop() {
		if let p = player {
			if p.isPlaying {
				p.stop()
			}
			processPhase = .Idle		//	consider introduce new phase constant: .Done
			//currentTime = 0		//	reset
		}
		
	}
	
	func play() {
		guard processPhase != .Play else { return }
		if player == nil {
			openAudioAndReadInfo()
		}
		if let p = player {
			processPhase = .Play
			currentTime = 0
			p.play()
		}
	}
	
	func createNewQueue() {
		
	}

	//	CustomStringConvertible
	override public var description: String {
		return String(
			format: "AP<%d> time:%.2f phase:%@ dur(frag:%.2f file:%.2f)",
			playerId,
			currentTime,
			processPhase.rawValue,
			fragDuration,
			fileDuration
		)
	}

}

