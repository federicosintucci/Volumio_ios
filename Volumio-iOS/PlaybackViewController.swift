//
//  PlaybackViewController.swift
//  Volumio-iOS
//
//  Created by Federico Sintucci on 20/09/16.
//  Copyright © 2016 Federico Sintucci. All rights reserved.
//

import UIKit
import Kingfisher

class PlaybackViewController: UIViewController {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var currentAlbum: UILabel!
    @IBOutlet weak var currentTitle: UILabel!
    @IBOutlet weak var currentArtist: UILabel!
    @IBOutlet weak var currentAlbumArt: UIImageView!
    @IBOutlet weak var spotifyTrack: UIImageView!
    @IBOutlet weak var currentProgress: UIProgressView!
    @IBOutlet weak var currentVolume: UILabel!
    @IBOutlet weak var seekValue: UILabel!
    @IBOutlet weak var currentDuration: UILabel!

    @IBOutlet weak var outerRing: UIView!
    @IBOutlet weak var innerRing: UIView!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var playerViewShadow: UIView!
    
    var counter: Int = 0
    var trackDuration: Int = 0
    var currentTrackInfo:CurrentTrack!
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let logo = UIImage(named: "logo")
        let imageView = UIImageView(image:logo)
        self.navigationItem.titleView = imageView
        
        SocketIOManager.sharedInstance.getState()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("currentTrack"), object: nil, queue: nil, using: { notification in
            self.getCurrentTrackInfo()
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(getCurrentTrackInfo), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        innerRing.makeCircle()
        outerRing.makeCircle()
        
        playerViewShadow.layer.shadowOffset = CGSize.zero
        playerViewShadow.layer.shadowOpacity = 1
        playerViewShadow.layer.shadowRadius = 3
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func pressPlay(_ sender: UIButton) {
        switch SocketIOManager.sharedInstance.currentTrack!.status! {
        case "play":
            SocketIOManager.sharedInstance.setPlayback(status: "pause")
        case "pause":
            SocketIOManager.sharedInstance.setPlayback(status: "play")
        case "stop":
            SocketIOManager.sharedInstance.setPlayback(status: "play")
        default:
            SocketIOManager.sharedInstance.setPlayback(status: "stop")
        }
        getPlayerStatus()
    }
    
    @IBAction func pressPrevious(_ sender: UIButton) {
        SocketIOManager.sharedInstance.prevTrack()
    }
    
    @IBAction func pressNext(_ sender: UIButton) {
        SocketIOManager.sharedInstance.nextTrack()
    }
    
    @IBAction func pressVolumeUp(_ sender: UIButton) {
        if var volume = SocketIOManager.sharedInstance.currentTrack!.volume {
            if volume < 100 {
                volume += 5
                currentVolume.text = "\(volume)"
                SocketIOManager.sharedInstance.setVolume(value: volume)
            }
        }
    }
    
    @IBAction func pressVolumeDown(_ sender: UIButton) {
        if var volume = SocketIOManager.sharedInstance.currentTrack!.volume {
            if volume > 0 {
                volume -= 5
                currentVolume.text = "\(volume)"
                SocketIOManager.sharedInstance.setVolume(value: volume)
            }
        }
    }

    func getCurrentTrackInfo() {
                        
        currentTrackInfo = SocketIOManager.sharedInstance.currentTrack!
        currentAlbum.text = currentTrackInfo.album ?? ""
        currentTitle.text = currentTrackInfo.title ?? ""
        currentArtist.text = currentTrackInfo.artist ?? ""
        
        currentAlbumArt.kf.indicatorType = .activity
        
        if let volume = currentTrackInfo.volume {
            currentVolume.text = "\(volume)"
        } else {
            SocketIOManager.sharedInstance.setVolume(value: 50)
        }
        
        if let duration = currentTrackInfo.duration {
            trackDuration = duration
            currentDuration.text = timeFormatted(totalSeconds: duration)
            if let seek = currentTrackInfo.seek {
                counter = seek
                seekValue.text = timeFormatted(totalSeconds: counter/1000)
                
                let percentage = Float(counter) / (Float(trackDuration) * 1000)
                currentProgress.setProgress(percentage, animated: true)
            }
        }

        if currentTrackInfo.albumArt!.range(of:"http") != nil{
            currentAlbumArt.kf.setImage(with: URL(string: currentTrackInfo.albumArt!), placeholder: UIImage(named: "background"), options: [.transition(.fade(0.2)), .forceRefresh])
        } else {
            LastFmManager.sharedInstance.getAlbumArt(artist: currentTrackInfo.artist!, album: currentTrackInfo.album!, completionHandler: { (albumUrl) in
                if let albumUrl = albumUrl {
                    DispatchQueue.main.async {
                        self.currentAlbumArt.kf.setImage(with: URL(string: albumUrl), placeholder: UIImage(named: "background"), options: [.transition(.fade(0.2)), .forceRefresh])
                    }
                }
            })
        }
        
        if currentTrackInfo.service! == "spop" {
            spotifyTrack.isHidden = false
        }
        
        self.getPlayerStatus()
    }
    
    func getPlayerStatus() {
        if let status = currentTrackInfo.status {
            switch status {
            case "play":
                startTimer()
                self.playButton.setImage(UIImage(named: "pause"), for: UIControlState.normal)
            case "pause":
                stopTimer()
                self.playButton.setImage(UIImage(named: "play"), for: UIControlState.normal)
            case "stop":
                stopTimer()
                self.playButton.setImage(UIImage(named: "play"), for: UIControlState.normal)
            default:
                stopTimer()
                self.playButton.setImage(UIImage(named: "stop"), for: UIControlState.normal)
            }
        }
    }
    
    func timeFormatted(totalSeconds: Int) -> String {
        let seconds: Int = totalSeconds % 60
        let minutes: Int = (totalSeconds / 60) % 60
        let hours: Int = totalSeconds / 3600
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    func startTimer() {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSeek), userInfo:nil, repeats: true)
    }
    
    func stopTimer() {
        timer.invalidate()
        seekValue.text = timeFormatted(totalSeconds: counter/1000)
    }
    
    func updateSeek() {
        counter += 1000
        seekValue.text = timeFormatted(totalSeconds: counter/1000)
        
        let percentage = Float(counter) / (Float(trackDuration) * 1000)
        currentProgress.setProgress(percentage, animated: true)
    }
}

extension UIView {
    
    func makeCircle() {
        self.layer.cornerRadius = self.frame.size.width/2
        self.clipsToBounds = true
    }
}