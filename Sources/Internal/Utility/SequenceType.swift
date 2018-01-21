import Foundation

internal extension Sequence {

	internal func firstMatching(predicate: (Iterator.Element) throws -> Bool) rethrows -> Iterator.Element? {
		for element in self where try predicate(element) {
			return element
		}

		return nil
	}

	internal func mapNotNil<T>(transform: (Iterator.Element) throws -> T?) rethrows -> [T] {
		var result = [T]()

		for element in self {
			guard let mappedElement = try transform(element) else {
				continue
			}

			result.append(mappedElement)
		}

		return result
	}
}

internal extension Sequence where Iterator.Element: _Optional {

	internal func filterNonNil() -> [Iterator.Element.Wrapped] {
		var result = Array<Iterator.Element.Wrapped>()
		for element in self {
			guard let element = element.value else {
				continue
			}

			result.append(element)
		}

		return result
	}
}
