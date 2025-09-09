import SwiftUI
import GoogleGenerativeAI

@MainActor
class StockSummaryViewModel: ObservableObject {
    @Published var summary: [String] = []
    let stockName: String
    private let apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]

    init(stockName: String) {
        self.stockName = stockName
        if apiKey == nil {
            self.summary = ["Error: API Key not configured."]
            return
        }
        generateSummary()
    }

    func generateSummary() {
        guard let apiKey = apiKey else { return }

        Task {
            do {
                let generativeModel = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)

                let prompt = """
                As a financial analyst, please provide a concise and neutral summary of the following company.
                Focus on the core business activities, key products or services, and the market they operate in.
                Avoid making any investment recommendations or using subjective language and also list the pros and cons
                of investing in that company in 1 line each.
                Please return the output as a JSON array of strings, with the first element being the summary,
                the second being the pros, and the third being the cons.

                Here is the company name:

                \(self.stockName)
                """

                let response = try await generativeModel.generateContent(prompt)

                if let generatedText = response.text {
                    let cleanText = generatedText
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let data = cleanText.data(using: .utf8) {
                        let decodedSummary = try JSONDecoder().decode([String].self, from: data)
                        self.summary = decodedSummary
                    } else {
                        self.summary = ["Error: Could not encode generated text."]
                    }
                } else {
                    self.summary = ["No summary generated."]
                }
            } catch {
                print("Error generating content or decoding JSON: \(error)")
                self.summary = ["Failed to generate summary or parse response."]
            }
        }
    }
}
