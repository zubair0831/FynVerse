//
//  UIApplication.swift
//  FynVerse
//
//  Created by zubair ahmed on 18/07/25.
//

import Foundation
import SwiftUI

extension UIApplication{
    func endEdititng(){
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
