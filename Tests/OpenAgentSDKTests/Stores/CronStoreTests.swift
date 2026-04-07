import XCTest
@testable import OpenAgentSDK

// MARK: - CronStore Tests

/// ATDD RED PHASE: Tests for Story 5.3 -- CronStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `CronJob` struct is defined with id, name, schedule, command, enabled, createdAt, lastRunAt, nextRunAt fields
///   - `CronStoreError` enum is defined with cronJobNotFound(id) case
///   - `CronStore` actor is defined with create, delete, get, list, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class CronStoreTests: XCTestCase {

    // MARK: - AC1: CronStore Actor -- create

    /// AC1 [P0]: Creating a cron job returns a CronJob with correct field values.
    func testCreate_returnsJobWithCorrectFields() async throws {
        // Given: a fresh CronStore
        let store = CronStore()

        // When: creating a cron job
        let job = await store.create(name: "Daily Report", schedule: "0 9 * * *", command: "generate-report")

        // Then: the returned job has the expected field values
        XCTAssertFalse(job.id.isEmpty)
        XCTAssertEqual(job.name, "Daily Report")
        XCTAssertEqual(job.schedule, "0 9 * * *")
        XCTAssertEqual(job.command, "generate-report")
        XCTAssertTrue(job.enabled)
        XCTAssertFalse(job.createdAt.isEmpty)
        XCTAssertNil(job.lastRunAt)
        XCTAssertNil(job.nextRunAt)
    }

    /// AC1 [P0]: Creating cron jobs auto-generates sequential IDs (cron_1, cron_2, ...).
    func testCreate_autoGeneratesSequentialIds() async throws {
        // Given: a fresh CronStore
        let store = CronStore()

        // When: creating multiple cron jobs
        let job1 = await store.create(name: "first", schedule: "*/5 * * * *", command: "cmd1")
        let job2 = await store.create(name: "second", schedule: "0 * * * *", command: "cmd2")
        let job3 = await store.create(name: "third", schedule: "0 0 * * *", command: "cmd3")

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(job1.id, "cron_1")
        XCTAssertEqual(job2.id, "cron_2")
        XCTAssertEqual(job3.id, "cron_3")
    }

    /// AC1 [P0]: Default enabled value for a new cron job is true.
    func testCreate_defaultEnabledIsTrue() async throws {
        // Given: a fresh CronStore
        let store = CronStore()

        // When: creating a cron job
        let job = await store.create(name: "test", schedule: "*/5 * * * *", command: "cmd")

        // Then: enabled is true by default
        XCTAssertTrue(job.enabled)
    }

    /// AC1 [P0]: Creating a cron job does not throw (pure append operation).
    func testCreate_doesNotThrow() async throws {
        // Given: a fresh CronStore
        let store = CronStore()

        // When/Then: creating a cron job does not throw
        let job = await store.create(name: "safe", schedule: "* * * * *", command: "safe-cmd")
        XCTAssertEqual(job.name, "safe")
    }

    // MARK: - AC1: CronStore Actor -- delete

    /// AC1 [P0]: Deleting an existing cron job succeeds.
    func testDelete_existingId_succeeds() async throws {
        // Given: a CronStore with a cron job
        let store = CronStore()
        let job = await store.create(name: "delete-me", schedule: "*/5 * * * *", command: "cmd")

        // When: deleting the job
        let result = try await store.delete(id: job.id)

        // Then: returns true and job is removed
        XCTAssertTrue(result)
        let found = await store.get(id: job.id)
        XCTAssertNil(found)
    }

    /// AC1 [P0]: Deleting a non-existent cron job throws cronJobNotFound.
    func testDelete_nonexistentId_throwsCronJobNotFound() async {
        // Given: a CronStore
        let store = CronStore()

        // When/Then: deleting a non-existent job throws cronJobNotFound
        do {
            _ = try await store.delete(id: "cron_999")
            XCTFail("Should have thrown cronJobNotFound error")
        } catch let error as CronStoreError {
            if case .cronJobNotFound(let id) = error {
                XCTAssertEqual(id, "cron_999")
            } else {
                XCTFail("Expected cronJobNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC11: CronStore Actor -- get

    /// AC11 [P0]: Getting an existing cron job by ID returns the job.
    func testGet_existingId_returnsJob() async throws {
        // Given: a CronStore with a cron job
        let store = CronStore()
        let created = await store.create(name: "find-me", schedule: "0 * * * *", command: "hourly")

        // When: getting the job by ID
        let found = await store.get(id: created.id)

        // Then: the job is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.name, "find-me")
        XCTAssertEqual(found?.schedule, "0 * * * *")
        XCTAssertEqual(found?.command, "hourly")
    }

    /// AC11 [P0]: Getting a non-existent cron job by ID returns nil.
    func testGet_nonexistentId_returnsNil() async {
        // Given: a CronStore
        let store = CronStore()

        // When: getting a job that does not exist
        let found = await store.get(id: "cron_999")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC11: CronStore Actor -- list

    /// AC11 [P1]: Listing cron jobs returns all created jobs.
    func testList_returnsAllJobs() async throws {
        // Given: a CronStore with 3 cron jobs
        let store = CronStore()

        _ = await store.create(name: "job-a", schedule: "*/5 * * * *", command: "cmd-a")
        _ = await store.create(name: "job-b", schedule: "0 * * * *", command: "cmd-b")
        _ = await store.create(name: "job-c", schedule: "0 0 * * *", command: "cmd-c")

        // When: listing all jobs
        let jobs = await store.list()

        // Then: all 3 jobs are returned
        XCTAssertEqual(jobs.count, 3)
    }

    /// AC11 [P1]: Listing from an empty store returns an empty array.
    func testList_emptyStore_returnsEmpty() async {
        // Given: a fresh empty CronStore
        let store = CronStore()

        // When: listing jobs
        let jobs = await store.list()

        // Then: result is empty
        XCTAssertTrue(jobs.isEmpty)
    }

    // MARK: - AC11: CronStore Actor -- clear

    /// AC11 [P1]: Clearing the store resets all jobs and the counter.
    func testClear_resetsStore() async throws {
        // Given: a CronStore with jobs
        let store = CronStore()

        _ = await store.create(name: "first", schedule: "*/5 * * * *", command: "cmd1")
        _ = await store.create(name: "second", schedule: "0 * * * *", command: "cmd2")

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let jobs = await store.list()
        XCTAssertTrue(jobs.isEmpty)

        // Counter reset means next job gets cron_1 again
        let newJob = await store.create(name: "after-clear", schedule: "* * * * *", command: "cmd")
        XCTAssertEqual(newJob.id, "cron_1")
    }

    // MARK: - AC1: CronStore Actor -- Thread Safety

    /// AC1 [P0]: Concurrent access to CronStore does not crash (actor isolation).
    func testCronStore_concurrentAccess() async throws {
        // Given: a CronStore
        let store = CronStore()

        // When: creating cron jobs concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    _ = await store.create(name: "concurrent-\(i)", schedule: "*/\(i) * * * *", command: "cmd-\(i)")
                }
            }
        }

        // Then: all 20 jobs were created without crash
        let jobs = await store.list()
        XCTAssertEqual(jobs.count, 20)
    }

    // MARK: - Types: CronJob

    /// AC1 [P0]: CronJob is Equatable.
    func testCronJob_equality() {
        let job1 = CronJob(
            id: "cron_1",
            name: "test",
            schedule: "*/5 * * * *",
            command: "cmd",
            enabled: true,
            createdAt: "2025-01-01T00:00:00Z"
        )
        let job2 = CronJob(
            id: "cron_1",
            name: "test",
            schedule: "*/5 * * * *",
            command: "cmd",
            enabled: true,
            createdAt: "2025-01-01T00:00:00Z"
        )
        XCTAssertEqual(job1, job2)
    }

    /// AC1 [P0]: CronJob is Codable (round-trip encode/decode).
    func testCronJob_codable() throws {
        let job = CronJob(
            id: "cron_1",
            name: "test job",
            schedule: "0 9 * * *",
            command: "generate-report",
            enabled: true,
            createdAt: "2025-01-01T00:00:00Z",
            lastRunAt: "2025-01-01T09:00:00Z",
            nextRunAt: "2025-01-02T09:00:00Z"
        )
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(CronJob.self, from: data)
        XCTAssertEqual(decoded, job)
    }

    /// AC1 [P0]: CronJob with nil optional fields is Codable (round-trip).
    func testCronJob_codable_withNilOptionals() throws {
        let job = CronJob(
            id: "cron_2",
            name: "minimal",
            schedule: "* * * * *",
            command: "tick",
            enabled: true,
            createdAt: "2025-01-01T00:00:00Z"
        )
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(CronJob.self, from: data)
        XCTAssertEqual(decoded, job)
        XCTAssertNil(decoded.lastRunAt)
        XCTAssertNil(decoded.nextRunAt)
    }

    // MARK: - Types: CronStoreError

    /// AC1 [P0]: CronStoreError is Equatable.
    func testCronStoreError_equality() {
        let error1 = CronStoreError.cronJobNotFound(id: "cron_1")
        let error2 = CronStoreError.cronJobNotFound(id: "cron_1")
        let error3 = CronStoreError.cronJobNotFound(id: "cron_2")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    /// AC1 [P0]: CronStoreError.cronJobNotFound has correct error description.
    func testCronStoreError_cronJobNotFound_description() {
        let error = CronStoreError.cronJobNotFound(id: "cron_42")
        XCTAssertTrue(error.localizedDescription.contains("cron_42"))
    }
}
