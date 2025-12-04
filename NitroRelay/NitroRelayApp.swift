import SwiftUI
import CoreMotion
import AVFoundation
import AudioToolbox
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct NitroRelayApp: App {
    init() {
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var game = NitroGame()
    @State private var showGuide = true
    @State private var showInterstitial = false
    @AppStorage("adsDisabled") private var adsDisabled: Bool = false
    // AdMob インタースティシャルID管理（テストID / 本番IDを切り替え可能）
    private let useTestAds = true
    private let testInterstitialId = "ca-app-pub-3940256099942544/1033173712" // Google公式テストID
    private let productionInterstitialId = "YOUR_INTERSTITIAL_AD_UNIT_ID"     // ← 後で本番IDに差し替え
    private let adDelay: TimeInterval = 1.2 // 爆発画面を見せる時間
    // バナー広告ID（AdMob公式テストID）
    private let testBannerId = "ca-app-pub-3940256099942544/2934735716"
    private let productionBannerId = "YOUR_BANNER_AD_UNIT_ID"                // ← 後で本番IDに差し替え

    var body: some View {
        ZStack {
            BackgroundGradient()

            VStack(spacing: 22) {
                header
                loopBanner
                gaugeCard
                controlButtons
                handoffSlider
                spiceToggles
                removeAdsButton
                bannerArea
                Spacer(minLength: 10)
                statusFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .overlay(overlayCards, alignment: .top)
        .overlay(ruleOverlay, alignment: .center)
        .overlay(explosionOverlay.opacity(game.phase == .exploded ? 1 : 0))
        .overlay(interstitialOverlay)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.phase)
        .sheet(isPresented: $showGuide) {
            GuideSheet(showGuide: $showGuide)
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showGuide = true
            } label: {
                Label("操作ガイド", systemImage: "questionmark.circle")
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(12)
            }
            .accessibilityLabel("操作ガイドを開く")
        }
        .onChange(of: game.phase) { newValue in
            if newValue == .exploded {
                // まず爆発画面を見せ、その後インタースティシャルへ（広告OFF時はスキップ）
                DispatchQueue.main.asyncAfter(deadline: .now() + adDelay) {
                    if game.phase == .exploded && !adsDisabled { showInterstitial = true }
                }
            } else {
                showInterstitial = false
            }
        }
    }

    // MARK: Subviews

    private var loopBanner: some View {
        Group {
            if game.phase == .running, let remain = game.loopRemaining {
                LoopBanner(remaining: remain, base: max(2, Int(game.handoffSeconds.rounded())))
            }
        }
    }

    private var ruleOverlay: some View {
        Group {
            if let rule = game.ruleLabel {
                RuleBanner(text: rule)
                    .transition(.scale.combined(with: .opacity))
                    .padding()
            }
        }
    }

    private var interstitialOverlay: some View {
        Group {
            if showInterstitial {
                let adId = useTestAds ? testInterstitialId : productionInterstitialId
                InterstitialAdHostView(adUnitId: adId) {
                    showInterstitial = false
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    // MARK: - Purchases (placeholder)
    private func openAppleAccountForPurchase() {
        if let url = URL(string: "https://apps.apple.com/account/billing") {
            UIApplication.shared.open(url)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("爆弾リレー：揺らすと即爆")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .kerning(1.2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 24)
                .padding(.top, 18) // ノッチを避ける

            PhaseBadge(phase: game.phase)
        }
    }

    private var gaugeCard: some View {
        VStack(spacing: 16) {
            GaugeRing(progress: game.gaugeProgress,
                      color: game.phase == .exploded ? .red : .yellow)
                .frame(width: 210, height: 210)
                .overlay(gaugeCenter, alignment: .center)

            VStack(spacing: 6) {
                Text(game.message)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text("しきい値 \(String(format: "%.2f", game.currentThreshold)) G ・ 感度 \(game.sensitivityLabel)")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var gaugeCenter: some View {
        VStack(spacing: 8) {
            if game.phase == .running, let loop = game.loopRemaining {
                Text("\(loop)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 8, y: 4)
                    .id(loop)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(String(format: "%.3f G", game.intensity))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: game.loopRemaining)
    }

    private var subtitle: String {
        switch game.phase {
        case .calibrating:
            return "静止率 \(Int(game.calibrationProgress * 100))%"
        case .running:
            return "カリカリ＆リズム: 3→1→ピ! で渡す"
        case .armed:
            return "そっと渡して"
        case .exploded:
            return "BOOM!"
        case .idle:
            return "待機中"
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    let selected = game.difficulty == level
                    let bg: Color = {
                        switch level {
                        case .hot: return selected ? Color.red.opacity(0.3) : Color.black.opacity(0.25)
                        case .normal: return selected ? Color.orange.opacity(0.3) : Color.black.opacity(0.2)
                        case .sweet: return selected ? Color.yellow.opacity(0.25) : Color.black.opacity(0.2)
                        }
                    }()
                    Button {
                        game.difficulty = level
                    } label: {
                        Text(level.label)
                            .font(.callout.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(bg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1.2)
                            )
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: game.start) {
                    Label(game.phase.isActive ? "もう一度装填" : "装填スタート", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(color: .yellow))
                .disabled(game.phase == .calibrating || showInterstitial)

                Button(role: .destructive, action: game.resetHard) {
                    Label("リセット", systemImage: "stop.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(color: .red.opacity(0.9), textColor: .white))
                .disabled(showInterstitial)
            }
        }
    }

    private var spiceToggles: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $game.soundEnabled) {
                Label("音オン", systemImage: game.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toggleStyle(.button)
            .tint(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)

            Toggle(isOn: $game.fakeBuzzEnabled) {
                Label("フェイント振動", systemImage: "bolt.fill")
            }
            .toggleStyle(.switch)
            .tint(.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)

            Toggle(isOn: $game.ruleCardsEnabled) {
                Label("指示カード", systemImage: "hand.point.up.left.fill")
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        }
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.white.opacity(0.9))
    }

    private var bannerArea: some View {
        if adsDisabled { return AnyView(EmptyView()) }
        let adId = useTestAds ? testBannerId : productionBannerId
        #if canImport(GoogleMobileAds)
        return AnyView(
            AdMobBannerView(adUnitId: adId)
                .frame(height: 60)
                .padding(.vertical, 6)
        )
        #else
        return AnyView(
            BannerAdMockView(adUnitId: adId)
                .frame(height: 60)
                .padding(.vertical, 6)
        )
        #endif
    }

    private var removeAdsButton: some View {
        Button(action: {
            if adsDisabled {
                // 広告を再表示
                adsDisabled = false
            } else {
                // 広告をオフ（プレースホルダー購入動線）
                openAppleAccountForPurchase()
                adsDisabled = true
                showInterstitial = false
            }
        }) {
            Label(
                adsDisabled ? "広告を再表示する" : "広告をオフにする",
                systemImage: adsDisabled ? "arrow.uturn.backward" : "cart.fill"
            )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(color: adsDisabled ? .orange : .gray.opacity(0.3), textColor: .white))
        .padding(.top, 4)
    }

    private var handoffSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("交代カウント秒数", systemImage: "hourglass.bottomhalf.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(game.handoffSeconds)) 秒")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }
            Slider(value: $game.handoffSeconds, in: 2...10, step: 1) {
                Text("交代カウント秒数")
            }
            .tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var statusFooter: some View {
        VStack(spacing: 6) {
            if let burst = game.burstLabel {
                PillLabel(text: burst, color: .orange)
            }
            Text("加速度監視: userAcceleration を使用 / 0.02s スキャン")
                .font(.caption.monospaced())
                .foregroundColor(.white.opacity(0.65))
            Text("持ち主が感じる緊張感を最優先。揺らすほど音が早く & バイブが強く。")
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var overlayCards: some View {
        VStack(spacing: 10) {
            if game.phase == .calibrating {
                GlassCard(text: "静止判定中…スマホを水平にして 1 秒キープ", color: .blue)
            }
            if let toast = game.toast {
                GlassCard(text: toast, color: .yellow)
            }
            if game.phase == .armed {
                GlassCard(text: "装填完了！そっと渡してください", color: .green)
            }
            if let handoff = game.handoffValue {
                GlassCard(text: "次のプレイヤーに渡して！ \(handoff)", color: .orange)
            }
        }
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var explosionOverlay: some View {
        ZStack {
            Color.red.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("ドッカーン！！")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("揺らしすぎ！もう一度挑戦？")
                    .font(.headline)
                    .foregroundColor(.white)
                Button("交代して再開") { game.startHandoffCountdown() }
                    .buttonStyle(PrimaryButtonStyle(color: .white, textColor: .red))
                .padding(.top, 6)
            }
            .padding(32)
        }
    }
}

// MARK: - Game Engine

final class NitroGame: ObservableObject {
    enum Phase { case idle, calibrating, armed, running, exploded
        var isActive: Bool { self == .calibrating || self == .running || self == .armed }
    }

    @Published var phase: Phase = .idle
    @Published var intensity: Double = 0
    @Published var message: String = "スマホを水平にして静止させてください"
    @Published var calibrationProgress: Double = 0
    @Published var toast: String?
    @Published var burstLabel: String?
    @Published var ruleLabel: String?
    @Published var soundEnabled: Bool = true
    @Published var fakeBuzzEnabled: Bool = true
    @Published var ruleCardsEnabled: Bool = true
    @Published var handoffValue: Int?
    @Published var handoffSeconds: Double = 3
    @Published var loopRemaining: Int?
    @Published var difficulty: Difficulty = .normal {
        didSet {
            baseThreshold = difficulty.threshold
            if difficulty != .hot { ruleLabel = nil }
        }
    }

    // thresholds
    private var baseThreshold: Double = Difficulty.normal.threshold
    private(set) var sensitivityMultiplier: Double = 1.0
    var currentThreshold: Double { baseThreshold / sensitivityMultiplier }
    var gaugeProgress: Double {
        guard currentThreshold > 0 else { return 0 }
        return min(intensity / currentThreshold, 1.25)
    }
    var sensitivityLabel: String {
        sensitivityMultiplier == 1.0 ? "100%" : String(format: "%.0f%%", sensitivityMultiplier * 100)
    }

    // Motion
    private let motion = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let updateInterval = 0.02
    private let steadyTolerance: Double = 0.035
    private let steadySamplesNeeded = 50 // ≒1s
    private var steadyCount = 0

    // Timers
    private var tickTimer: DispatchSourceTimer?
    private var spiceTimer: DispatchSourceTimer?
    private var handoffTimer: DispatchSourceTimer?
    private var loopTimer: DispatchSourceTimer?
    private var currentTickInterval: Double = 0.5
    private var filteredMag: Double = 0

    // Haptics/Sound
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private var explosionPlayer: AVAudioPlayer?

    // Rules
    private let ruleCards = [
        "右手だけで渡せ！",
        "利き手禁止！反対の手だけ",
        "肘をピンと伸ばして！",
        "親指を離せ！",
        "目を閉じたまま渡せ！",
        "肘はテーブルにつけたまま！",
        "片手はテーブルに置いたまま、もう片手で渡せ！"
    ]

    // MARK: Public controls

    func start() {
        stopHandoffCountdown()
        guard motion.isDeviceMotionAvailable else {
            message = "このデバイスでは加速度を取得できません"
            return
        }
        reset(keepDifficulty: true)
        phase = .calibrating
        message = "静止判定中…"
        motion.deviceMotionUpdateInterval = updateInterval
        steadyCount = 0
        calibrationProgress = 0

        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            let mag = self.magnitude(data.userAcceleration)

            switch self.phase {
            case .calibrating:
                if mag < self.steadyTolerance {
                    self.steadyCount += 1
                } else {
                    self.steadyCount = 0
                }
                DispatchQueue.main.async {
                    self.calibrationProgress = min(1.0, Double(self.steadyCount) / Double(self.steadySamplesNeeded))
                }
                if steadyCount >= steadySamplesNeeded {
                    DispatchQueue.main.async { self.beginRelay() }
                }
            case .running:
                self.handleMotionMagnitude(mag)
            case .armed, .idle, .exploded:
                break
            }
        }
    }

    func resetHard() {
        reset(keepDifficulty: true)
        phase = .idle
    }

    // MARK: Private core

    private func beginRelay() {
        phase = .armed
        message = "装填完了。そっと渡してください"
        toast = "開始！動かすほどカリカリが速くなる"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.phase = .running
            self.toast = nil
            self.message = "カリカリ音の速さに注意！"
        }
        lightHaptic.prepare()
        mediumHaptic.prepare()
        startTickTimer(interval: currentTickInterval)
        startSpiceTimer()
        startLoopTicker()
    }

    private func handleMotionMagnitude(_ mag: Double) {
        DispatchQueue.main.async {
            // 簡易ローパスでスパイクを平滑化（揺れを少し寛容に）
            self.filteredMag = 0.7 * self.filteredMag + 0.3 * mag
            let m = self.filteredMag
            self.intensity = m
            if m > self.currentThreshold {
                self.explode()
                return
            }
            self.updateTickRate(for: m)
            self.lightHaptic.impactOccurred(intensity: CGFloat(min(1.0, max(0.05, m / self.currentThreshold))))
        }
    }

    private func explode() {
        phase = .exploded
        message = "ドッカーン！！"
        stopAllTimers()
        motion.stopDeviceMotionUpdates()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        playExplosionSound()
        mediumHaptic.impactOccurred(intensity: 1.0)
    }

    private func reset(keepDifficulty: Bool) {
        stopAllTimers()
        motion.stopDeviceMotionUpdates()
        intensity = 0
        calibrationProgress = 0
        toast = nil
        burstLabel = nil
        ruleLabel = nil
        handoffValue = nil
        loopRemaining = nil
        sensitivityMultiplier = 1.0
        filteredMag = 0
        if !keepDifficulty { difficulty = .normal }
        baseThreshold = difficulty.threshold
        message = "スマホを水平にして静止させてください"
        phase = .idle
    }

    // MARK: Spice features

    private func startSpiceTimer() {
        spiceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 4, repeating: 7, leeway: .milliseconds(400))
        timer.setEventHandler { [weak self] in self?.rollSpice() }
        timer.resume()
        spiceTimer = timer
    }

    private func rollSpice() {
        guard phase == .running else { return }
        let roll = Double.random(in: 0...1)
        if roll < 0.35 {
            triggerMaxSensitivity()
        } else if roll < 0.7, ruleCardsEnabled, difficulty == .hot {
            triggerRuleCard()
        } else if fakeBuzzEnabled {
            triggerFakeBuzz()
        }
    }

    // MARK: Loop Countdown (always during relay)

    private func startLoopTicker() {
        stopLoopTicker()
        let base = max(2, Int(handoffSeconds.rounded()))
        loopRemaining = base
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard let remain = self.loopRemaining else {
                self.loopRemaining = base
                return
            }
            if remain <= 1 {
                if self.soundEnabled { AudioServicesPlaySystemSound(1113) } // beep on "ピ!"
                self.mediumHaptic.impactOccurred(intensity: 0.9)
                self.loopRemaining = base
            } else {
                if self.soundEnabled { AudioServicesPlaySystemSound(1057) } // tick per second
                self.lightHaptic.impactOccurred(intensity: 0.3)
                self.loopRemaining = remain - 1
            }
        }
        timer.resume()
        loopTimer = timer
    }

    private func stopLoopTicker() {
        loopTimer?.cancel()
        loopTimer = nil
        loopRemaining = nil
    }

    // MARK: Handoff Countdown (legacy pre-start) — kept for optional handoff use

    func startHandoffCountdown(seconds: Int? = nil) {
        stopHandoffCountdown()
        reset(keepDifficulty: true)
        let sec = max(1, seconds ?? Int(handoffSeconds.rounded()))
        handoffValue = sec
        toast = "次のプレイヤーに手渡し準備！"
        message = "交代カウント中…揺らさずキープ"
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard let value = self.handoffValue else { return }
            if self.soundEnabled { AudioServicesPlaySystemSound(1057) } // short tick
            self.lightHaptic.impactOccurred(intensity: 0.4)
            if value <= 1 {
                self.stopHandoffCountdown()
                self.toast = "スタート！"
                self.start()
            } else {
                self.handoffValue = value - 1
            }
        }
        timer.resume()
        handoffTimer = timer
    }

    private func stopHandoffCountdown() {
        handoffTimer?.cancel()
        handoffTimer = nil
        handoffValue = nil
    }

    private func triggerMaxSensitivity() {
        sensitivityMultiplier = 2.0
        burstLabel = "感度200% わずかな揺れでも即爆！"
        toast = "感度200% 発動！"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.toast == "感度200% 発動！" { self?.toast = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.phase == .running else { return }
            self.sensitivityMultiplier = 1.0
            self.burstLabel = nil
        }
    }

    private func triggerRuleCard() {
        ruleLabel = ruleCards.randomElement()
        toast = ruleLabel
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.ruleLabel = nil
        }
    }

    private func triggerFakeBuzz() {
        toast = "フェイント振動！"
        mediumHaptic.impactOccurred(intensity: 0.8)
        if soundEnabled { AudioServicesPlaySystemSound(1107) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.toast = nil
        }
    }

    // MARK: Tick sound handling

    private func startTickTimer(interval: Double) {
        tickTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self, self.soundEnabled else { return }
            AudioServicesPlaySystemSound(1104) // "カリカリ"系クリック
        }
        timer.resume()
        tickTimer = timer
        currentTickInterval = interval
    }

    private func updateTickRate(for mag: Double) {
        let minInterval = 0.06
        let maxInterval = 0.6
        let ratio = min(1.0, max(0, mag / currentThreshold))
        let newInterval = maxInterval - (maxInterval - minInterval) * ratio
        if abs(newInterval - currentTickInterval) > 0.02 {
            startTickTimer(interval: newInterval)
        }
    }

    private func stopAllTimers() {
        tickTimer?.cancel()
        tickTimer = nil
        spiceTimer?.cancel()
        spiceTimer = nil
        handoffTimer?.cancel()
        handoffTimer = nil
        loopTimer?.cancel()
        loopTimer = nil
    }

    // MARK: Helpers

    private func magnitude(_ a: CMAcceleration) -> Double {
        sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    }

    // MARK: Explosion sound

    private func prepareExplosionSoundIfNeeded() {
        guard explosionPlayer == nil else { return }
        if let url = Bundle.main.url(forResource: "DeathFlash", withExtension: "flac") ??
            Bundle.main.url(forResource: "explosion", withExtension: "caf") {
            explosionPlayer = try? AVAudioPlayer(contentsOf: url)
            explosionPlayer?.volume = 1.0 // 最大音量
            explosionPlayer?.prepareToPlay()
        }
    }

    private func playExplosionSound() {
        guard soundEnabled else { return }
        prepareExplosionSoundIfNeeded()
        if let player = explosionPlayer {
            player.currentTime = 0
            player.play()
            // もう一発重ねて体感音量を上げる
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                player.currentTime = 0
                player.play()
            }
        } else {
            // Fallback: louder, sharper system sound than以前の1020
            AudioServicesPlaySystemSound(1009) // "Alert" style
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                AudioServicesPlaySystemSound(1009)
            }
        }
    }
}

// MARK: - Models

enum Difficulty: CaseIterable {
    case sweet, normal, hot

    var label: String {
        switch self {
        case .sweet: return "激甘"
        case .normal: return "普通"
        case .hot: return "激辛"
        }
    }

    var threshold: Double {
        switch self {
        case .sweet: return 0.7    // さらに甘め
        case .normal: return 0.52  // 全体をもう一段緩和
        case .hot: return 0.26     // 激辛も少し緩め
        }
    }
}

// MARK: - UI components

struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [.black, .red.opacity(0.9), .black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
        .overlay(
            AngularGradient(
                gradient: Gradient(colors: [.clear, .orange.opacity(0.25), .yellow.opacity(0.15), .clear]),
                center: .center,
                angle: .degrees(120))
        )
        .ignoresSafeArea()
    }
}

struct GaugeRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 16)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, .orange, .red]),
                        center: .center),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.15), value: progress)
            if progress > 1 {
                Circle()
                    .stroke(Color.red.opacity(0.35), lineWidth: 24)
                    .blur(radius: 6)
            }
        }
    }
}

struct GlassCard: View {
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.white)
                .font(.subheadline.weight(.bold))
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.5), lineWidth: 1))
        .padding(.horizontal)
    }
}

struct PillLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

struct PhaseBadge: View {
    let phase: NitroGame.Phase

    var body: some View {
        let (text, color): (String, Color) = {
            switch phase {
            case .idle: return ("待機中", .gray)
            case .calibrating: return ("静止判定中…", .blue)
            case .armed: return ("装填完了", .green)
            case .running: return ("リレー中", .orange)
            case .exploded: return ("ドッカーン！", .red)
            }
        }()

        return Text(text)
            .font(.headline.weight(.bold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(color.opacity(0.2)))
            .overlay(Capsule().stroke(color, lineWidth: 2))
            .foregroundColor(color)
    }
}

struct RuleBanner: View {
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .red.opacity(0.5), radius: 8, y: 4)
            Text(text)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .shadow(color: .red.opacity(0.7), radius: 10, y: 6)
            Text("指示に従わないと爆発リスクUP！")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.red.opacity(0.7), lineWidth: 3)
                )
        )
    }
}

struct InterstitialAdMockView: View {
    let adUnitId: String
    var onClose: () -> Void
    @State private var closeEnabled = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .top, endPoint: .bottom))
                .frame(maxWidth: 320, maxHeight: 500)
                .overlay(
                    VStack(spacing: 20) {
                        Text("スポンサータイム")
                            .font(.title.weight(.black))
                            .foregroundColor(.white)
                        Text("ここに本物のインタースティシャル広告を表示します。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                        Text("Test Ad Unit: \(adUnitId)")
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        Button(action: { if closeEnabled { onClose() } }) {
                            Text(closeEnabled ? "× 閉じる" : "あと1.5秒…")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                        .disabled(!closeEnabled)
                    }
                    .padding(24)
                )
                .shadow(radius: 24, y: 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                closeEnabled = true
            }
        }
    }
}

#if canImport(GoogleMobileAds)
struct AdMobBannerView: UIViewRepresentable {
    let adUnitId: String

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner)
        view.adUnitID = adUnitId
        view.rootViewController = rootViewController()
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) { }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

struct InterstitialAdHostView: View {
    let adUnitId: String
    var onClose: () -> Void
    @State private var hasShown = false

    var body: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(ProgressView("広告読み込み中…").foregroundColor(.white))
            .onAppear {
                guard !hasShown else { return }
                hasShown = true
                AdMobInterstitial.shared.show(adUnitId: adUnitId) {
                    onClose()
                }
            }
    }
}

final class AdMobInterstitial: NSObject, GADFullScreenContentDelegate {
    static let shared = AdMobInterstitial()
    private var ad: GADInterstitialAd?
    private var completion: (() -> Void)?

    func show(adUnitId: String, onComplete: @escaping () -> Void) {
        completion = onComplete
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: adUnitId, request: request) { [weak self] ad, _ in
            guard let self, let ad, let root = Self.rootViewController() else {
                onComplete()
                return
            }
            self.ad = ad
            ad.fullScreenContentDelegate = self
            ad.present(fromRootViewController: root)
        }
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        completion?()
        completion = nil
        self.ad = nil
    }
}
#else
// 非AdMob環境用のホストビュー（モック）
struct InterstitialAdHostView: View {
    let adUnitId: String
    var onClose: () -> Void
    var body: some View {
        InterstitialAdMockView(adUnitId: adUnitId, onClose: onClose)
    }
}
#endif

struct BannerAdMockView: View {
    let adUnitId: String
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.9))
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Test Banner")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                        Text(adUnitId)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.black.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
                .padding(.horizontal, 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

struct LoopBanner: View {
    let remaining: Int
    let base: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("渡すリズム")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
            Text("\(remaining) → 1 → ピ！")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundColor(.white)
                .shadow(color: .orange.opacity(0.7), radius: 8, y: 4)
                .id(remaining)
                .transition(.scale.combined(with: .opacity))
            Spacer()
            Text("\(base)s")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: remaining)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        let fg = textColor ?? (color == .white ? .red : .black)
        return configuration.label
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.6 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundColor(fg)
            .shadow(color: color.opacity(0.45), radius: 12, y: 6)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

// MARK: - Guide Sheet

struct GuideSheet: View {
    @Binding var showGuide: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("まずは水平な所に置いてね！")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primary)

                    guideRow(title: "1. 卓上で装填", detail: "スマホを水平に置き、手を離して約1秒。静止判定が終わると『装填完了』。")
                    guideRow(title: "2. そっとリレー", detail: "装填後は少しでも揺れると『カリカリ』音が加速。しきい値を超えると爆発。")
                    guideRow(title: "3. 交代カウント", detail: "交代前に『交代カウント』ボタンを押すと3→1で渡すタイミングを合わせられる（秒数はスライダーで変更可）。")
                    guideRow(title: "4. スパイス", detail: "感度300%・フェイント振動・持ち方指定カードがランダムで発動。盛り上げ要素としてON/OFF切替可。")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("裏ワザで緊張感UP")
                            .font(.headline)
                        Text("・暗所なら音オフ＋ハプティクスだけでも遊べる\n・爆発後は『交代して再開』で次の人に即引き継ぎ\n・難易度プリセット（激甘/普通/激辛）で調整")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showGuide = false
                    } label: {
                        Text("遊び方はわかった！")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .yellow, textColor: .black))
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("操作ガイド")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showGuide = false }
                }
            }
        }
    }

    private func guideRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
