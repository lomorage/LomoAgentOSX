//
//  QRImage.swift
//  QRCodeSample
//
//  Created by ing.conti on 08/06/2019.
//  Copyright © 2019 ing.conti. All rights reserved.
//



#if os(iOS)
import UIKit
typealias QRImage = UIImage
#elseif os(OSX)
import Cocoa
typealias QRImage = NSImage
#endif

func QRCodeImageWith(string: String, size: CGFloat = 500) -> QRImage?{

    guard let data = string.data(using: .utf8) else {
        return nil
    }
    
    return QRCodeImageWith(data: data, size: size)
}

func QRCodeImageWith(data: Data, size: CGFloat = 500) -> QRImage?{
    
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
        return nil
    }
    
    filter.setValue(data, forKey: "inputMessage")
    guard let ciImage = filter.outputImage else {
        return nil
    }
    
    let destRect = CGRect(x: 0, y: 0, width: size, height: size)
    
    
    #if os(iOS)

    let tinyImage = UIImage(ciImage: ciImage)
    if (size <= tinyImage.size.width){
        return tinyImage
    }
    
    
    // Scale image up:
    UIGraphicsBeginImageContext(CGSize(width: size, height: size))
    if let context = UIGraphicsGetCurrentContext(){
        context.interpolationQuality = .none
        tinyImage.draw(in: destRect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    return nil
    
    #elseif os(OSX)
    
    let rep = NSCIImageRep(ciImage: ciImage)
    let tinyImage = NSImage()
    tinyImage.addRepresentation(rep)
    if size <= rep.size.width {
        return tinyImage as QRImage
    }
    
    // Scale image up:
    let nsImage = NSImage(size: NSSize(width: size, height: size))
    nsImage.lockFocus()
    
    let ctx = NSGraphicsContext.current
    ctx?.imageInterpolation = NSImageInterpolation.none
    tinyImage.draw(in: destRect)
    nsImage.unlockFocus()
    return nsImage
    

    #endif
}


// SEE below for usage on iOS and OSX

