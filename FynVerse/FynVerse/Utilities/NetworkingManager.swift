import Foundation
import SwiftUI

enum NetworkError: Error {
    case badURL
    case invalidResponse
    case badStatusCode(Int)
    case decodingFailed(Error)
    case unknown(Error)
}

final class NetworkManager {
    
    static let shared = NetworkManager()
    
    private init() {}

    func fetch<T: Decodable>(
        urlString: String,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.badStatusCode(httpResponse.statusCode)
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    func fetchImage(urlString: String) async throws -> UIImage {
           guard let url = URL(string: urlString) else {
               throw NetworkError.badURL
           }

           let (data, response) = try await URLSession.shared.data(from: url)

           guard let httpResponse = response as? HTTPURLResponse,
                 (200...299).contains(httpResponse.statusCode) else {
               throw NetworkError.badStatusCode((response as? HTTPURLResponse)?.statusCode ?? -1)
           }

           guard let image = UIImage(data: data) else {
               throw URLError(.cannotDecodeRawData)
           }

           return image
       }
}
