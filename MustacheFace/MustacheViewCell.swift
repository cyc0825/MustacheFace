//
//  MustacheViewCell.swift
//  MustacheFace
//
//  Created by 曹越程 on 2023/8/18.
//

import UIKit

class MustacheViewCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!
    
    static let identifier = "MustacheViewCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    public func configure(with image: UIImage){
        imageView.image = image
    }
    
    static func nib() -> UINib {
        return UINib(nibName: "MustacheViewCell", bundle: nil)
    }

}
