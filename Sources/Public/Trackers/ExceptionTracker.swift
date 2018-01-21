import Foundation

public protocol ExceptionTracker: class {

    /** do exception tracking for info/warning message */
    func trackInfo(_ name: String, message: String)
    
    /** do exception tracking for exception message */
    func trackException(_ exception: NSException)
    
    /** do exception tracking for NSError message */
    func trackNSError(_ error: NSError)
    
    /** do exception tracking for NSError message */
    func trackError(_ error: Error)
}
