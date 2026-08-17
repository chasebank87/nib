public enum ExternalChangeAction: Equatable, Sendable {
    case ignore
    case reload
    case prompt
}

public enum ExternalChangePolicy {
    /// Clean documents reload from disk. Dirty documents prompt so we never
    /// discard unsaved edits. Own writes are ignored by the document before
    /// this policy runs.
    public static func action(isDirty: Bool) -> ExternalChangeAction {
        isDirty ? .prompt : .reload
    }
}
