import ObjectiveC

private func class_getInstanceMethodIgnoringSupertypes(_ clazz: AnyClass, _ name: Selector) -> Method? {
	let method = class_getInstanceMethod(clazz, name)

	if let superclass = class_getSuperclass(clazz) {
		let superclassMethod = class_getInstanceMethod(superclass, name)
		guard superclassMethod != method else {
			return nil
		}
	}

	return method!
}

internal func swizzleMethod(ofType type: AnyClass, fromSelector: Selector, toSelector: Selector) -> Bool {
	precondition(fromSelector != toSelector)

	guard let fromMethod = class_getInstanceMethodIgnoringSupertypes(type, fromSelector) else {
		logError("Selector '\(fromSelector)' was not swizzled with selector '\(toSelector)' since the former is not present in '\(type)'.")
		return false
	}

	guard let toMethod = class_getInstanceMethodIgnoringSupertypes(type, toSelector) else {
		logError("Selector '\(fromSelector)' was not swizzled with selector '\(toSelector)' since the latter is not present in '\(type)'.")
		return false
	}

	let fromTypePointer = method_getTypeEncoding(fromMethod)
	let toTypePointer = method_getTypeEncoding(toMethod)
    
	guard fromTypePointer != nil && toTypePointer != nil,
    let fromType = String(validatingUTF8: fromTypePointer!),
    let toType = String(validatingUTF8: toTypePointer!) else {
		logError("Selector '\(fromSelector)' was not swizzled with selector '\(toSelector)' since their type encodings could not be accessed.")
		return false
	}
    
	guard fromType == toType else {
		logError("Selector '\(fromSelector)' was not swizzled with selector '\(toSelector)' since their type encodings don't match: '\(fromType)' -> '\(toType)'.")
		return false
	}

	method_exchangeImplementations(fromMethod, toMethod)
	return true
}

// function adds method to class from another class
func addMethodFromAnotherClass(toClass: AnyClass, selectorToUse: Selector, methodSelector: Selector, fromClass: AnyClass) -> Bool{
    
    //get method object
    
    guard let method = class_getInstanceMethod(fromClass, methodSelector) else{
        WebtrekkTracking.defaultLogger.logError("can't get method from method selector")
        return false
    }
    
    let methodImpl = method_getImplementation(method)
    let methodTypes = method_getTypeEncoding(method)
    
    if  methodTypes == nil {
        WebtrekkTracking.defaultLogger.logError("can't get method types from method")
        return false
    }
    
    return class_addMethod(toClass, selectorToUse, methodImpl, methodTypes)
}

// use method from another class, add it to required class and replace implementation
func replaceImplementationFromAnotherClass(toClass: AnyClass, methodChanged: Selector, fromClass: AnyClass, methodAdded: Selector) -> Bool {
    
    // method is already added
    guard !class_respondsToSelector(toClass, methodAdded) else {
        return true
    }
    
    let methodName = String(cString: sel_getName(methodChanged))
    
    //no such method just add, no need to replace
    if !class_respondsToSelector(toClass, methodChanged) {
        // just add this function
        guard addMethodFromAnotherClass(toClass: toClass, selectorToUse: methodChanged, methodSelector:methodAdded, fromClass: fromClass) else {
            WebtrekkTracking.defaultLogger.logError("Can't add original method \(methodName) to class.")
            return false
        }
    } else {
        guard addMethodFromAnotherClass(toClass: toClass, selectorToUse: methodAdded, methodSelector:methodAdded, fromClass: fromClass) else {
            WebtrekkTracking.defaultLogger.logError("Can't add method \(methodName) to delegate class.")
            return false
        }

        if swizzleMethod(ofType: toClass, fromSelector: methodChanged, toSelector: methodAdded) {
            WebtrekkTracking.defaultLogger.logDebug("swizzle extention delegate method \(methodName) successfully")
        } else {
            WebtrekkTracking.defaultLogger.logError("Cann't swizzle method \(methodName)")
            return false
        }
    }
    
    return true
}
