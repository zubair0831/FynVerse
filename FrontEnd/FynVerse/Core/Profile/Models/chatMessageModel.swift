//
//  chatMessageModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//
import Foundation
struct ChatMessage: Identifiable,Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}
