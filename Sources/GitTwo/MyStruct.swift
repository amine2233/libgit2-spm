import Clibgit2
import Foundation

struct TestGit {
    static func run() {
        var majorPointer: Int32 = 0
        var minorPointer: Int32 = 0
        var revPointer: Int32 = 0
        let result = git_libgit2_version(&majorPointer, &minorPointer, &revPointer)

        guard result == 0 else { fatalError("Unexpected libgit2 error: \(result)") }

        print(majorPointer)
        print(minorPointer)
        print(revPointer)
    }
}

public let libGit2ErrorDomain = "org.libgit2.libgit2"

internal extension NSError {
    /// Returns an NSError with an error domain and message for libgit2 errors.
    ///
    /// :param: errorCode An error code returned by a libgit2 function.
    /// :param: libGit2PointOfFailure The name of the libgit2 function that produced the
    ///         error code.
    /// :returns: An NSError with a libgit2 error domain, code, and message.
    convenience init(gitError errorCode: Int32, pointOfFailure: String? = nil) {
        let code = Int(errorCode)
        var userInfo: [String: String] = [:]

        if let message = errorMessage(errorCode) {
            userInfo[NSLocalizedDescriptionKey] = message
        } else {
            userInfo[NSLocalizedDescriptionKey] = "Unknown libgit2 error."
        }

        if let pointOfFailure = pointOfFailure {
            userInfo[NSLocalizedFailureReasonErrorKey] = "\(pointOfFailure) failed."
        }

        self.init(domain: libGit2ErrorDomain, code: code, userInfo: userInfo)
    }
}

/// Returns the libgit2 error message for the given error code.
///
/// The error message represents the last error message generated by
/// libgit2 in the current thread.
///
/// :param: errorCode An error code returned by a libgit2 function.
/// :returns: If the error message exists either in libgit2's thread-specific registry,
///           or errno has been set by the system, this function returns the
///           corresponding string representation of that error. Otherwise, it returns
///           nil.
private func errorMessage(_ errorCode: Int32) -> String? {
    let last = giterr_last()
    if let lastErrorPointer = last {
        return String(validatingUTF8: lastErrorPointer.pointee.message)
    } else if UInt32(errorCode) == GIT_ERROR_OS.rawValue {
        return String(validatingUTF8: strerror(errno))
    } else {
        return nil
    }
}

public class Repository {
    public class func start() {
        git_libgit2_init()
    }
    /// Load the repository at the given URL.
    ///
    /// URL - The URL of the repository.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public class func at(_ url: URL) -> Result<Repository, NSError> {
        var pointer: OpaquePointer? = nil
        // let cURL = UnsafePointer(Array(url.path.utf8CString)) ou ca
        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_open(&pointer, $0)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_open"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    // MARK: - Initializers
    /// Create an instance with a libgit2 `git_repository` object.
    ///
    /// The Repository assumes ownership of the `git_repository` object.
    public init(_ pointer: OpaquePointer) {
        self.pointer = pointer

        let path = git_repository_workdir(pointer)
        self.directoryURL = path.map({ URL(fileURLWithPath: String(validatingUTF8: $0)!, isDirectory: true) })
    }

    deinit {
        git_repository_free(pointer)
    }

    // MARK: - Properties
    /// The underlying libgit2 `git_repository` object.
    public let pointer: OpaquePointer

    /// The URL of the repository's working directory, or `nil` if the
    /// repository is bare.
    public let directoryURL: URL?

    public func status(options: StatusOptions = [.includeUntracked]) -> Result<[StatusEntry], NSError> {
            var returnArray = [StatusEntry]()

            // Do this because GIT_STATUS_OPTIONS_INIT is unavailable in swift
            let pointer = UnsafeMutablePointer<git_status_options>.allocate(capacity: 1)
            let optionsResult = git_status_init_options(pointer, UInt32(GIT_STATUS_OPTIONS_VERSION))
            guard optionsResult == GIT_OK.rawValue else {
                return .failure(NSError(gitError: optionsResult, pointOfFailure: "git_status_init_options"))
            }
            var listOptions = pointer.move()
            listOptions.flags = options.rawValue
            pointer.deallocate()

            var unsafeStatus: OpaquePointer? = nil
            defer { git_status_list_free(unsafeStatus) }
            let statusResult = git_status_list_new(&unsafeStatus, self.pointer, &listOptions)
            guard statusResult == GIT_OK.rawValue, let unwrapStatusResult = unsafeStatus else {
                return .failure(NSError(gitError: statusResult, pointOfFailure: "git_status_list_new"))
            }

            let count = git_status_list_entrycount(unwrapStatusResult)

            for i in 0..<count {
                let s = git_status_byindex(unwrapStatusResult, i)
                if s?.pointee.status.rawValue == GIT_STATUS_CURRENT.rawValue {
                    continue
                }

                let statusEntry = StatusEntry(from: s!.pointee)
                returnArray.append(statusEntry)
            }

            return .success(returnArray)
        }
}

public struct StatusOptions: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let includeUntracked = StatusOptions(
        rawValue: GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
    )
    public static let includeIgnored = StatusOptions(
        rawValue: GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue
    )
    public static let includeUnmodified = StatusOptions(
        rawValue: GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue
    )
    public static let excludeSubmodules = StatusOptions(
        rawValue: GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue
    )
    public static let recurseUntrackedDirs = StatusOptions(
        rawValue: GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
    )
    public static let disablePathSpecMatch = StatusOptions(
        rawValue: GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue
    )
    public static let recurseIgnoredDirs = StatusOptions(
        rawValue: GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue
    )
    public static let renamesHeadToIndex = StatusOptions(
        rawValue: GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
    )
    public static let renamesIndexToWorkDir = StatusOptions(
        rawValue: GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue
    )
    public static let sortCasesSensitively = StatusOptions(
        rawValue: GIT_STATUS_OPT_SORT_CASE_SENSITIVELY.rawValue
    )
    public static let sortCasesInSensitively = StatusOptions(
        rawValue: GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY.rawValue
    )
    public static let renamesFromRewrites = StatusOptions(
        rawValue: GIT_STATUS_OPT_RENAMES_FROM_REWRITES.rawValue
    )
    public static let noRefresh = StatusOptions(
        rawValue: GIT_STATUS_OPT_NO_REFRESH.rawValue
    )
    public static let updateIndex = StatusOptions(
        rawValue: GIT_STATUS_OPT_UPDATE_INDEX.rawValue
    )
    public static let includeUnreadable = StatusOptions(
        rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE.rawValue
    )
    public static let includeUnreadableAsUntracked = StatusOptions(
        rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED.rawValue
    )
}

public struct StatusEntry {
    public var status: Diff.Status
    public var headToIndex: Diff.Delta?
    public var indexToWorkDir: Diff.Delta?

    public init(from statusEntry: git_status_entry) {
        self.status = Diff.Status(rawValue: statusEntry.status.rawValue)

        if let htoi = statusEntry.head_to_index {
            self.headToIndex = Diff.Delta(htoi.pointee)
        }

        if let itow = statusEntry.index_to_workdir {
            self.indexToWorkDir = Diff.Delta(itow.pointee)
        }
    }
}

public struct Diff {

    /// The set of deltas.
    public var deltas = [Delta]()

    public struct Delta {
        public static let type = GIT_OBJECT_REF_DELTA

        public var status: Status
        public var flags: Flags
        public var oldFile: File?
        public var newFile: File?

        public init(_ delta: git_diff_delta) {
            self.status = Status(rawValue: UInt32(git_diff_status_char(delta.status)))
            self.flags = Flags(rawValue: delta.flags)
            self.oldFile = File(delta.old_file)
            self.newFile = File(delta.new_file)
        }
    }

    public struct File {
        public var oid: OID
        public var path: String
        public var size: UInt64
        public var flags: Flags

        public init(_ diffFile: git_diff_file) {
            self.oid = OID(diffFile.id)
            let path = diffFile.path
            self.path = path.map(String.init(cString:))!
            self.size = diffFile.size
            self.flags = Flags(rawValue: diffFile.flags)
        }
    }

    public struct Status: OptionSet {
        // This appears to be necessary due to bug in Swift
        // https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        public let rawValue: UInt32

        public static let current                = Status(rawValue: GIT_STATUS_CURRENT.rawValue)
        public static let indexNew               = Status(rawValue: GIT_STATUS_INDEX_NEW.rawValue)
        public static let indexModified          = Status(rawValue: GIT_STATUS_INDEX_MODIFIED.rawValue)
        public static let indexDeleted           = Status(rawValue: GIT_STATUS_INDEX_DELETED.rawValue)
        public static let indexRenamed           = Status(rawValue: GIT_STATUS_INDEX_RENAMED.rawValue)
        public static let indexTypeChange        = Status(rawValue: GIT_STATUS_INDEX_TYPECHANGE.rawValue)
        public static let workTreeNew            = Status(rawValue: GIT_STATUS_WT_NEW.rawValue)
        public static let workTreeModified       = Status(rawValue: GIT_STATUS_WT_MODIFIED.rawValue)
        public static let workTreeDeleted        = Status(rawValue: GIT_STATUS_WT_DELETED.rawValue)
        public static let workTreeTypeChange     = Status(rawValue: GIT_STATUS_WT_TYPECHANGE.rawValue)
        public static let workTreeRenamed        = Status(rawValue: GIT_STATUS_WT_RENAMED.rawValue)
        public static let workTreeUnreadable     = Status(rawValue: GIT_STATUS_WT_UNREADABLE.rawValue)
        public static let ignored                = Status(rawValue: GIT_STATUS_IGNORED.rawValue)
        public static let conflicted             = Status(rawValue: GIT_STATUS_CONFLICTED.rawValue)
    }

    public struct Flags: OptionSet {
        // This appears to be necessary due to bug in Swift
        // https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        public let rawValue: UInt32

        public static let binary     = Flags([])
        public static let notBinary  = Flags(rawValue: 1 << 0)
        public static let validId    = Flags(rawValue: 1 << 1)
        public static let exists     = Flags(rawValue: 1 << 2)
    }

    /// Create an instance with a libgit2 `git_diff`.
    public init(_ pointer: OpaquePointer) {
        for i in 0..<git_diff_num_deltas(pointer) {
            if let delta = git_diff_get_delta(pointer, i) {
                deltas.append(Diff.Delta(delta.pointee))
            }
        }
    }
}

/// An identifier for a Git object.
public struct OID {

    // MARK: - Initializers
    /// Create an instance from a hex formatted string.
    ///
    /// string - A 40-byte hex formatted string.
    public init?(string: String) {
        // libgit2 doesn't enforce a maximum length
        if string.lengthOfBytes(using: String.Encoding.ascii) > 40 {
            return nil
        }

        let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
        let result = git_oid_fromstr(pointer, string)

        if result < GIT_OK.rawValue {
            pointer.deallocate()
            return nil
        }

        oid = pointer.pointee
        pointer.deallocate()
    }

    /// Create an instance from a libgit2 `git_oid`.
    public init(_ oid: git_oid) {
        self.oid = oid
    }

    // MARK: - Properties
    public let oid: git_oid
}

extension OID: CustomStringConvertible {
    public var description: String {
        let length = Int(GIT_OID_RAWSZ) * 2
        let string = UnsafeMutablePointer<Int8>.allocate(capacity: length)
        var oid = self.oid
        git_oid_fmt(string, &oid)

        return String(bytesNoCopy: string, length: length, encoding: .ascii, freeWhenDone: true)!
    }
}

extension OID: Hashable {
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: oid.id) {
            hasher.combine(bytes: $0)
        }
    }

    public static func == (lhs: OID, rhs: OID) -> Bool {
        var left = lhs.oid
        var right = rhs.oid
        return git_oid_cmp(&left, &right) == 0
    }
}