import Foundation

/**
 A protocol for errors specyfing its `code` and providing the `description`.
 */
public protocol CodedError: Error {
  var code: String { get }
  var description: String { get }
}

public protocol CausedError: Error, AnyObject {
  var cause: Error? { get set }
  var rootCause: Error? { get }
  func causedBy(_ error: Error) -> Self
}

public extension CausedError {
  var rootCause: Error? {
    if let cause = cause as? CausedError {
      return cause.rootCause
    }
    return cause
  }

  func causedBy(_ error: Error) -> Self {
    cause = error
    return self
  }
}

public class BaseError: CodedError, CausedError, CustomStringConvertible {
  public var name: String {
    return String(describing: Self.self)
  }

  public var message: String {
    "undefined message"
  }

  public var description: String {
    let description = "\(name): \(message)"

    if let cause = cause as? CodedError {
      return "\(description)\n→ Caused by \(cause.description)"
    } else if let cause = cause {
      return "\(description)\n→ Caused by: \(cause.localizedDescription)"
    }
    return description
  }

  // MARK: CausedError

  public var cause: Error?
}

public class GenericError<ArgsType>: BaseError {
  public let args: ArgsType

  public init(_ args: ArgsType) {
    self.args = args
  }
}

/**
 Extends the `CodedError` to make a fallback for `code` and `description`.
 */
public extension CodedError {
  /**
   The code is inferred from the class name — e.g. the code of `ModuleNotFoundError` becomes `ERR_MODULE_NOT_FOUND`.
   To obtain the code, the class name is cut off from generics and `Error` suffix, then it's converted to snake case and uppercased.
   */
  var code: String {
    let className = String(describing: type(of: self))
      .replacingOccurrences(of: #"(Error)?(<.*>)?$"#, with: "", options: .regularExpression)
    let regex = try! NSRegularExpression(pattern: "(.)([A-Z])", options: [])
    let range = NSRange(location: 0, length: className.count)

    return "ERR_" + regex
      .stringByReplacingMatches(in: className, options: [], range: range, withTemplate: "$1_$2")
      .uppercased()
  }

  /**
   The description falls back to object's localized description.
   */
  var description: String {
    return localizedDescription
  }
}

/**
 Basic implementation of `CodedError` protocol,
 where the code and the description are provided in the initializer.
 */
public struct SimpleCodedError: CodedError {
  public var code: String
  public var description: String

  init(_ code: String, _ description: String) {
    self.code = code
    self.description = description
  }
}

/**
 Coded wrapper for uncoded errors. Intended to be used to handle unexpected native errors.
 */
public struct UnexpectedError: CodedError {
  public let description: String

  init(_ error: Error) {
    self.description = error.localizedDescription
  }
}
