import UIKit

@objc(WMFFetcher)
open class Fetcher: NSObject {
    @objc public let configuration: Configuration
    @objc public let session: Session
    
    private var tasks = [String: URLSessionTask]()
    private let semaphore = DispatchSemaphore.init(value: 1)
    
    @objc required public init(session: Session, configuration: Configuration) {
        self.session = session
        self.configuration = configuration
    }
    
    @objc(trackTask:forKey:)
    public func track(task: URLSessionTask, for key: String) {
        semaphore.wait()
        tasks[key] = task
        semaphore.signal()
    }
    
    @objc(untrackTaskForKey:)
    public func untrack(taskFor key: String) {
        semaphore.wait()
        tasks.removeValue(forKey: key)
        semaphore.signal()
    }
    
    @objc(cancelTaskForKey:)
    public func cancel(taskFor key: String) {
        semaphore.wait()
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
        semaphore.signal()
    }
    
    @objc(cancelAllTasks)
    public func cancelAllTasks() {
        semaphore.wait()
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll(keepingCapacity: true)
        semaphore.signal()
    }
}
