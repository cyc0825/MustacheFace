//
//  VideoCell.swift
//  MustacheFace
//
//  Created by 曹越程 on 2023/8/19.
//

import UIKit
import AVKit
import AVFoundation

class VideoCell: UITableViewCell {

    @IBOutlet var preview: UIImageView!
    @IBOutlet var tags: UILabel!
    @IBOutlet var duration: UILabel!
    
    static let identifier = "VideoCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = UIColor.white
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func thumbnailFromVideo(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time = CMTimeMakeWithSeconds(0.0, preferredTimescale: 600)
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: img)
            return thumbnail
        } catch {
          // Handle error
          return nil
        }
    }
    
    func durationToString(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public func configure(video: VideoEntity){
        preview.layer.cornerRadius = 10
        print(URL(fileURLWithPath: video.videoURL!))
        preview.image = thumbnailFromVideo(url: URL(string: video.videoURL!)!)
        tags.text = video.tag
        tags.textColor = UIColor.black
        duration.text = durationToString(video.duration)
        duration.textColor = UIColor.gray
    }
    
    static func nib() -> UINib {
        return UINib(nibName: "VideoCell", bundle: nil)
    }
    
}
