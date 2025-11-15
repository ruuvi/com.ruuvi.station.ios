extension Optional where Wrapped == String {
    var unwrapped: String {
        self ?? ""
    }
}
