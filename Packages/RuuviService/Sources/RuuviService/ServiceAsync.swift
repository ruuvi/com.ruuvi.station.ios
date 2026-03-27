import Foundation
import RuuviCloud
import RuuviLocal
import RuuviPool
import RuuviRepository
import RuuviStorage

public extension RuuviServiceError {
    @inline(__always)
    static func perform<Value>(
        _ task: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await task()
        } catch let error as RuuviServiceError {
            throw error
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch let error as RuuviRepositoryError {
            throw RuuviServiceError.ruuviRepository(error)
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        } catch let error as RuuviLocalError {
            throw RuuviServiceError.ruuviLocal(error)
        } catch {
            throw RuuviServiceError.networking(error)
        }
    }
}
