import Dispatch

public final class ConcreteFunction<Args, ReturnType>: AnyFunction {
  public typealias ClosureType = (Args) -> ReturnType

  public let name: String

  public var takesPromise: Bool {
    return argTypes.last is PromiseArgumentType
  }

  public var argumentsCount: Int {
    return argTypes.count - (takesPromise ? 1 : 0)
  }

  public var queue: DispatchQueue?

  let closure: ClosureType

  let argTypes: [AnyArgumentType]

  init(
    _ name: String,
    argTypes: [AnyArgumentType],
    _ closure: @escaping ClosureType
  ) {
    self.name = name
    self.argTypes = argTypes
    self.closure = closure
  }

  public func call(args: [Any], promise: Promise) {
    let takesPromise = self.takesPromise
    let returnedValue: ReturnType?

    do {
      var finalArgs = try castArguments(args)

      if takesPromise {
        finalArgs.append(promise)
      }

      let tuple = try Conversions.toTuple(finalArgs) as! Args
      returnedValue = closure(tuple)
    } catch let error as CodedError {
      promise.reject(FunctionCallError(name).causedBy(error))
      return
    } catch let error {
      promise.reject(UnexpectedError(error))
      return
    }
    if !takesPromise {
      promise.resolve(returnedValue)
    }
  }

  public func callSync(args: [Any]) -> Any {
    if takesPromise {
      var result: Any?
      let semaphore = DispatchSemaphore(value: 0)

      let promise = Promise {
        result = $0
        semaphore.signal()
      } rejecter: { error in
        semaphore.signal()
      }
      call(args: args, promise: promise)
      semaphore.wait()
      return result as Any
    } else {
      do {
        let finalArgs = try castArguments(args)
        let tuple = try Conversions.toTuple(finalArgs) as! Args
        return closure(tuple)
      } catch let error {
        return error
      }
    }
  }

  public func runOnQueue(_ queue: DispatchQueue?) -> Self {
    self.queue = queue
    return self
  }

  private func argumentType(atIndex index: Int) -> AnyArgumentType? {
    return (0..<argTypes.count).contains(index) ? argTypes[index] : nil
  }

  private func castArguments(_ args: [Any]) throws -> [Any] {
    if args.count != argumentsCount {
      throw InvalidArgsNumberError((received: args.count, expected: argumentsCount))
    }
    return try args.enumerated().map { (index, arg) in
      let expectedType = argumentType(atIndex: index)

      do {
        // It's safe to unwrap since the arguments count matches.
        return try expectedType!.cast(arg)
      } catch {
        throw ArgumentCastError((index: index, type: expectedType!)).causedBy(error)
      }
    }
  }
}

internal class InvalidArgsNumberError: GenericError<(received: Int, expected: Int)> {
  override var message: String {
    "Received \(args.received) arguments, but \(args.expected) was expected."
  }
}

internal class ArgumentCastError: GenericError<(index: Int, type: AnyArgumentType)> {
  override var message: String {
    "Argument at index \"\(args.index)\" couldn't be casted to type \"\(args.type.description)\"."
  }
}

internal class FunctionCallError: GenericError<String> {
  override var message: String {
    "Calling function \"\(args)\" has been rejected."
  }
}
