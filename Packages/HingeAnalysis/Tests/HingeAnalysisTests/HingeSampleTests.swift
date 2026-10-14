import Testing
import Foundation
@testable import HingeAnalysis
import FoldKit

@Suite("HingeSample Tests")
struct HingeSampleTests {
    
    @Test("HingeSample initializes correctly")
    func testInitialization() {
        let sample = HingeSample(degrees: 90, status: .partiallyOpen, t: 1.5)
        #expect(sample.degrees == 90)
        #expect(sample.status == .partiallyOpen)
        #expect(sample.t == 1.5)
    }
    
    @Test("HingeSample is Equatable")
    func testEquatable() {
        let sample1 = HingeSample(degrees: 90, status: .partiallyOpen, t: 1.0)
        let sample2 = HingeSample(degrees: 90, status: .partiallyOpen, t: 1.0)
        let sample3 = HingeSample(degrees: 95, status: .partiallyOpen, t: 1.0)
        
        #expect(sample1 == sample2)
        #expect(sample1 != sample3)
    }
    
    @Test("HingeSample is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = HingeSample(degrees: 90, status: .partiallyOpen, t: 1.5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HingeSample.self, from: data)
        
        #expect(decoded == original)
    }
}

@Suite("HingeSampleCollection Tests")
struct HingeSampleCollectionTests {
    
    @Test("Empty collection has correct properties")
    func testEmptyCollection() {
        let collection = HingeSampleCollection()
        #expect(collection.isEmpty)
        #expect(collection.count == 0)
        #expect(collection.duration == 0)
        #expect(collection.estimatedSampleRate == 0)
        #expect(collection.minAngle == nil)
        #expect(collection.maxAngle == nil)
        #expect(collection.angleRange == nil)
    }
    
    @Test("Collection calculates duration correctly")
    func testDuration() {
        var collection = HingeSampleCollection()
        collection.append(HingeSample(degrees: 0, status: .closed, t: 0))
        collection.append(HingeSample(degrees: 90, status: .partiallyOpen, t: 1.0))
        collection.append(HingeSample(degrees: 180, status: .fullyOpen, t: 2.0))
        
        #expect(collection.duration == 2.0)
    }
    
    @Test("Collection calculates sample rate correctly")
    func testSampleRate() {
        var collection = HingeSampleCollection()
        // 31 samples over 1 second = 30 Hz
        for i in 0...30 {
            let t = Double(i) / 30.0
            let degrees = Double(i) * 6  // 0 to 180
            collection.append(HingeSample(degrees: degrees, status: .partiallyOpen, t: t))
        }
        
        #expect(collection.estimatedSampleRate == 30.0)
    }
    
    @Test("Collection tracks min/max angles")
    func testMinMaxAngles() {
        var collection = HingeSampleCollection()
        collection.append(HingeSample(degrees: 45, status: .partiallyOpen, t: 0))
        collection.append(HingeSample(degrees: 90, status: .partiallyOpen, t: 0.5))
        collection.append(HingeSample(degrees: 30, status: .partiallyOpen, t: 1.0))
        collection.append(HingeSample(degrees: 150, status: .partiallyOpen, t: 1.5))
        
        #expect(collection.minAngle == 30)
        #expect(collection.maxAngle == 150)
        #expect(collection.angleRange == 30...150)
    }
}
