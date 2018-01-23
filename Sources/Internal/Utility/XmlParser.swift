import Foundation

internal struct XmlElement {

	internal var attributes: [String: String]
	internal var children: [XmlElement]
	internal var path: [String]
	internal var text: String

	internal var name: String {
		return path.last ?? ""
	}

	internal init(attributes: [String: String], children: [XmlElement], path: [String], text: String) {
		self.attributes = attributes
		self.children = children
		self.path = path
		self.text = text
	}
}

internal final class XmlParser {

	internal func parse(xml data: Data) throws -> XmlElement {

        let parser = try ActualParser(xml: data)

        return parser.rootElement
	}
}

private final class ActualParser: NSObject {

	fileprivate var currentText = ""
	fileprivate var elementBuilder: ElementBuilder?
	fileprivate var elementBuilderStack = [ElementBuilder]()
	fileprivate var elementPath = [String]()
	fileprivate var error: Error?
	fileprivate let parser: XMLParser
	fileprivate var rootElement: XmlElement!

	fileprivate init(xml data: Data) throws {
		self.parser = XMLParser(data: data)

		super.init()

		parser.delegate = self
		parser.parse()
		parser.delegate = nil

		if let error = self.error {
			throw error
		}

        if self.rootElement == nil {
            throw TrackerError(message: "Configuration xml is invalid. Its probably don't have xml content to parce")
        }
	}

	fileprivate final class ElementBuilder {

		fileprivate let attributes: [String: String]
		fileprivate var children = [XmlElement]()
		fileprivate let path: [String]
		fileprivate var text = ""

		fileprivate init(attributes: [String: String], path: [String]) {
			self.attributes = attributes
			self.path = path
		}

		fileprivate func build() -> XmlElement {
			return XmlElement(attributes: attributes, children: children, path: path, text: text)
		}
	}
}

extension ActualParser: XMLParserDelegate {

	@objc
	fileprivate func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
		guard let elementBuilder = elementBuilder else {
			fatalError()
		}

		currentText = currentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

		elementBuilder.text = currentText

		let element = elementBuilder.build()

		if let parentElementBuilder = elementBuilderStack.popLast() {
			parentElementBuilder.children.append(element)

			self.elementBuilder = parentElementBuilder
		} else {
			rootElement = element

			self.elementBuilder = nil
		}

		currentText = ""
		elementPath.removeLast()
	}

	@objc
	fileprivate func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
		currentText = ""
		elementPath.append(elementName)

		if let elementBuilder = elementBuilder {
			elementBuilderStack.append(elementBuilder)
		}

		elementBuilder = ElementBuilder(attributes: attributes, path: elementPath)
	}

	@objc
	fileprivate func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	@objc
	fileprivate func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		if error == nil {
			error = parseError
		}
	}
}
