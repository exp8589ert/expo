// Copyright 2021-present 650 Industries. All rights reserved.

import Quick
import Nimble

@testable import ExpoModulesCore

final class ErrorsSpec: QuickSpec {
  override func spec() {
    it("has name") {
      let error = TestError()
      expect(error.name) == "TestError"
    }

    it("has code") {
      let error = TestError()
      expect(error.code) == "ERR_TEST"
    }

    it("has message") {
      let error = TestError()
      expect(error.message) == "This is test error"
    }

    describe("chaining") {
      it("can be chained once") {
        func throwable() throws {
          do {
            throw TestCauseError()
          } catch {
            throw TestError().causedBy(error)
          }
        }
        expect { try throwable() }.to(throwError { error in
          expect(error).to(beAKindOf(TestError.self))
          expect((error as! TestError).cause).to(beAKindOf(TestCauseError.self))
        })
      }

      it("can be chained twice") {
        func throwable() throws {
          do {
            do {
              throw TestCauseError()
            } catch {
              throw TestCauseError().causedBy(error)
            }
          } catch {
            throw TestError().causedBy(error)
          }
        }
        expect { try throwable() }.to(throwError { error in
          expect(error).to(beAKindOf(TestError.self))
          expect((error as! TestError).cause).to(beAKindOf(TestCauseError.self))
          expect(((error as! TestError).cause as! TestCauseError).cause).to(beAKindOf(TestCauseError.self))
        })
      }

      it("includes cause description") {
        func throwable() throws {
          do {
            throw TestCauseError()
          } catch {
            throw TestError().causedBy(error)
          }
        }
        expect { try throwable() }.to(throwError { error in
          if let error = error as? TestError, let cause = error.cause as? TestCauseError {
            expect(error.description).to(contain(cause.description))
          } else {
            fail("Error and its cause are not of expected types.")
          }
        })
      }
    }
  }
}

class TestError: BaseError {
  override var message: String {
    "This is test error"
  }
}

class TestCauseError: BaseError {
  override var message: String {
    "This is the cause of test error"
  }
}
