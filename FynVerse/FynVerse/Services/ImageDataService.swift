//
//  ImageDataService.swift
//  FynVerse
//
//  Created by zubair ahmed on 18/07/25.
//


import Foundation
import SwiftUI

struct LogoResult: Decodable {
    let name: String
    let domain: String
    let logo_url: String
}

final class ImageDataService {
    
    static let shared = ImageDataService()
    private init() {}
   

    private let baseURL = "https://api.logo.dev/search?q="
    private let headers = ["Authorization": "Bearer: sk_RN7EYRdzSbyiSFoD8cSfOg"]
    
   
    func fetchFirstLogoImage(for query: String) async throws -> String? {
        let urlString = baseURL + query

        let logos: [LogoResult] = try await NetworkManager.shared.fetch(
            urlString: urlString,
            headers: headers,
            responseType: [LogoResult].self
        )

        guard let logoURL = logos.first?.logo_url else { return nil }

        //return try await fetchImage(from: logoURL)
        return logoURL
    }

    func fetchImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}
