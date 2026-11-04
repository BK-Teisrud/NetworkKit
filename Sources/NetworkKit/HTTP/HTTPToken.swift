/// Shared ASCII token validation for method and field names.
internal enum HTTPToken {
    static func isValid(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            switch byte {
            case 48...57, 65...90, 97...122,
                 33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126:
                true
            default:
                false
            }
        }
    }
}
