import Foundation

/// Reads all available bytes from an InputStream into Data.
///
/// Used by MockURLProtocol subclasses to capture request body data
/// from `httpBodyStream` when `httpBody` is nil (e.g., streaming requests).
///
/// - Parameter stream: The input stream to read from. The stream is opened
///   and closed automatically.
/// - Returns: The accumulated data, or nil if a read error occurs.
func readRequestBodyFromStream(_ stream: InputStream) -> Data? {
    stream.open()
    defer { stream.close() }

    let bufferSize = 4096
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 { return nil }
        if bytesRead == 0 { break }
        data.append(buffer, count: bytesRead)
    }

    return data
}

/// Creates a URLSession with an ephemeral configuration that routes all
/// requests through the given mock URLProtocol subclass.
///
/// - Parameter protocolClass: The URLProtocol subclass to intercept requests.
/// - Returns: A configured URLSession ready for mock-based testing.
func makeMockURLSession(protocolClass: URLProtocol.Type) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [protocolClass]
    return URLSession(configuration: config)
}
