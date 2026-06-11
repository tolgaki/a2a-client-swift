// SSEConnection.swift
// A2AClient
//
// Delegate-backed streaming HTTP connection for Server-Sent Events.
//
// `URLSession.bytes(for:)` does not reliably deliver bytes incrementally
// on Linux (swift-corelibs-foundation), which stalls SSE consumption until
// the connection closes. `URLSessionDataDelegate` delivers chunks as they
// arrive on both Darwin and Linux, so streaming uses it on every platform.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One streaming HTTP request: yields the response head once available,
/// then body bytes as `Data` chunks while they arrive.
///
/// - Important: `@unchecked Sendable` is safe because all mutable state is
///   guarded by `lock`; the stream continuation is itself thread-safe.
final class SSEConnection: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let chunkStream: AsyncThrowingStream<Data, Error>
    private let chunkContinuation: AsyncThrowingStream<Data, Error>.Continuation

    private let lock = NSLock()
    private var session: URLSession?
    private var responseContinuation: CheckedContinuation<URLResponse, Error>?

    override init() {
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.chunkStream = AsyncThrowingStream { continuation = $0 }
        self.chunkContinuation = continuation
        super.init()
    }

    /// Starts the request and suspends until the response head arrives.
    ///
    /// - Returns: The response and the stream of body chunks. The caller
    ///   must either consume the stream to completion or call `cancel()`.
    func connect(request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, Error>) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
        lock.lock()
        self.session = session
        lock.unlock()

        let task = session.dataTask(with: request)
        let response: URLResponse = try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            responseContinuation = continuation
            lock.unlock()
            task.resume()
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            cancel()
            throw A2AError.invalidResponse(message: "Invalid response type")
        }
        return (httpResponse, chunkStream)
    }

    /// Tears down the connection and ends the chunk stream.
    func cancel() {
        lock.lock()
        let session = self.session
        self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
        chunkContinuation.finish()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        let continuation = responseContinuation
        responseContinuation = nil
        lock.unlock()
        continuation?.resume(returning: response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        chunkContinuation.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = responseContinuation
        responseContinuation = nil
        self.session = nil
        lock.unlock()

        if let continuation = continuation {
            // The connection failed before the response head arrived.
            continuation.resume(throwing: error ?? A2AError.invalidResponse(
                message: "Connection closed before a response was received"
            ))
        }
        chunkContinuation.finish(throwing: error)
        session.finishTasksAndInvalidate()
    }
}

// MARK: - Line Splitting

/// Incrementally splits raw byte chunks into text lines for the SSE parser.
/// Handles `\n` and `\r\n` terminators and lines that span chunk boundaries.
struct SSELineSplitter {
    private var buffer = Data()

    /// Feeds one chunk; returns every complete line it terminates.
    mutating func push(_ chunk: Data) -> [String] {
        buffer.append(chunk)
        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            var line = buffer.prefix(upTo: newlineIndex)
            if line.last == UInt8(ascii: "\r") {
                line = line.dropLast()
            }
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(...newlineIndex)
        }
        return lines
    }

    /// Returns any final unterminated line at end of stream.
    mutating func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        var line = buffer[...]
        if line.last == UInt8(ascii: "\r") {
            line = line.dropLast()
        }
        let result = String(decoding: line, as: UTF8.self)
        buffer.removeAll()
        return result
    }
}
