public final class WeakReference<T: AnyObject> {

    public weak var target: T?

    public init(_ target: T) { self.target = target }
}
