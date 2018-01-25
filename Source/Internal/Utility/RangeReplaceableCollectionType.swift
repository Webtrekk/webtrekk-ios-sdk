internal extension RangeReplaceableCollection where Iterator.Element: Equatable {

	internal mutating func removeFirstEqual(_ element: Iterator.Element) -> (Index, Iterator.Element)? {
		guard let index = index(of: element) else {
			return nil
		}

		return (index, remove(at: index))
	}
}
