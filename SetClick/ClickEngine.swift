import AVFoundation
import Foundation

final class ClickEngine {
    struct TickEvent {
        let isBeatBoundary: Bool
        let isCountIn: Bool
        let countInRemaining: Int
        let beatInBar: Int
        let generation: UInt64
    }

    var onTick: ((TickEvent) -> Void)?

    private let queue = DispatchQueue(label: "setclick.engine", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private lazy var format: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()

    private var running = false
    private var generation: UInt64 = 0

    // Current song config
    private var bpm: Double = 120
    private var numerator: Int = 4
    private var ticksPerBeat: Int = 1
    private var sound: ClickSound = .classic
    private var accentDownbeat: Bool = true
    private var countInBeats: Int = 4

    // Tick state
    private var tickInBeat = 0
    private var sampleError: Double = 0
    private var beatInBar = 0
    private var countInRemaining = 0

    // Schedule-ahead
    private var buffersQueued = 0
    private var buffersCompleted = 0
    private var samplesScheduled: Int64 = 0
    private var samplesCompleted: Int64 = 0
    private let lookAhead = 3
    private var scheduleTimer: DispatchSourceTimer?

    // Voice countdown
    private let voiceRenderQueue = DispatchQueue(label: "setclick.voice", qos: .utility)
    private var voiceSamples: [[Float]] = Array(repeating: [], count: 8)
    private var voicesReady = false

#if os(iOS)
    private var audioSessionConfigured = false
#endif

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        preRenderVoices()
    }

    func start(bpm: Double, timeSignature: TimeSignature, subdivision: Subdivision, sound: ClickSound, countInBeats: Int) {
        queue.async { [self] in
            stopLocked()
            self.bpm = bpm
            self.numerator = timeSignature.numerator
            self.ticksPerBeat = subdivision.clicksPerBeat
            self.sound = sound
            self.countInBeats = countInBeats
            generation += 1
            tickInBeat = 0
            beatInBar = 0
            countInRemaining = max(0, countInBeats)
            buffersQueued = 0
            buffersCompleted = 0
            samplesScheduled = 0
            samplesCompleted = 0
            sampleError = 0
            running = true
            startAudioLocked()
            fillSchedule()
            startPumpTimer()
        }
    }

    func setVolume(_ vol: Float) {
        queue.async { [weak self] in
            self?.player.volume = vol
        }
    }
    
    func stop() {
        queue.async { self.stopLocked() }
    }
    
    /// Stop synchronously - blocks until audio is fully stopped
    func stopSync() {
        queue.sync { self.stopLocked() }
    }
    
    /// Stop audio immediately from any thread, then clean up async.
    /// Calling player.stop() on the main thread cancels all scheduled
    /// buffers BEFORE the engine queue can schedule more.
    func stopImmediate() {
        player.stop()
        queue.async { [self] in
            running = false
            generation += 1
            scheduleTimer?.cancel()
            scheduleTimer = nil
            engine.stop()
        }
    }

    var isRunning: Bool { running }
    var currentGeneration: UInt64 { generation }
    
    /// Change section using the audio engine's own clock for sample-accurate timing.
    /// Flushes old buffers, schedules exact silence gap, then new section.
    func changeSection(bpm: Double, timeSignature: TimeSignature, subdivision: Subdivision, sound: ClickSound, gapSamples: Int = 0) {
        queue.sync { [self] in
            guard running else { return }
            generation += 1
            
            // Flush scheduled buffers but keep engine alive
            player.stop()
            player.play()
            
            samplesScheduled = 0
            samplesCompleted = 0
            buffersQueued = 0
            buffersCompleted = 0
            
            // Schedule silence gap (one beat at old tempo) through the audio engine
            // This gives sample-accurate timing instead of wall-clock timers
            if gapSamples > 0 {
                let silenceFrames = AVAudioFrameCount(gapSamples)
                if let silenceBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: silenceFrames) {
                    silenceBuf.frameLength = silenceFrames
                    let ch = silenceBuf.floatChannelData![0]
                    for i in 0..<gapSamples { ch[i] = 0 }
                    let gs = Int64(gapSamples)
                    samplesScheduled += gs
                    buffersQueued += 1
                    player.scheduleBuffer(silenceBuf) { [weak self] in
                        self?.queue.async {
                            self?.samplesCompleted += gs
                            self?.buffersCompleted += 1
                        }
                    }
                }
            }
            
            self.bpm = bpm
            self.numerator = timeSignature.numerator
            self.ticksPerBeat = subdivision.clicksPerBeat
            self.sound = sound
            self.beatInBar = 0
            self.tickInBeat = 0
            self.sampleError = 0
            
            fillSchedule()
        }
    }

    // MARK: - Voice Pre-rendering

    private func preRenderVoices() {
        voiceRenderQueue.async { [self] in
            let words = ["one", "two", "three", "four", "five", "six", "seven", "eight"]
            let synth = AVSpeechSynthesizer()
            var rendered: [[Float]] = []
            for word in words {
                let utterance = AVSpeechUtterance(string: word)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.15
                utterance.pitchMultiplier = 1.05
                utterance.volume = 0.85
                if let voice = AVSpeechSynthesisVoice(language: "en-US") { utterance.voice = voice }
                var rawSamples: [Float] = []
                var sourceSR: Double = 22050
                let sem = DispatchSemaphore(value: 0)
                synth.write(utterance) { buffer in
                    guard let pcm = buffer as? AVAudioPCMBuffer else { sem.signal(); return }
                    if pcm.frameLength == 0 { sem.signal(); return }
                    sourceSR = pcm.format.sampleRate
                    if let data = pcm.floatChannelData {
                        rawSamples.append(contentsOf: UnsafeBufferPointer(start: data[0], count: Int(pcm.frameLength)))
                    }
                }
                sem.wait()
                if abs(sourceSR - self.sampleRate) > 1.0 && !rawSamples.isEmpty {
                    let ratio = self.sampleRate / sourceSR
                    let outCount = Int(Double(rawSamples.count) * ratio)
                    var resampled = [Float](repeating: 0, count: outCount)
                    for i in 0..<outCount {
                        let srcIdx = Double(i) / ratio
                        let idx = Int(srcIdx)
                        let frac = Float(srcIdx - Double(idx))
                        if idx + 1 < rawSamples.count {
                            resampled[i] = rawSamples[idx] * (1 - frac) + rawSamples[idx + 1] * frac
                        } else if idx < rawSamples.count {
                            resampled[i] = rawSamples[idx]
                        }
                    }
                    rendered.append(resampled)
                } else {
                    rendered.append(rawSamples)
                }
            }
            self.queue.async { self.voiceSamples = rendered; self.voicesReady = true }
        }
    }

    // MARK: - Core scheduling

    private func fillSchedule() {
        guard running else { return }
        let exactSamplesPerTick = sampleRate * 60.0 / (bpm * Double(ticksPerBeat))
        let currentGen = generation
        var toSchedule = lookAhead - (buffersQueued - buffersCompleted)
        if toSchedule <= 0 { return }
        while toSchedule > 0 {
            guard currentGen == generation else { break }
            let corrected = exactSamplesPerTick + sampleError
            let samplesPerTick = max(1, Int(corrected.rounded()))
            sampleError = corrected - Double(samplesPerTick)
            let isBeat = tickInBeat == 0
            let isCI = countInRemaining > 0
            var resetBeatAfterEvent = false
            if isBeat {
                if isCI {
                    countInRemaining -= 1
                    beatInBar = (beatInBar % numerator) + 1
                    if countInRemaining == 0 {
                        resetBeatAfterEvent = true
                    }
                } else {
                    beatInBar = (beatInBar % numerator) + 1
                }
            }
            let accent = isBeat && !isCI && accentDownbeat && beatInBar == 1
            let voiceBeat: Int
            if isCI {
                voiceBeat = max(1, countInBeats) - countInRemaining
            } else {
                voiceBeat = beatInBar
            }
            let buf = makeTickBuffer(samplesPerTick: samplesPerTick, accent: accent, isBeatBoundary: isBeat, voiceBeatNumber: voiceBeat, isCountIn: isCI)
            let ev = TickEvent(isBeatBoundary: isBeat, isCountIn: isCI, countInRemaining: max(countInRemaining, 0), beatInBar: max(beatInBar, 1), generation: generation)
            let samplesAhead = samplesScheduled - samplesCompleted
            let delay = Double(samplesAhead) / sampleRate
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.running, currentGen == self.generation else { return }
                self.onTick?(ev)
            }
            let bufSamples = Int64(samplesPerTick)
            samplesScheduled += bufSamples
            buffersQueued += 1
            if resetBeatAfterEvent { beatInBar = 0 }
            player.scheduleBuffer(buf) { [weak self] in
                guard let self else { return }
                self.queue.async {
                    self.samplesCompleted += bufSamples
                    self.buffersCompleted += 1
                    guard self.running, currentGen == self.generation else { return }
                    self.fillSchedule()
                }
            }
            tickInBeat = (tickInBeat + 1) % ticksPerBeat
            toSchedule -= 1
        }
    }

    private func startPumpTimer() {
        scheduleTimer?.cancel()
        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(deadline: .now() + 0.08, repeating: .milliseconds(40))
        src.setEventHandler { [weak self] in
            guard let self, running else { return }
            fillSchedule()
        }
        scheduleTimer = src
        src.resume()
    }

    // MARK: - Tick buffer

    private func makeTickBuffer(samplesPerTick: Int, accent: Bool, isBeatBoundary: Bool, voiceBeatNumber: Int, isCountIn: Bool) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(samplesPerTick)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return AVAudioPCMBuffer() }
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for i in 0..<samplesPerTick { channel[i] = 0 }
        let clickDuration: Double
        switch sound {
        case .classic: clickDuration = 0.025     // short punchy snap
        case .woodblock: clickDuration = 0.050   // longer resonant body
        case .beep: clickDuration = 0.030        // clean digital tick
        case .hihat: clickDuration = 0.065       // metallic shimmer tail
        }
        let clickFrames = min(samplesPerTick, Int(sampleRate * clickDuration))
        let attackSamples = Int(sampleRate * 0.0003)  // faster attack
        let baseFreq: Double
        switch sound {
        case .classic: baseFreq = accent ? 1_800 : 1_200    // higher, snappier
        case .woodblock: baseFreq = accent ? 1_100 : 800    // warm, hollow
        case .beep: baseFreq = accent ? 2_400 : 1_600       // clean digital
        case .hihat: baseFreq = accent ? 8_000 : 6_500      // metallic
        }
        let amp: Double
        switch sound {
        case .classic: amp = accent ? 0.95 : 0.80
        case .woodblock: amp = accent ? 0.85 : 0.55
        case .beep: amp = accent ? 0.75 : 0.50
        case .hihat: amp = accent ? 0.55 : 0.35
        }
        for i in 0..<clickFrames {
            let t = Double(i) / sampleRate
            let atk = min(1.0, Double(i) / Double(max(1, attackSamples)))
            let env = Self.envelope(sound: sound, time: t)
            let tone = Self.tone(sound: sound, frequency: baseFreq, time: t)
            channel[i] = Float(tone * env * atk * amp)
        }
        if voicesReady && isBeatBoundary && isCountIn {
            let idx = voiceBeatNumber - 1
            if idx >= 0 && idx < voiceSamples.count && !voiceSamples[idx].isEmpty {
                let voice = voiceSamples[idx]
                let copyCount = min(voice.count, samplesPerTick)
                for i in 0..<copyCount { channel[i] += voice[i] * 0.55 }
            }
        }
        return buffer
    }

    // MARK: - Helpers

    private func stopLocked() {
        running = false
        generation += 1
        scheduleTimer?.cancel()
        scheduleTimer = nil
        player.stop()
        engine.stop()
    }

    private func startAudioLocked() {
#if os(iOS)
        if !audioSessionConfigured {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers])
                try session.setPreferredIOBufferDuration(0.005)
                try session.setActive(true)
                audioSessionConfigured = true
            } catch {}
        }
#endif
        if !engine.isRunning {
            do { try engine.start() } catch {
                print("[SetClick] Audio engine failed: \(error)")
                running = false
                return
            }
        }
        player.play()
    }

    // MARK: - Synthesis

    private static func envelope(sound: ClickSound, time: Double) -> Double {
        switch sound {
        case .classic:
            // Mechanical metronome: ultra-sharp transient, dry woody snap
            let click = exp(-4000 * time)        // initial snap (< 1ms)
            let body = exp(-800 * time) * 0.3     // short resonance
            return click + body
        case .woodblock:
            // Real woodblock: hard attack, hollow resonant body, medium decay
            let attack = exp(-3000 * time)        // sharp stick hit
            let body = exp(-200 * time) * 0.6     // hollow wood resonance
            let ring = exp(-80 * time) * 0.15     // subtle tail
            return attack + body + ring
        case .beep:
            // Clean digital click: Pro Tools / Logic style
            let snap = exp(-5000 * time)          // very short transient
            let tone = exp(-500 * time) * 0.7     // clean pitched body
            return snap + tone
        case .hihat:
            // Closed hi-hat: metallic noise burst with shimmer tail
            let stick = exp(-6000 * time)         // stick contact
            let noise = exp(-300 * time) * 0.5    // metallic ring
            let shimmer = exp(-100 * time) * 0.15 // subtle sustain
            return stick + noise + shimmer
        }
    }

    private static func tone(sound: ClickSound, frequency: Double, time: Double) -> Double {
        let pi2 = 2.0 * Double.pi
        switch sound {
        case .classic:
            // Mechanical click: pitched knock with inharmonic overtones
            let fundamental = sin(pi2 * frequency * time)
            let second = sin(pi2 * frequency * 2.76 * time) * 0.35  // inharmonic
            let third = sin(pi2 * frequency * 4.52 * time) * 0.12
            // Add noise transient for realism
            let noise = Double.random(in: -1...1) * exp(-6000 * time) * 0.4
            return fundamental + second + third + noise
        case .woodblock:
            // Hollow wood: multiple inharmonic modes like a real block
            let f = frequency
            let m1 = sin(pi2 * f * time)
            let m2 = sin(pi2 * f * 2.58 * time) * 0.65   // hollow body mode
            let m3 = sin(pi2 * f * 3.87 * time) * 0.35   // upper mode
            let m4 = sin(pi2 * f * 5.41 * time) * 0.15   // brightness
            let m5 = sin(pi2 * f * 7.23 * time) * 0.08   // air
            let noise = Double.random(in: -1...1) * exp(-4000 * time) * 0.25
            return m1 + m2 + m3 + m4 + m5 + noise
        case .beep:
            // Clean digital: pure tone with subtle 2nd harmonic
            let main = sin(pi2 * frequency * time)
            let harm = sin(pi2 * frequency * 2.0 * time) * 0.08
            return main + harm
        case .hihat:
            // Metallic cymbal: dense inharmonic partials + filtered noise
            let f = frequency
            let p1 = sin(pi2 * f * 1.00 * time)
            let p2 = sin(pi2 * f * 1.47 * time) * 0.80
            let p3 = sin(pi2 * f * 1.83 * time) * 0.65
            let p4 = sin(pi2 * f * 2.36 * time) * 0.50
            let p5 = sin(pi2 * f * 2.89 * time) * 0.38
            let p6 = sin(pi2 * f * 3.47 * time) * 0.25
            let p7 = sin(pi2 * f * 4.12 * time) * 0.15
            let p8 = sin(pi2 * f * 5.08 * time) * 0.08
            // Noise component for metallic sizzle
            let noise = Double.random(in: -1...1) * 0.35
            return (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + noise) / 3.0
        }
    }
}
