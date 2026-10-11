import Testing
@testable import TidyUp

// MARK: - Contact Scan Tests

@Suite("ContactScanService")
struct ContactScanServiceTests {

    @Test("Phone normalization strips to last 10 digits")
    func phoneNormalization() async throws {
        #expect(ContactScanService.normalize(phone: "+1 (800) 555-1234") == "8005551234")
        #expect(ContactScanService.normalize(phone: "555-1234")           == "5551234")
        #expect(ContactScanService.normalize(phone: "+44 20 7946 0958")   == "2079460958")
        #expect(ContactScanService.normalize(phone: "")                   == "")
    }

    @Test("Jaro-Winkler similarity: identical names score 1.0")
    func nameSimilarityIdentical() async {
        let score = ContactScanService.jaroWinkler("john doe", "john doe")
        #expect(score == 1.0)

        let diffScore = ContactScanService.jaroWinkler("john", "alex")
        #expect(diffScore < 0.5)
    }
}

// MARK: - Storage Service Tests

@Suite("StorageService")
struct StorageServiceTests {

    @Test("fetchCapacity returns positive total")
    func capacityIsPositive() async throws {
        let service = StorageService()
        let (used, total) = try await service.fetchCapacity()
        #expect(total > 0)
        #expect(used >= 0)
        #expect(used <= total)
    }
}
