internal extension RangeReplaceableCollection where Iterator.Element: Equatable {

	mutating func removeFirstEqual(_ element: Iterator.Element) -> (Index, Iterator.Element)? {
		guard let index = firstIndex(of: element) else {
			return nil
		}

		return (index, remove(at: index))
	}
}
