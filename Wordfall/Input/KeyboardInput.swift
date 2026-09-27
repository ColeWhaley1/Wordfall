import SwiftUI
import UIKit

/// An invisible view that owns the system keyboard and reports raw key
/// presses. Using `UIKeyInput` instead of a text field means there is no text
/// to diff, no autocorrect and no cursor: each key is a game action.
final class KeyCatcherView: UIView, UIKeyInput {
    var onInsert: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onReturn: (() -> Void)?
    var wantsFocus = false {
        didSet { updateFocus() }
    }

    // UITextInputTraits
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .allCharacters
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .asciiCapable
    var keyboardAppearance: UIKeyboardAppearance = .dark
    var returnKeyType: UIReturnKeyType = .done

    override var canBecomeFirstResponder: Bool { true }

    /// Always report text so backspace is delivered even when the answer is empty.
    var hasText: Bool { true }

    func insertText(_ text: String) {
        if text == "\n" {
            onReturn?()
            return
        }
        onInsert?(text)
    }

    func deleteBackward() {
        onDelete?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateFocus()
    }

    private func updateFocus() {
        guard window != nil else { return }
        if wantsFocus, !isFirstResponder {
            becomeFirstResponder()
        } else if !wantsFocus, isFirstResponder {
            resignFirstResponder()
        }
    }
}

/// Shows the system keyboard while `isActive` is true and forwards keys.
struct KeyboardInput: UIViewRepresentable {
    @Binding var isActive: Bool
    var onInsert: (String) -> Void
    var onDelete: () -> Void

    func makeUIView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: KeyCatcherView, context: Context) {
        view.onInsert = onInsert
        view.onDelete = onDelete
        let binding = $isActive
        view.onReturn = { binding.wrappedValue = false }
        let active = isActive
        if view.wantsFocus != active {
            // Changing first responder during a SwiftUI update is not allowed.
            DispatchQueue.main.async {
                view.wantsFocus = active
            }
        }
    }
}
