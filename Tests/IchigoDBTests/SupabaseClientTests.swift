import XCTest
@testable import IchigoDB

final class SupabaseClientTests: XCTestCase {
    func testBuildsPostgrestSelectRequest() throws {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let client = SupabaseClient(config: config)
        let request = try client.request(
            path: "rest/v1/varieties",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "deleted_at", value: "is.null"),
                URLQueryItem(name: "order", value: "name.asc")
            ],
            method: "GET"
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon")
        XCTAssertTrue(request.url?.absoluteString.contains("rest/v1/varieties") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("deleted_at=is.null") == true)
    }

    func testUsesAuthAccessTokenWhenAvailable() throws {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let client = SupabaseClient(config: config, accessTokenProvider: { "user-token" })
        let request = try client.request(path: "rest/v1/varieties", method: "GET")

        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user-token")
    }

    func testFilterFactoriesMatchPostgrestSyntax() {
        XCTAssertEqual(PostgrestFilter.eq("id", "abc").value, "eq.abc")
        XCTAssertEqual(PostgrestFilter.isNull("deleted_at").value, "is.null")
        XCTAssertEqual(PostgrestFilter.in("id", ["a", "b"]).value, "in.(a,b)")
    }

    func testBuildsEscapedStorageObjectRequest() throws {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let client = SupabaseClient(config: config)
        let request = try client.storageObjectRequest(
            bucket: "variety-images",
            path: "varieties/a b/あまおう.jpg",
            method: "GET"
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.absoluteString.contains("storage/v1/object/variety-images/varieties/a%20b/") == true)
        XCTAssertTrue(request.url?.absoluteString.contains(".jpg") == true)
    }

    func testBuildsPublicStorageURL() throws {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let client = SupabaseClient(config: config)
        let url = client.publicStorageURL(bucket: "review-images", path: "reviews/a b/photo.jpg")

        XCTAssertEqual(url?.absoluteString, "https://example.supabase.co/storage/v1/object/public/review-images/reviews/a%20b/photo.jpg")
    }
}
