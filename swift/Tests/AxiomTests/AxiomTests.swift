import CryptoKit
import Foundation
import Testing
import AxiomRuntime

// Links and calls the packaged binary; signing keys exist only in memory.
@Test func packagedRuntimeVerifiesContracts() throws {
    #expect(axiom_abi_version() == 1)
    #expect(axiom_data_abi_version() == 1)
    #expect(axiom_initialize(AxiomString(ptr: nil, len: 0)) == 0)
    defer { axiom_reset_session() }
    let artifact = Data(#"{"header":{"axiom_version":"1.0","min_runtime_version":1},"ir":{"serviceName":"qualification","specVersion":"1.0","endpoints":{},"models":{},"enums":{}},"endpoints":[],"project":{"project_id":"qualification","version":"1.0.0","codec":"json","schema_hash":"qualification","variant":"default"},"observability":null,"policies":null,"validators":{},"schema_fbs":null}"#.utf8)
    let key = Curve25519.Signing.PrivateKey()
    let digest = Data(SHA256.hash(data: artifact))
    let signature = try key.signature(for: digest).base64EncodedString()
    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    let hash = digest.map { String(format: "%02x", $0) }.joined()
    func string(_ pointer: UnsafePointer<CChar>, _ value: String) -> AxiomString {
        AxiomString(ptr: value.isEmpty ? nil : UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self), len: value.utf8.count)
    }
    func load(_ namespace: String, _ bytes: Data, signature: String = "", publicKey: String = "", lock: String? = nil) -> Int32 {
        // All temporary Swift buffers remain live throughout the borrowed FFI call.
        namespace.withCString { ns in
            "http://127.0.0.1:1".withCString { url in
                signature.withCString { sig in
                    publicKey.withCString { pub in
                        bytes.withUnsafeBytes { raw in
                            let n = string(ns, namespace), u = string(url, "http://127.0.0.1:1")
                            let b = AxiomBuffer(ptr: UnsafeMutablePointer(mutating: raw.bindMemory(to: UInt8.self).baseAddress), len: raw.count)
                            let s = string(sig, signature), p = string(pub, publicKey)
                            if let lock {
                                return lock.withCString { expected in
                                    axiom_load_contract_locked(n, u, b, s, p, string(expected, lock))
                                }
                            }
                            return axiom_load_contract(n, u, b, s, p)
                        }
                    }
                }
            }
        }
    }
    #expect(load("signed", artifact, signature: signature, publicKey: publicKey) == 0)
    #expect(load("local", artifact) == -1)
    #expect(load("partial", artifact, publicKey: publicKey) == 10)
    #expect(load("bad-proof", artifact, signature: "invalid", publicKey: publicKey) == 10)
    #expect(load("tampered", artifact + Data(" ".utf8), signature: signature, publicKey: publicKey) == 10)
    #expect(load("locked", artifact, signature: signature, publicKey: publicKey, lock: hash) == 0)
    #expect(load("unsigned-locked", artifact, lock: hash) == 10)
    #expect(load("wrong-lock", artifact, signature: signature, publicKey: publicKey, lock: String(repeating: "0", count: 64)) == 10)
    #expect(load("retired", Data([65, 88, 79, 77, 1, 0, 0, 0])) == 10)
}
