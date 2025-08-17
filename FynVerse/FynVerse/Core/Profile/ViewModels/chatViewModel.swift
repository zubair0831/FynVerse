//
//  chatViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation
import GoogleGenerativeAI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    
    private let apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = inputText
        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""
        
        Task {
            let response = await getGeminiResponse(prompt: userMessage)
            messages.append(ChatMessage(text: response, isUser: false))
        }
    }
    
    private func getGeminiResponse(prompt: String) async -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return "Error: API Key is not configured."
        }

        do {
            let generativeModel = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)
            let response = try await generativeModel.generateContent(prompt)
            return response.text ?? "No response generated."
        } catch {
            print("Error generating content: \(error)")
            return "Sorry, I couldn't respond. Error: \(error.localizedDescription)"
        }
    }
}
