//
//  GalaxyViewController.swift
//  AR Galaxy Shooter
//
//  Created by Jintian Wang on 2020/5/3.
//  Copyright © 2020 Jintian Wang. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AVFoundation
import ChameleonFramework
import GoogleMobileAds
import AudioToolbox
import FirebaseAnalytics
import AVFoundation

class GalaxyViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate, GADRewardedAdDelegate {
    
    @IBOutlet var speakerButton: UIButton!
    @IBOutlet var succeedTopLabel: UILabel!
    @IBOutlet var succeedLabel: UILabel!
    @IBOutlet var failedLabel: UILabel!
    @IBOutlet var adView: UIView!
    @IBOutlet var rewardLabel: UILabel!
    @IBOutlet var yesButton: UIButton!
    @IBOutlet var noButton: UIButton!
    @IBOutlet var adsNotReadyLabel: UILabel!
    @IBOutlet var adImageView: UIImageView!
    
    @IBOutlet var alarmImageView: UIImageView!
    @IBOutlet var overlayView: UIView!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var topView: UIView!
    @IBOutlet var easyLabel: UILabel!
    @IBOutlet var tipsLabel: UILabel!
    @IBOutlet var faceCameraLabel: UILabel!
    @IBOutlet var tapAnywhereLabel: UILabel!
    
    @IBOutlet var addDeductLabel: UILabel!
    
    @IBOutlet var progressBar: UIProgressView!
    @IBOutlet var timeLeftLabel: UILabel!
    @IBOutlet var scoreLabel: UILabel!
    @IBOutlet var goalLabel: UILabel!
    @IBOutlet var exitButton: UIButton!
    
    @IBOutlet var idleProgressBar: UIProgressView!
    
    private var isPremium = false
    
    private var prevShootedStar = SCNNode()
    
    private var timesPlayed = 0
    
    private var rewardIndex = 0
    private var player: AVAudioPlayer!
    private var backPlayer: AVAudioPlayer!
    private var timer: Timer?
    private var idleTimer: Timer?
    private var easyTimer: Timer?
    var isFromMission = false
    private var hasSucceeded = false
    
    private var userScore: Int = 0 {
        didSet {
            if !hasSucceeded && userScore >= goal {
                
                if goal == Galaxy.levels[5].goal {
                    UserDefaults.standard.set(true, forKey: K.galaxyUnlocked)
                }
                
                DispatchQueue.main.async {
                    self.animateWin()
                }
                hasSucceeded = true
            }
            DispatchQueue.main.async {
                self.scoreLabel.text = String(self.userScore)
            }
        }
    }
    
    private var isHigherBlue = false
    private var isDoubleFire = false
    
    var timeLeft = 50 {
        didSet {
            
            DispatchQueue.main.async {
                self.timeLeftLabel.text = "\("Time Left".localized): \(self.timeLeft)\("s".localized)"
               self.progressBar.setProgress(Float(self.timeLeft)/Float(self.totalTime), animated: true)
            }
            
            if timeLeft <= 0 {
                sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                    if node==sceneView.pointOfView || node == gunNode ?? sceneView.pointOfView {return}
                    node.removeFromParentNode()
                }
                goodStars = []
                badStars = []
                isDoubleFire = false
                isHigherBlue = false
                sceneView.isUserInteractionEnabled = false
                timeLeft = 0
                timer?.invalidate()
                timer = nil
                goodStars.removeAll()
                badStars.removeAll()
                showOverlay()
            }
        }
    }
    var totalTime = 50
    
    var goal = 10
    
    private var goodStars = [SCNNode]()
    private var badStars = [SCNNode]()
    
    private var start = SCNVector3()
    
    private var gunNode: SCNNode?
    
    private var realTimePassed = 0
    var idleTimeLeft: Float = 15.0 {
        didSet {
            if isFromMission {return}
        
            DispatchQueue.main.async {
                self.idleProgressBar.setProgress(self.idleTimeLeft/15.0, animated: true)
            }
            if idleTimeLeft == 0 {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isPremium = true    // isPremium = UserDefaults.standard.bool(forKey: K.isPremium)
        
        if isPremium {
            noButton.removeFromSuperview()
        } else {
            K.appDelegate.galaxyRewardedAd = K.appDelegate.createAndLoadReward(id: K.galaxyRewardedAdUnitID)
        }
        
        setBackgroundMusic()
        
        setCorner()
        
        if isFromMission {
            tipsLabel.text = (Galaxy.tips.randomElement() ?? "- Tips: Move around your camera to find the target star").localized
        } else {
            tipsLabel.text = "Exit will pop up if you win the game or play it for 20 seconds.".localized
        }
        
        idleProgressBar.transform = CGAffineTransform(scaleX: 1, y: 2)
        
        adImageView.layer.cornerRadius = adImageView.bounds.width/2.5
        
        goodStars = [SCNNode]()
        badStars = [SCNNode]()
    
        start = sceneView.pointOfView?.worldPosition ?? SCNVector3Zero
        
        totalTime = timeLeft
        
        SleepViewController.setSpeaker()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.scene.physicsWorld.contactDelegate = self
        
        timeLeftLabel.text = "\("Time Left".localized): \(timeLeft)\("s".localized)"
        goalLabel.text = "\("Goal".localized): \(goal)"
        
        waitAnimation()
        
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
        } else {
            if UserDefaults.standard.bool(forKey: "cameraRequested") {
                self.showCameraAlert(with: "Allow Camera Usage in Settings", msg: "\nPlease allow camera usage in settings. Otherwise, Alarmie cannot run Galaxy Shooting.")
            } else {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                    UserDefaults.standard.set(true, forKey: "cameraRequested")
                    if !granted {
                        self.showCameraAlert(with: "Allow Camera Usage in Settings", msg: "\nPlease allow camera usage in settings. Otherwise, Alarmie cannot run Galaxy Shooting.")
                    }
                })
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topView.backgroundColor = UIColor(gradientStyle: .topToBottom, withFrame: topView.bounds, andColors: [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6),#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)])
    }
    
    func setBackgroundMusic() {
        if UserDefaults.standard.bool(forKey: K.noGameSound) {
            speakerButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        } else {
            speakerButton.setImage(UIImage(systemName: "speaker.1.fill"), for: .normal)
            playBackMusic()
        }
    }
    
    func playBackMusic() {
        let url = Bundle.main.url(forResource: "galaxyBack", withExtension: "mp3")
        if let url = url {
            do {
                backPlayer = try AVAudioPlayer(contentsOf: url)
                backPlayer.play()
                backPlayer.numberOfLoops = -1
            } catch {
            }
        }
    }
    
    @IBAction func speakerTapped(_ sender: UIButton) {
        if UserDefaults.standard.bool(forKey: K.noGameSound) {
            UserDefaults.standard.set(false, forKey: K.noGameSound)
            speakerButton.setImage(UIImage(systemName: "speaker.1.fill"), for: .normal)
            if backPlayer != nil {
                backPlayer.play()
            } else {
                playBackMusic()
            }
        } else {
            UserDefaults.standard.set(true, forKey: K.noGameSound)
            speakerButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
            backPlayer.pause()
        }
    }
    
    func showCameraAlert(with title: String, msg: String) {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
            self.exitTapped(nil)
        }))
        if title == "Allow Camera Usage in Settings" {
            alert.addAction(UIAlertAction(title: "Settings", style: .destructive, handler: { (_) in
                let url = URL(string:UIApplication.openSettingsURLString)
                if UIApplication.shared.canOpenURL(url!){
                    UIApplication.shared.open(url!, options: [:]) { (_) in
                        self.exitTapped(nil)
                    }
                }
            }))
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.3) {
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureSession()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        sceneView.scene.rootNode.enumerateChildNodes({ (node, stop) in
            if node == self.sceneView.pointOfView || node == (self.gunNode ?? self.sceneView.pointOfView) {return}
            let end = node.presentation.worldPosition
            let distance = sqrt(pow(end.x - self.start.x,2)+pow(end.y - self.start.y,2)+pow(end.z - self.start.z,2))
            if distance >= 2 {
                node.removeFromParentNode()
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node == sceneView.pointOfView {return}
            node.removeFromParentNode()
        }
        
        if backPlayer != nil {backPlayer.stop()}
        idleTimeLeft = 15
        idleTimer?.invalidate()
        idleTimer = nil
        timer?.invalidate()
        timer = nil
        easyTimer?.invalidate()
        easyTimer = nil
        goodStars.removeAll()
        badStars.removeAll()
        gunNode = nil
        sceneView.session.pause()
    }
    
    
    func setCorner() {
        easyLabel.layer.cornerRadius = easyLabel.bounds.width / 2
        succeedTopLabel.layer.cornerRadius = 5
        
        succeedLabel.layer.cornerRadius = 12
        succeedLabel.layer.borderWidth = 2
        succeedLabel.layer.borderColor = UIColor.white.cgColor
        failedLabel.layer.cornerRadius = 12
        failedLabel.layer.borderWidth = 2
        failedLabel.layer.borderColor = UIColor.white.cgColor
        adsNotReadyLabel.layer.cornerRadius = 12
        adsNotReadyLabel.layer.borderWidth = 2
        adsNotReadyLabel.layer.borderColor = UIColor.white.cgColor
        adView.layer.cornerRadius = 12
        adView.layer.borderWidth = 2
        adView.layer.borderColor = #colorLiteral(red: 0.3504969776, green: 0.9615690112, blue: 1, alpha: 1).cgColor
        
        yesButton.layer.cornerRadius = 8
        noButton.layer.cornerRadius = 8
        
        exitButton.layer.cornerRadius = 8
        exitButton.alpha = isFromMission ? 1 : 0
        idleProgressBar.isHidden = isFromMission ? true : false
        addDeductLabel.layer.cornerRadius = 5
    }
    
    func alarmShaking() {
        UIView.animate(withDuration: 0.1, animations: {
            self.alarmImageView.transform = CGAffineTransform(rotationAngle: -.pi/7)
        }) { (_) in
            UIView.animate(withDuration: 0.2, animations: {
                self.alarmImageView.transform = CGAffineTransform(rotationAngle: .pi/7)
            }) { (_) in
                self.alarmImageView.transform = CGAffineTransform.identity
            }
        }
    }
    
    func animateWin() {
        succeedLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.15) {
           self.succeedLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.succeedLabel.alpha = 0.8
        }
        UIView.animate(withDuration: 0.05, delay: 0.2, options: .curveLinear, animations: {
            self.succeedLabel.transform = CGAffineTransform.identity
        }, completion: nil)
       
        UIView.animate(withDuration: 0.7, delay: 0.6, options: .curveEaseInOut, animations: {
            self.succeedLabel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3).concatenating(CGAffineTransform(translationX: UIScreen.main.bounds.width/2 - 70 - self.succeedLabel.bounds.width/2, y: -(UIScreen.main.bounds.height/2 - 80 - self.succeedLabel.bounds.height/2)))
            self.succeedLabel.alpha = 0
        }) { (_) in
            self.succeedLabel.transform = CGAffineTransform.identity
            
            if self.isFromMission {
                UIView.animate(withDuration: 0.3) {
                    self.succeedTopLabel.alpha = 1
                }
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    self.succeedTopLabel.alpha = 1
                    self.exitButton.alpha = 1
                }) { (_) in
                    UIView.animate(withDuration: 0.3) {
                        self.idleProgressBar.transform = CGAffineTransform(translationX: 0, y: -(self.exitButton.bounds.height+20))
                    }
                }
            }
        }
    }
    
    func animateAd() {
        rewardIndex = [0,1].randomElement() ?? 0
        if isPremium {
            rewardLabel.text = Galaxy.premiumRewards[rewardIndex].localized
        } else {
            rewardLabel.text = Galaxy.rewards[rewardIndex].localized
        }
        
        adView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.15) {
           self.adView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.adView.alpha = 1
            self.adImageView.alpha = 1
        }
        UIView.animate(withDuration: 0.05, delay: 0.2, options: .curveLinear, animations: {
            self.adView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    func animateLose(with label: UILabel) {
        label.transform = CGAffineTransform(translationX: 0, y: 150)
        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 0.8
            label.transform = CGAffineTransform(translationX: 0, y: -10)
        }) { (_) in
            label.transform = CGAffineTransform.identity
            self.overlayView.isUserInteractionEnabled = true
            self.overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openTimer)))
        }
    }
    
    @IBAction func yesTapped(_ sender: UIButton) {
        idleTimeLeft = 15
        if !isPremium {
            K.appDelegate.galaxyRewardedAd?.present(fromRootViewController: self, delegate: self)
            UIView.animate(withDuration: 0.2) {
                self.adView.alpha = 0
                self.adImageView.alpha = 0
            }
            
            log()
        } else {
            if rewardIndex == 0 {
                isDoubleFire = true
            } else if rewardIndex == 1 {
                isHigherBlue = true
            }
            UIView.animate(withDuration: 0.2, animations: {
                self.adView.alpha = 0
                self.adImageView.alpha = 0
            }) { (_) in
                self.openTimer()
            }
        }
    }
    
    func log() {
        Analytics.logEvent("galaxy_rewardedAd_entered", parameters: [
            "click_time": "\(Date())",
            "l": UserDefaults.standard.string(forKey: K.r) ?? "Unknown..."
        ])
    }

    func rewardedAd(_ rewardedAd: GADRewardedAd, userDidEarn reward: GADAdReward) {
        if rewardIndex == 0 {
            isDoubleFire = true
        } else if rewardIndex == 1 {
            isHigherBlue = true
        }
    }
    
    func rewardedAdDidDismiss(_ rewardedAd: GADRewardedAd) {
        K.appDelegate.galaxyRewardedAd = K.appDelegate.createAndLoadReward(id: K.galaxyRewardedAdUnitID)
        sceneView.isUserInteractionEnabled = true
        hasSucceeded = false
        timeLeft = totalTime
        userScore = 0
        alarmImageView.alpha = 0
        idleTimeLeft = 15
        openIdleTimer()
        
        addGun()
        gunNode?.eulerAngles = SCNVector3(-10*CGFloat.pi/180, 170*CGFloat.pi/180, 0)
        gunNode?.scale = SCNVector3(0.003, 0.003, 0.003)
        gunNode?.position = SCNVector3(0.002, -0.02, -0.12)
        for _ in 0...4 {
            addNewStar(0)
        }
        
        if isDoubleFire || isHigherBlue {
            UIView.animate(withDuration: 0.2) {
                self.overlayView.alpha = 0
            }
            openTimer()
        } else {
            animateLose(with: failedLabel)
        }
    }
    
    func rewardedAd(_ rewardedAd: GADRewardedAd, didFailToPresentWithError error: Error) {
        animateLose(with: adsNotReadyLabel)
    }
    
    @IBAction func noTapped(_ sender: UIButton) {
        idleTimeLeft = 15
        UIView.animate(withDuration: 0.2, animations: {
            self.adView.alpha = 0
            self.adImageView.alpha = 0
        }) { (_) in
            self.animateLose(with: self.failedLabel)
        }
    }
    
    @objc func beginGame() {
        
        idleTimeLeft = 15
        
        overlayView.isUserInteractionEnabled = false
        sceneView.isUserInteractionEnabled = false
        gunNode?.runAction(SCNAction.repeat(SCNAction.rotateBy(x: 0, y: -.pi/1.6, z: 0, duration: 0.5), count: 1))
        gunNode?.runAction(SCNAction.repeat(SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.5), count: 1))
        gunNode?.runAction(SCNAction.fadeOut(duration: 0.5))
        UIView.animate(withDuration: 0.5, animations: {
            self.overlayView.alpha = 0
        }) { (_) in
            self.easyTimer?.invalidate()
            self.easyTimer = nil
            self.gunNode?.eulerAngles = SCNVector3(-10*CGFloat.pi/180, 170*CGFloat.pi/180, 0)
            self.gunNode?.scale = SCNVector3(0.003, 0.003, 0.003)
            self.gunNode?.position = SCNVector3(0.002, -0.02, -0.12)
            self.gunNode?.runAction(SCNAction.fadeIn(duration: 0.3))
            for _ in 0...4 {
                self.addNewStar(0)
            }
            self.openTimer()
        }
    }
    
    func waitAnimation() {
        easyLabel.alpha = 1
        self.animateOneCircle()
        var circle = 0
        var changeTip = true
        let maxCircle = Int.random(in: 1...2)
        var openIdle = true
        
        easyTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true, block: { [weak self] (_) in
            
            guard let self = self else {return}
            
            if circle == 0 {self.addGun()}
            
            if circle <= maxCircle {
                circle += 1
                DispatchQueue.main.async {
                    self.animateOneCircle()
                }
            } else {
                
                if !self.isFromMission && openIdle {
                    openIdle = false
                    self.openIdleTimer()
                }
                
                if changeTip {
                    self.overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.beginGame)))
                    self.faceCameraLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.beginGame)))
                    self.easyLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.beginGame)))
                    self.tapAnywhereLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.beginGame)))
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.tipsLabel.alpha = 0
                        }) { (_) in
                            UIView.animate(withDuration: 0.2, animations: {
                                self.faceCameraLabel.alpha = 1
                            }) { (_) in
                                self.blinkTap(1)
                            }
                        }
                    }
                    changeTip = false
                } else {
                    DispatchQueue.main.async {
                        self.blinkTap(0)
                    }
                }
            }
        })
        easyTimer?.tolerance = 0.1
    }
    
    func blinkTap(_ type: Int) {
        if type == 1 {
            self.tapAnywhereLabel.alpha = 1
        } else {
            self.tapAnywhereLabel.alpha = 0
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4) {
                self.tapAnywhereLabel.alpha = 1
            }
        }
    }
    
    func animateOneCircle() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveLinear, animations: {
            self.easyLabel.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }, completion: nil)
        UIView.animate(withDuration: 0.4, delay: 0.4, options: .curveLinear, animations: {
            self.easyLabel.transform = CGAffineTransform(rotationAngle: 2 * CGFloat.pi)
        }, completion: nil)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        showCameraAlert(with: "Device Not Supported", msg: "\nSession failed with error: \(error.localizedDescription) ")
        UserDefaults.standard.set(true, forKey: K.galaxyUnlocked)
    }
    
    func handleUnrelatedObj() {
        userScore = 0
        succeedLabel.alpha = 0
        succeedTopLabel.alpha = 0
        failedLabel.alpha = 0
        adsNotReadyLabel.alpha = 0
        overlayView.isUserInteractionEnabled = false
        overlayView.alpha = 0
        timeLeft = totalTime
        alarmImageView.alpha = 0
        hasSucceeded = false
    }
    
    @objc func openTimer() {
        handleUnrelatedObj()
        sceneView.isUserInteractionEnabled = true
        let bluePoll = isHigherBlue ? [-1,1,1,1,1] : [-1,1]
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            
            guard let self = self else {return}
            
            self.timeLeft -= 1
            
            if self.timeLeft%3 == 0 {
                self.addNewStar(bluePoll.randomElement() ?? 1)
    
                self.sceneView.scene.rootNode.enumerateChildNodes({ (node, _) in
                    if node == self.sceneView.pointOfView {return}
                    let end = node.presentation.worldPosition
                    let distance = sqrt(pow(end.x - self.start.x,2)+pow(end.y - self.start.y,2)+pow(end.z - self.start.z,2))
                    if distance >= 4 {
                        node.removeFromParentNode()
                    }
                })
            }
            
            if self.timeLeft%2 == 0 {
                self.addNewStar(0)
            }
            
            if self.timeLeft == 6 {
                UIView.animate(withDuration: 0.5) {
                    self.alarmImageView.alpha = 1
                }
            } else if self.timeLeft < 6 {
                self.alarmShaking()
            }
            
        })
        timer?.tolerance = 0.1
        
        timesPlayed += 1
        Analytics.logEvent("galaxy_played", parameters: [
            "times_played": timesPlayed,
            "l": UserDefaults.standard.string(forKey: K.r) ?? "Unknown..."
        ])
    }
    
    func openIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            self.idleTimeLeft -= 1
            self.realTimePassed += 1
            if self.realTimePassed == 20 {
                self.showExit()
            }
        })
        idleTimer?.tolerance = 0.1
    }
    
    func showExit() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, animations: {
                self.exitButton.alpha = 1
            }) { (_) in
                UIView.animate(withDuration: 0.3) {
                    self.idleProgressBar.transform = CGAffineTransform(translationX: 0, y: -(self.exitButton.bounds.height+20))
                }
            }
        }
    }
    
    func showOverlay() {
        DispatchQueue.main.async {
            self.easyLabel.isHidden = true
            self.tipsLabel.isHidden = true
            self.faceCameraLabel.isHidden = true
            self.tapAnywhereLabel.isHidden = true
            UIView.animate(withDuration: 0.2, animations: {
                self.overlayView.alpha = 1
            }) { (_) in
                if self.hasSucceeded {
                    self.succeedLabel.transform = CGAffineTransform(translationX: 0, y: 150)
                    UIView.animate(withDuration: 0.2, animations: {
                        self.succeedLabel.alpha = 0.8
                        self.succeedLabel.transform = CGAffineTransform(translationX: 0, y: -10)
                    }) { (_) in
                        self.succeedLabel.transform = CGAffineTransform.identity
                        self.overlayView.isUserInteractionEnabled = true
                        self.overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openTimer)))
                    }
                } else {
                    if !self.isPremium {
                        if K.appDelegate.galaxyRewardedAd?.isReady == true {
                            self.animateAd()
                        } else {
                            K.appDelegate.galaxyRewardedAd = K.appDelegate.createAndLoadReward(id: K.galaxyRewardedAdUnitID)
                            self.animateLose(with: self.failedLabel)
                        }
                    } else {
                        self.animateAd()
                    }
                }
            }
        }
    }
    
    @IBAction func didTapScreen(_ sender: UITapGestureRecognizer) {
        idleTimeLeft = 15.0
        createBullet()
        if isDoubleFire {
            createAccompanyingBullet()
        }
    }
    
    func createBullet() {
        self.playSoundEffect(ofType: .torpedo)
        
        let bulletsNode = Bullet()
        
        let (direction, position) = self.getUserVector()
        bulletsNode.position = position
        
        let bulletDirection = direction
        bulletsNode.physicsBody?.applyForce(bulletDirection, asImpulse: true)
        self.sceneView.scene.rootNode.addChildNode(bulletsNode)
        let prevG = bulletsNode.geometry
        bulletsNode.geometry = nil
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.12) {
            bulletsNode.geometry = prevG
        }
    }
    
    func createAccompanyingBullet() {
        
        let bulletsNode = Bullet()
        
        let (direction, position) = self.getUserVector()
        bulletsNode.position = SCNVector3(position.x, position.y, position.z + 0.09)
        
        let bulletDirection = direction
        bulletsNode.physicsBody?.applyForce(bulletDirection, asImpulse: true)
        self.sceneView.scene.rootNode.addChildNode(bulletsNode)
        let prevG = bulletsNode.geometry
        bulletsNode.geometry = nil
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.12) {
            bulletsNode.geometry = prevG
        }
    }
    
    // MARK: - Game Functionalit
    
    func configureSession() {
        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            sceneView.session.run(configuration)
        } else {
            let configuration = AROrientationTrackingConfiguration()
            sceneView.session.run(configuration)
        }
    }
    
    func addGun() {
        let gunScene = SCNScene(named: "Gun.scn")!
        if let gunNode = gunScene.rootNode.childNode(withName: "Gun", recursively: false) {
            self.gunNode = gunNode
            sceneView.pointOfView?.addChildNode(gunNode)
        }
    }
    
    func addNewStar(_ type: Int) {
        
        var cubeNode = SCNNode()
        
        if type == 0 {
            cubeNode = Star()
            cubeNode.position = SCNVector3(floatBetween(-0.5, and: 0.5), floatBetween(-0.5, and: 0.5), -1)
            cubeNode.physicsBody?.applyForce(SCNVector3(floatBetween(-0.5, and: 0.5), floatBetween(-0.5, and: 0.5), 0), asImpulse: true)
            cubeNode.physicsBody?.applyTorque(SCNVector4(floatBetween(-0.1, and: 0.1), floatBetween(-0.1, and: 0.1), 0, 0.1), asImpulse: true)
            
        } else if type == -1 {
            cubeNode = BadStar()
            badStars.append(cubeNode)
            cubeNode.position = SCNVector3(floatBetween(-0.5, and: 0.5), floatBetween(-0.5, and: 0.5), -1)
            cubeNode.physicsBody?.applyForce(SCNVector3(floatBetween(-1.5, and: 1.5), floatBetween(-1.5, and: 1.5), 0), asImpulse: true)
            cubeNode.physicsBody?.applyTorque(SCNVector4(floatBetween(-0.2, and: 0.2), floatBetween(-0.2, and: 0.2), 0, 0.1), asImpulse: true)
            
        } else {
            cubeNode = GoodStar()
            goodStars.append(cubeNode)
            cubeNode.position = SCNVector3(floatBetween(-0.5, and: 0.5), floatBetween(-0.5, and: 0.5), -1)
            cubeNode.physicsBody?.applyForce(SCNVector3(floatBetween(-1.5, and: 1.5), floatBetween(-1.5, and: 1.5), 0), asImpulse: true)
            cubeNode.physicsBody?.applyTorque(SCNVector4(floatBetween(-0.2, and: 0.2), floatBetween(-0.2, and: 0.2), 0, 0.1), asImpulse: true)
        }
        
        sceneView.scene.rootNode.addChildNode(cubeNode)
    }
    
    func removeNodeWithAnimation(_ node: SCNNode, explosion: Bool, type: Int) {

        self.playSoundEffect(ofType: .collision)
        
        if explosion {
        
            self.playSoundEffect(ofType: .explosion)
            
            let systemNode = SCNNode()
            if type == 0 {
                systemNode.addParticleSystem(Galaxy.particleSystem)
                
            } else if type == 1 {
                systemNode.addParticleSystem(Galaxy.goodParticle)
                
            } else if type == -1 {
                systemNode.addParticleSystem(Galaxy.badParticle)
            }
            systemNode.position = node.presentation.position
            sceneView.scene.rootNode.addChildNode(systemNode)
        }
        node.removeFromParentNode()
    }
    
    func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform)
            let dir = SCNVector3(-3 * mat.m31, -3 * mat.m32, -3 * mat.m33)
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -3), SCNVector3(0, 0, -0.2))
    }
    
    func floatBetween(_ first: Float,  and second: Float) -> Float {
        return (Float(arc4random()) / Float(UInt32.max)) * (first - second) + second
    }
    
    // MARK: - Contact Delegate
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.ship.rawValue || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.ship.rawValue {
            
            if contact.nodeA == prevShootedStar {return}
            
            prevShootedStar = contact.nodeA
         
            removeNodeWithAnimation(contact.nodeB, explosion: false, type: 0)
            
            var type = 0
            if goodStars.contains(contact.nodeA) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                userScore += 8
                type = 1
                if !isAnimating {animateAddDeduct("+8")}
                
            } else if badStars.contains(contact.nodeA) {
                AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(4095), nil)
                let minusPoints = Int.random(in: 6...12)
                userScore -= minusPoints
                type = -1
                if !isAnimating {animateAddDeduct("-\(minusPoints)")}
                
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.userScore += 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                self.removeNodeWithAnimation(contact.nodeA, explosion: true, type: type)
                self.addNewStar(0)
            })
            
        }
    }
    
    var isAnimating = false
    func animateAddDeduct(_ num: String) {
        
        self.isAnimating = true
        
        DispatchQueue.main.async {
            self.addDeductLabel.transform = CGAffineTransform.identity
            self.addDeductLabel.alpha = 0
            self.addDeductLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            self.addDeductLabel.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.2)
            self.addDeductLabel.textColor = num=="+8" ? #colorLiteral(red: 0.3504969776, green: 0.9615690112, blue: 1, alpha: 1) : #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            self.addDeductLabel.text = num
            
            UIView.animate(withDuration: 0.15) {
                self.addDeductLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.addDeductLabel.alpha = 1
            }
            UIView.animate(withDuration: 0.05, delay: 0.2, options: .curveEaseInOut, animations: {
                self.addDeductLabel.transform = CGAffineTransform.identity
            }, completion: nil)
            
            UIView.animate(withDuration: 0.2, delay: 0.7, options: .curveEaseInOut, animations: {
                self.addDeductLabel.transform = CGAffineTransform(translationX: 0, y: 30)
                self.addDeductLabel.alpha = 0
            }) { (_) in
                self.addDeductLabel.transform = CGAffineTransform.identity
                
                self.isAnimating = false
            }
        }
    }
    
    @IBAction func exitTapped(_ sender: Any?) {
        idleTimeLeft = 15
        if isFromMission {
            ARMissionViewController.backFromGame = true
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: K.interstitialCount) + 1, forKey: K.interstitialCount)
            performSegue(withIdentifier: K.exitFromGalaxyToMission, sender: self)
        } else {
            performSegue(withIdentifier: K.galaxyToPicSegue, sender: self)
        }
    }
    // MARK: - Sound Effects
    
    func playSoundEffect(ofType effect: SoundEffect) {
        DispatchQueue.main.async {
            do
            {
                if let effectURL = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") {
                    
                    self.player = try AVAudioPlayer(contentsOf: effectURL)
                    self.player.play()
                    
                }
            }
            catch {
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    
    static let bullets  = CollisionCategory(rawValue: 1 << 0) // 00...01
    static let ship = CollisionCategory(rawValue: 1 << 1) // 00..10
}

enum SoundEffect: String {
    case explosion = "explosion"
    case collision = "collision"
    case torpedo = "torpedo"
}
