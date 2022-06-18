import XCTest
import class Foundation.Bundle
@testable import GitTwo

final class GitTwoTests: XCTestCase {
    func testVersion() throws {
        TestGit.run()
    }

    func test_repository_at() throws {
        let fileManager = FileManager.default
        let homeURL = fileManager.urls(for: .userDirectory, in: .allDomainsMask).first
        guard let url = homeURL?.appendingPathComponent("work").appendingPathComponent(".password-store") else { return }
        Repository.start()
        let result = Repository.at(url)

        switch result {
        case .success(let repository):
            print(repository.status(options: [.includeUntracked]))
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
