//
//  ImageLoader.swift
//  99reddits
//
//  Created by Pietro Rea on 9/30/17.
//  Copyright © 2017 99 reddits. All rights reserved.
//

import UIKit
import Nuke

typealias ImageLoaderCompletionHandler = ((UIImage) -> Void)

//Objective-C compatible wrapper around Nuke
class ImageLoader: NSObject {
  static func load(urlString: String, into imageView: UIImageView) {
    guard let url = URL(string: urlString) else {
      return
    }

    Nuke.loadImage(with: url, into: imageView)
  }

  static func load(urlString: String, into imageView: UIImageView, completion: @escaping ImageLoaderCompletionHandler) {
    guard let url = URL(string: urlString) else {
      return
    }

    let request = Request(url: url)
    Nuke.loadImage(with: request, into: imageView) { (result, _) in
      switch result {
      case .success(let image):
        completion(image)
      case .failure(let error):
        //handle error
        print(error)
      }
    }
  }
}
