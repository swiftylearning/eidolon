import Foundation
import Quick
import Nimble
@testable
import Kiosk
import Moya
import RxBlocking
import RxSwift
import Action

private enum DefaultsKeys: String {
    case TokenKey = "TokenKey"
    case TokenExpiry = "TokenExpiry"
}

func clearDefaultsKeys(_ defaults: UserDefaults) {
    defaults.removeObject(forKey: DefaultsKeys.TokenKey.rawValue)
    defaults.removeObject(forKey: DefaultsKeys.TokenExpiry.rawValue)
}

func getDefaultsKeys(_ defaults: UserDefaults) -> (key: String?, expiry: Date?) {
    let key = defaults.object(forKey: DefaultsKeys.TokenKey.rawValue) as! String?
    let expiry = defaults.object(forKey: DefaultsKeys.TokenExpiry.rawValue) as! Date?
    
    return (key: key, expiry: expiry)
}

func setDefaultsKeys(_ defaults: UserDefaults, key: String?, expiry: Date?) {
    defaults.set(key, forKey: DefaultsKeys.TokenKey.rawValue)
    defaults.set(expiry, forKey: DefaultsKeys.TokenExpiry.rawValue)
}

func yearFromDate(_ date: Date) -> Int {
    let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    return (calendar as NSCalendar).components(.year, from: date).year!
}

@objc class TestClass: NSObject { }

// Necessary since UIImage(named:) doesn't work correctly in the test bundle
extension UIImage {
    class func testImage(named name: String, ofType type: String) -> UIImage! {
        let bundle = Bundle(for: type(of: TestClass()))
        let path = bundle.pathForResource(name, ofType: type)
        return UIImage(contentsOfFile: path!)
    }
}

func testArtwork() -> Artwork {
    return Artwork.fromJSON(["id": "red",
    "title" : "Rose Red",
    "date": "June 11th 2014",
    "blurb": "Pretty good",
    "artist": ["id" : "artistDee", "name": "Dee Emm"],
    "images": [
        ["id" : "image_id",
        "image_url" : "http://example.com/:version.jpg",
        "image_versions" : ["large"],
        "aspect_ratio" : 1.508,
        "tile_base_url" : "http://example.com",
        "tile_size" : 1]
    ]])
}

let testAuctionID = "AUCTION"

func testSaleArtwork() -> SaleArtwork {
    let saleArtwork = SaleArtwork(id: "12312313", artwork: testArtwork())
    saleArtwork.auctionID = testAuctionID
    return saleArtwork
}

func testBidDetails() -> BidDetails {
    return BidDetails(saleArtwork: testSaleArtwork(), paddleNumber: "1111", bidderPIN: "2222", bidAmountCents: 123456, auctionID: testAuctionID)
}

class StubFulfillmentController: FulfillmentController {
    lazy var bidDetails: BidDetails = { () -> BidDetails in
        let bidDetails = testBidDetails()
        bidDetails.setImage = { (_, imageView) -> () in
            imageView.image = loadingViewControllerTestImage
        }
        return bidDetails
        }()

    var auctionID: String! = ""
    var xAccessToken: String?
}

/// Nimble is currently having issues with nondeterministic async expectations.
/// This will have to do for now 😢
/// See: https://github.com/Quick/Nimble/issues/177
func kioskWaitUntil(_ action: (() -> Void) -> Void) {
    waitUntil(timeout: 10, action: action)
}


// TODO: Move these into a separate pod?
// This is handy so we can write expect(o) == 1 instead of expect(o.value) == 1 or whatever.
public func equalFirst<T: Equatable>(_ expectedValue: T?) -> MatcherFunc<Observable<T>> {
    return MatcherFunc { actualExpression, failureMessage in

        failureMessage.postfixMessage = "equal <\(expectedValue)>"
        let actualValue = try actualExpression.evaluate()?.toBlocking().first()

        let matches = actualValue == expectedValue
        return matches
    }
}

public func equalFirst<T: Equatable>(_ expectedValue: T?) -> MatcherFunc<Variable<T>> {
    return MatcherFunc { actualExpression, failureMessage in

        failureMessage.postfixMessage = "equal <\(expectedValue)>"
        let actualValue = try actualExpression.evaluate()?.value

        let matches = actualValue == expectedValue && expectedValue != nil
        return matches
    }
}

public func equalFirst<T: Equatable>(_ expectedValue: T?) -> MatcherFunc<Observable<Optional<T>>> {
    return MatcherFunc { actualExpression, failureMessage in

        failureMessage.postfixMessage = "equal <\(expectedValue)>"
        let actualValue = try actualExpression.evaluate()?.toBlocking().first()

        switch actualValue {
        case .None:
            return expectedValue == nil
        case .Some(let wrapped):
            return wrapped == expectedValue
        }
    }
}

public func equalFirst<T: Equatable>(_ expectedValue: T?) -> MatcherFunc<Variable<Optional<T>>> {
    return MatcherFunc { actualExpression, failureMessage in

        failureMessage.postfixMessage = "equal <\(expectedValue)>"
        let actualValue = try actualExpression.evaluate()?.value

        switch actualValue {
        case .None:
            return expectedValue == nil
        case .Some(let wrapped):
            return wrapped == expectedValue
        }
    }
}

public func ==<T: Equatable>(lhs: Expectation<Observable<T>>, rhs: T?) {
    lhs.to(equalFirst(rhs))
}

public func ==<T: Equatable>(lhs: Expectation<Variable<T>>, rhs: T?) {
    lhs.to(equalFirst(rhs))
}

public func ==<T: Equatable>(lhs: Expectation<Observable<Optional<T>>>, rhs: T?) {
    lhs.to(equalFirst(rhs))
}

public func ==<T: Equatable>(lhs: Expectation<Variable<Optional<T>>>, rhs: T?) {
    lhs.to(equalFirst(rhs))
}


// TODO: Move into Action pod?

enum TestError: String {
    case Default
}

extension TestError: Error { }

func emptyAction() -> CocoaAction {
    return CocoaAction { _ in Observable.empty() }
}

func neverAction() -> CocoaAction {
    return CocoaAction { _ in Observable.never() }
}

func errorAction(_ error: ErrorType = TestError.Default) -> CocoaAction {
    return CocoaAction { _ in Observable.error(error) }
}

func disabledAction() -> CocoaAction {
    return CocoaAction(enabledIf: Observable.just(false)) { _ in Observable.empty() }
}

