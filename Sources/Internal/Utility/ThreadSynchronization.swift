import Foundation

class SimpleSync<T> {
    private let thread: DispatchQueue
    private var valueInst: T
    
    init(value: T){
        thread = DispatchQueue(label: "webtrekk_simple_sync", qos: .utility, attributes: .concurrent)
        valueInst = value
    }
    
    var value : T {
        get {
            var value : T?
            self.thread.sync(){
                value = self.valueInst
            }
            return value!
        }
        set(value) {
            self.thread.sync(flags: .barrier){
                self.valueInst = value
            }
        }
    }
    
    func increment<T2: BinaryInteger>(to: T2){
        self.thread.sync(flags: .barrier){
            var val = self.valueInst as! T2
            val += to
            self.valueInst = val as! T
        }
    }
}

class ArraySync<T> {
    private let thread: DispatchQueue
    private var valueInst: [T]
    
    init(){
        thread = DispatchQueue(label: "webtrekk_array_sync", qos: .utility, attributes: .concurrent)
        valueInst = [T]()
    }
    
    var first : T? {
        var value : T?
        self.thread.sync(){
            value = self.valueInst.first
        }
        return value
    }
    
    var last : T? {
        var value : T?
        self.thread.sync(){
            value = self.valueInst.last
        }
        return value
    }
    
    var count : Int {
        var value : Int?
        self.thread.sync(){
            value = self.valueInst.count
        }
        return value!
    }
    
    var isEmpty : Bool {
        var value : Bool?
        self.thread.sync(){
            value = self.valueInst.isEmpty
        }
        return value!
    }
    
    func append(_ value: T){
        self.thread.sync(flags: .barrier){
            self.valueInst.append(value)
        }
    }
    
    func remove(at: Int){
        let _ = self.thread.sync(flags: .barrier){
            self.valueInst.remove(at: at)
        }
    }
    
    func removeAll(){
        self.thread.sync(flags: .barrier){
            self.valueInst.removeAll()
        }
    }
    
    subscript(index: Int) -> T {
        get {
            var value : T?
            self.thread.sync(){
                value = self.valueInst[index]
            }
            return value!
        }
        
        set(newValue) {
            self.thread.sync(flags: .barrier){
                self.valueInst[index] = newValue
            }
        }
    }
}
