//The MIT License (MIT)
//
//Copyright (c) 2016 Webtrekk GmbH
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
//"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
//distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject
//to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by Webtrekk on 02/06/17.
//

import XCTest
import Nimble
import Webtrekk

class GetTrackIdTest: WTBaseTestNew {
    
    override func getCongigName() -> String? {
        switch self.name {
        case let name where name?.range(of: "test1") != nil:
            // any config with multiple trackIds:
            return "webtrekk_config_multiple_trackIds"
        default:
            // any config with just one trackId (that's the more common case):
            return "webtrekk_config_recommendations"
        }
    }
    
    
    /// Getting the trackIds from an xml config that contains a list of trackIds
    func test1MultipleTrackIds(){
        let trackIds = WebtrekkTracking.instance().trackIds
        expect(trackIds[0]).to(equal("123456789012341"))
        expect(trackIds[1]).to(equal("123456789012342"))
        expect(trackIds[2]).to(equal("123456789012343"))
        expect(trackIds[3]).to(equal("123456789012344"))
    }
    
    
    /// Getting the trackIds from an xml config that contains only one trackId
    func test2OneTrackId(){
        let trackIds = WebtrekkTracking.instance().trackIds
        expect(trackIds[0]).to(equal("123451234512345"))
    }
}
