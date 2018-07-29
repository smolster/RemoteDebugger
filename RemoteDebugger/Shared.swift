//
//  Shared.swift
//  UniversalDebugger-iOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation

public struct DebugData<State: Codable>: Codable {
    let state: State
    let action: String
    let png: Data
}

// MARK: - View Capturing
#if canImport(UIKit)
import UIKit
internal extension UIView {
    func capture() -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = self.isOpaque
        let renderer = UIGraphicsImageRenderer(size: self.frame.size, format: format)
        return renderer.image { _ in
            drawHierarchy(in: self.frame, afterScreenUpdates: true)
        }
    }
}
#endif


// MARK: - Networking
internal struct JSONOverTCPEncoder {
    public func encode<E: Encodable>(_ object: E) throws -> Data {
        let jsonData = try JSONEncoder().encode(object)
        
        var encodedLength = Data(count: 4)
        
        encodedLength.withUnsafeMutableBytes { bytes in
            bytes.pointee = Int32(jsonData.count)
        }
        
        return Data(bytes: [206] + encodedLength + [UInt8](jsonData))
    }
}

internal struct JSONOverTCPDecoder<T: Decodable> {
    
    private var onResult: (Result) -> Void
    private var buffer = Data()
    private var bytesExpected: Int?
    
    enum Result {
        case decodingError(Error)
        case success(T)
    }
    
    internal init(onResult: @escaping (Result) -> Void) {
        self.onResult = onResult
    }
    
    internal mutating func decode(_ data: Data) {
        buffer.append(data)
        
        if buffer.count > 5 && bytesExpected == nil {
            guard buffer.removeFirst() == 206 else {
                fatalError("Did not find 206 as first byte of message. Please conform to the JSON over TCP protocol.")
            }
            let sizeBytes = buffer.prefix(4)
            buffer.removeFirst(4)
            
            let sizeOfJSON: Int32 = sizeBytes.withUnsafeBytes { $0.pointee }
            self.bytesExpected = Int(sizeOfJSON)
        }
        
        if let bytesExpected = self.bytesExpected, buffer.count >= bytesExpected {
            let jsonData = buffer.prefix(bytesExpected)
            buffer.removeFirst(bytesExpected)
            
            do {
                onResult(.success(try JSONDecoder().decode(T.self, from: jsonData)))
            } catch {
                onResult(.decodingError(error))
            }
            self.bytesExpected = nil
        }
    }
}

internal final class BufferedWriter: NSObject, StreamDelegate {
    
    private let queue: DispatchQueue = DispatchQueue(label: "writer")
    private let outputStream: OutputStream
    private let onEnd: (Result) -> Void
    private var buffer = Data()
    
    internal enum Result {
        case error(Error)
        case eof
    }
    
    internal init(_ outputStream: OutputStream, onEnd: @escaping (Result) -> Void) {
        self.outputStream = outputStream
        self.onEnd = onEnd
        super.init()
        CFWriteStreamSetDispatchQueue(outputStream, queue)
        outputStream.open()
        outputStream.delegate = self
    }
    
    internal func write(data: Data) {
        queue.async {
            self.buffer.append(data)
            self.resume()
        }
    }
    
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            resume()
        case .hasSpaceAvailable:
            resume()
        case .errorOccurred:
            onEnd(.error(outputStream.streamError!))
            outputStream.close()
        case .endEncountered:
            onEnd(.eof)
            outputStream.close()
        default:
            fatalError()
        }
    }
    
    private func resume() {
        // Writing empty data will be interpreted as EOF, so we need the check to ensure the buffer isn't empty.
        while !buffer.isEmpty && outputStream.hasSpaceAvailable && outputStream.streamStatus == .open {
            let data = buffer.prefix(1024) // Hardcoded chunk size.
            let bytesWritten = data.withUnsafeBytes { bytes in
                outputStream.write(bytes, maxLength: data.count)
            }
            switch bytesWritten {
            case -1:
                onEnd(.error(outputStream.streamError!))
                outputStream.close()
            case 0:
                onEnd(.eof)
                outputStream.close()
            case 1...:
                buffer.removeFirst(bytesWritten)
            default:
                fatalError()
            }
        }
    }
}

internal final class BufferedReader: NSObject, StreamDelegate {
    private let queue: DispatchQueue = DispatchQueue(label: "reader")
    private let inputStream: InputStream
    private let onResult: (Result) -> Void
    private var buffer = Data()
    
    internal enum Result {
        case chunk(Data)
        case error(Error)
        case eof
    }
    
    internal init(_ inputStream: InputStream, onResult: @escaping (Result) -> Void) {
        self.inputStream = inputStream
        self.onResult = onResult
        super.init()
        CFReadStreamSetDispatchQueue(inputStream, queue)
        inputStream.open()
        inputStream.delegate = self
    }
    
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            break
        case .hasBytesAvailable:
            let chunkSize = 1024
            var data = Data(count: chunkSize)
            let bytesRead = data.withUnsafeMutableBytes { bytes in
                inputStream.read(bytes, maxLength: chunkSize)
            }
            
            switch bytesRead {
            case -1:
                onResult(.error(inputStream.streamError!))
                inputStream.close()
            case 0:
                onResult(.eof)
                inputStream.close()
            case 1...:
                onResult(.chunk(data.prefix(bytesRead)))
            default:
                fatalError()
            }
        case .errorOccurred:
            onResult(.error(inputStream.streamError!))
            inputStream.close()
        case .endEncountered:
            onResult(.eof)
            inputStream.close()
        default:
            fatalError()
        }
    }
}

