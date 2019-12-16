
import UIKit

enum ArticleFetcherError: Error {
    case doesNotExist
    case failureToGenerateURL
    case missingData
    case invalidEndpointType
}

@objc(WMFArticleFetcher)
final public class ArticleFetcher: Fetcher {
    
    public enum EndpointType: String {
        case summary
        case mediaList = "media-list"
        case mobileHtmlOfflineResources = "mobile-html-offline-resources"
        case mobileHTML = "mobile-html"
        case references = "references"
    }
    
    typealias RequestURL = URL
    typealias TemporaryFileURL = URL
    typealias MIMEType = String
    typealias DownloadCompletion = (Error?, RequestURL?, TemporaryFileURL?, MIMEType?) -> Void
    
    public static func getURL(siteURL: URL, articleTitle: String, endpointType: EndpointType, configuration: Configuration = Configuration.current, scheme: String? = nil) -> URL? {
        guard let host = siteURL.host,
            let percentEncodedUrlTitle = (articleTitle as NSString)
                .wmf_normalizedPageTitle()
                .addingPercentEncoding(withAllowedCharacters: .wmf_articleTitlePathComponentAllowed) else {
            return nil
        }
        
        let pathComponents = ["page", endpointType.rawValue, percentEncodedUrlTitle]
        
        guard let url: URL = configuration.wikipediaMobileAppsServicesAPIURLComponentsForHost(host, appending: pathComponents).url else {
            return nil
        }
        
        if let scheme = scheme {
            
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.scheme = scheme
            
            return urlComponents?.url
        }
        
        return url
    }
    
    func fetchMobileHTML(siteURL: URL, articleTitle: String, completion: @escaping DownloadCompletion) {
        
        guard let taskURL = ArticleFetcher.getURL(siteURL: siteURL, articleTitle: articleTitle, endpointType: .mobileHTML, configuration: configuration) else {
            completion(ArticleFetcherError.failureToGenerateURL, nil, nil, nil)
            return
        }
        
        downloadData(url: taskURL, completion: completion)
    }
    
    func downloadData(url: URL, completion: @escaping DownloadCompletion) {
        let task = session.downloadTask(with: url) { fileURL, response, error in
            self.handleDownloadTaskCompletion(url: url, fileURL: fileURL, response: response, error: error, completion: completion)
        }
        task.resume()
    }
    
    //tonitodo: track/untrack tasks
    func fetchResourceList(siteURL: URL, articleTitle: String, endpointType: EndpointType, completion: @escaping (Result<[URL], Error>) -> Void) {
        
        guard endpointType == .mediaList || endpointType == .mobileHtmlOfflineResources else {
            completion(.failure(ArticleFetcherError.invalidEndpointType))
            return
        }
        
        guard let taskURL = ArticleFetcher.getURL(siteURL: siteURL, articleTitle: articleTitle, endpointType: endpointType, configuration: configuration) else {
            completion(.failure(ArticleFetcherError.failureToGenerateURL))
            return
        }
        
        session.jsonDecodableTask(with: taskURL) { (urlStrings: [String]?, response: URLResponse?, error: Error?) in
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
                statusCode == 404 {
                completion(.failure(ArticleFetcherError.doesNotExist))
                return
            }
            
            if let error = error {
               completion(.failure(error))
               return
           }
            
            guard let urlStrings = urlStrings else {
                completion(.failure(ArticleFetcherError.missingData))
                return
            }
            
            let result = urlStrings.map { (urlString) -> URL? in
                var urlComponents = URLComponents()
                urlComponents.path = urlString
                urlComponents.scheme = siteURL.scheme
                return urlComponents.url
            }.compactMap{ $0 }
            
            completion(.success(result))
        }
    }
}

private extension ArticleFetcher {
    
    //tonitodo: track/untrack tasks
    func handleDownloadTaskCompletion(url: URL, fileURL: URL?, response: URLResponse?, error: Error?, completion: @escaping DownloadCompletion) {
        if let error = error {
            completion(error, url, nil, nil)
            return
        }
        guard let fileURL = fileURL, let response = response else {
            completion(Fetcher.unexpectedResponseError, url, nil, nil)
            return
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            completion(Fetcher.unexpectedResponseError, url, nil, nil)
            return
        }
        completion(nil, url, fileURL, response.mimeType)
    }
}
