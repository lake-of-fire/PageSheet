#if os(iOS)
import SwiftUI

// MARK: - AutomaticPreferenceKey

private protocol AutomaticPreferenceKey: PreferenceKey {}

extension AutomaticPreferenceKey {
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

// MARK: - PageSheet

/// Customizable sheet presentations in SwiftUI
public enum PageSheet {
    /// An object that represents a height where a sheet naturally rests.
    public typealias Detent = UISheetPresentationController.Detent
    
    // MARK: - Configuration
    
    fileprivate struct Configuration: Equatable {
        var prefersGrabberVisible: Bool = false
        var detents: [Detent] = [.large()]
        var largestUndimmedDetentIdentifier: Detent.Identifier? = nil
        var selectedDetentIdentifier: Detent.Identifier = .large
        var prefersEdgeAttachedInCompactHeight: Bool = false
        var widthFollowsPreferredContentSizeWhenEdgeAttached: Bool = false
        var prefersScrollingExpandsWhenScrolledToEdge: Bool = true
        var preferredCornerRadius: CGFloat? = nil
        
        static var `default`: Self { .init() }
    }
    
    // MARK: - ConfiguredHostingView
    
    internal struct ConfiguredHostingView<Content: View>: View {
        @State private var configuration: Configuration = .default
        @State private var selectedDetent: Detent.Identifier = .large
        
        let content: Content
        
        var body: some View {
            HostingView(configuration: $configuration, selectedDetent: $selectedDetent, content: content)
                .onChange(of: selectedDetent) { newValue in
                    self.configuration.selectedDetentIdentifier = newValue
                }
                .onPreferenceChange(Preference.SelectedDetentIdentifier.self) { newValue in
                    self.selectedDetent = newValue
                }
                .onPreferenceChange(Preference.GrabberVisible.self) { newValue in
                    self.configuration.prefersGrabberVisible = newValue
                }
                .onPreferenceChange(Preference.Detents.self) { newValue in
                    self.configuration.detents = newValue
                }
                .onPreferenceChange(Preference.LargestUndimmedDetentIdentifier.self) { newValue in
                    self.configuration.largestUndimmedDetentIdentifier = newValue
                }
                .onPreferenceChange(Preference.EdgeAttachedInCompactHeight.self) { newValue in
                    self.configuration.prefersEdgeAttachedInCompactHeight = newValue
                }
                .onPreferenceChange(Preference.WidthFollowsPreferredContentSizeWhenEdgeAttached.self) {
                    newValue in
                    self.configuration.widthFollowsPreferredContentSizeWhenEdgeAttached = newValue
                }
                .onPreferenceChange(Preference.ScrollingExpandsWhenScrolledToEdge.self) { newValue in
                    self.configuration.prefersScrollingExpandsWhenScrolledToEdge = newValue
                }
                .onPreferenceChange(Preference.CornerRadius.self) { newValue in
                    self.configuration.preferredCornerRadius = newValue
                }
                .environment(\._selectedDetentIdentifier, self.selectedDetent)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - HostingController
    
    fileprivate class HostingController<Content: View>: UIHostingController<Content>,
                                                        UISheetPresentationControllerDelegate
    {
        var configuration: Configuration = .default {
            didSet {
                if let sheet = self.sheetPresentationController {
//                    if sheet.delegate == nil {
                        sheet.delegate = self
//                    }
                    
                    let config = self.configuration
                    sheet.animateChanges {
                        sheet.prefersGrabberVisible = config.prefersGrabberVisible
                        sheet.detents = config.detents
                        sheet.largestUndimmedDetentIdentifier = config.largestUndimmedDetentIdentifier
                        sheet.prefersEdgeAttachedInCompactHeight = config.prefersEdgeAttachedInCompactHeight
                        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached =
                        config.widthFollowsPreferredContentSizeWhenEdgeAttached
                        sheet.prefersScrollingExpandsWhenScrolledToEdge =
                        config.prefersScrollingExpandsWhenScrolledToEdge
                        sheet.preferredCornerRadius = config.preferredCornerRadius
                        sheet.selectedDetentIdentifier = config.selectedDetentIdentifier
                    }
                }
            }
        }
        
        @Binding
        var selectedDetent: Detent.Identifier
        
        init(rootView: Content, selectedDetent: Binding<Detent.Identifier>) {
            self._selectedDetent = selectedDetent
            super.init(rootView: rootView)
        }
        
        @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            
            // NOTE: Fixes iOS 16 keyboard+spacer bug in sheet.
            view.endEditing(true)
            view.layoutIfNeeded()
            
            // NOTE: Fixes an issue with largestUndimmedDetentIdentifier perpetually dimming buttons.
            // self.parent?.presentingViewController?.view.tintAdjustmentMode = .normal
        }
        
        // MARK: UISheetPresentationControllerDelegate
        
        func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
            _ sheet: UISheetPresentationController
        ) {
            self.selectedDetent = sheet.selectedDetentIdentifier ?? .large
        }
    }
    
    // MARK: - HostingView
    
    fileprivate struct HostingView<Content: View>: UIViewControllerRepresentable {
        @Binding var configuration: Configuration
        @Binding var selectedDetent: Detent.Identifier
        
        @State private var selectedDetentIdentifier: Detent.Identifier = .large
        
        let content: Content
        
        func makeUIViewController(context: Context) -> HostingController<Content> {
            HostingController(
                rootView: content,
                selectedDetent: $selectedDetent
            )
        }
        
        func updateUIViewController(_ controller: HostingController<Content>, context: Context) {
            controller.rootView = content
            if controller.configuration != configuration, configuration != .default {
                controller.configuration = configuration
                
                // NOTE: Fixes safe area flickering when we throw the view up and down.
                // controller.view.invalidateIntrinsicContentSize()
                
                // NOTE: Fixes an issue with largestUndimmedDetentIdentifier perpetually dimming buttons.
                // if configuration.largestUndimmedDetentIdentifier != nil {
                //   controller.parent?.presentingViewController?.view.tintAdjustmentMode = .normal
                // } else {
                //   controller.parent?.presentingViewController?.view.tintAdjustmentMode = .automatic
                // }
            }
        }
    }
}

// MARK: - Presentation View Modifiers

extension PageSheet {
    
    internal enum Modifier {
        
        // MARK: Presentation
        
        struct BooleanPresentation<SheetContent: View>: ViewModifier {
            
            @Binding
            var isPresented: Bool
            
            let onDismiss: (() -> Void)?
            let content: () -> SheetContent
            
            func body(content: Content) -> some View {
                content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                    ConfiguredHostingView(
                        content: self.content()
                    )
                }
            }
        }
        
        // MARK: ItemPresentation
        
        struct ItemPresentation<Item: Identifiable, SheetContent: View>: ViewModifier {
            
            @Binding
            var item: Item?
            
            let onDismiss: (() -> Void)?
            let content: (Item) -> SheetContent
            
            func body(content: Content) -> some View {
                content.sheet(item: $item, onDismiss: onDismiss) { item in
                    ConfiguredHostingView(
                        content: self.content(item)
                    )
                }
            }
        }
    }
    
}

// MARK: Preference

extension PageSheet {
    /// Implementations of custom [`PreferenceKeys`](https://developer.apple.com/documentation/swiftui/preferencekey).
    public enum Preference {
        public struct GrabberVisible: AutomaticPreferenceKey {
            public static var defaultValue: Bool = Configuration.default.prefersGrabberVisible
        }
        
        public struct Detents: AutomaticPreferenceKey {
            public static var defaultValue: [PageSheet.Detent] = Configuration.default.detents
        }
        
        public struct LargestUndimmedDetentIdentifier: AutomaticPreferenceKey {
            public static var defaultValue: Detent.Identifier? = Configuration.default
                .largestUndimmedDetentIdentifier
        }
        
        public struct SelectedDetentIdentifier: AutomaticPreferenceKey {
            public static var defaultValue: Detent.Identifier = Configuration.default
                .selectedDetentIdentifier
        }
        
        public struct EdgeAttachedInCompactHeight: AutomaticPreferenceKey {
            public static var defaultValue: Bool = Configuration.default
                .prefersEdgeAttachedInCompactHeight
        }
        
        public struct WidthFollowsPreferredContentSizeWhenEdgeAttached: AutomaticPreferenceKey {
            public static var defaultValue: Bool = Configuration.default
                .widthFollowsPreferredContentSizeWhenEdgeAttached
        }
        
        public struct ScrollingExpandsWhenScrolledToEdge: AutomaticPreferenceKey {
            public static var defaultValue: Bool = Configuration.default
                .prefersScrollingExpandsWhenScrolledToEdge
        }
        
        public struct CornerRadius: AutomaticPreferenceKey {
            public static var defaultValue: CGFloat? = Configuration.default.preferredCornerRadius
        }
    }
}

// MARK: - PresentationPreference

/// Set of preferences that can be applied to a sheet presentation.
@frozen public enum SheetPreference: Hashable {
    /// Sets a Boolean value that determines whether the presenting sheet shows a grabber at the top.
    ///
    /// The default value is `false`, which means the sheet doesn't show a grabber. A *grabber* is a visual affordance that indicates that a sheet is resizable.
    /// Showing a grabber may be useful when it isn't apparent that a sheet can resize or when the sheet can't dismiss interactively.
    ///
    /// Set this value to `true` for the system to draw a grabber in the standard system-defined location.
    /// The system automatically hides the grabber at appropriate times, like when the sheet is full screen in a compact-height size class or when another sheet presents on top of it.
    ///
    case grabberVisible(Bool)
    
    /// Sets an array of heights where the presenting sheet can rest.
    ///
    /// The default value is an array that contains the value [`large()`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/detent/3801916-large).
    /// The array must contain at least one element. When you set this value, specify detents in order from smallest to largest height.
    ///
    case detents([PageSheet.Detent])
    
    /// Sets the largest detent that doesn’t dim the view underneath the presenting sheet.
    ///
    /// The default value is `nil`, which means the system adds a noninteractive dimming view underneath the sheet at all detents.
    /// Set this property to only add the dimming view at detents larger than the detent you specify.
    /// For example, set this property to [`medium`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/detent/identifier/3801920-medium) to add the dimming view at the [`large`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/detent/identifier/3801919-large) detent.
    ///
    /// Without a dimming view, the undimmed area around the sheet responds to user interaction, allowing for a nonmodal experience.
    /// You can use this behavior for sheets with interactive content underneath them.
    ///
    case largestUndimmedDetent(id: PageSheet.Detent.Identifier?)
    
    /// Sets the identifier of the most recently selected detent on the presenting sheet.
    ///
    /// This property represents the most recent detent that the user selects or that you set programmatically.
    /// The default value is `nil`, which means the sheet displays at the smallest detent you specify in [`detents`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/3801903-detents).
    /// Detents can be modified using the ``PageSheetCore/SheetPreference/detents(_:)`` sheet preference.
    ///
    case selectedDetent(id: PageSheet.Detent.Identifier)
    
    /// Sets a Boolean value that determines whether the presenting sheet attaches to the bottom edge of the screen in a compact-height size class.
    ///
    /// The default value is `false`, which means the sheet defaults to a full screen appearance at compact height.
    /// Set this value to `true` to use an alternate appearance in a compact-height size class, causing the sheet to only attach to the screen on its bottom edge.
    ///
    case edgeAttachedInCompactHeight(Bool)
    
    /// Sets a Boolean value that determines whether the presenting sheet's width matches its view's preferred content size.
    ///
    /// The default value is `false`, which means the sheet's width equals the width of its container's safe area.
    /// Set this value to `true` to use your view controller's [`preferredContentSize`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621476-preferredcontentsize) to determine the width of the sheet instead.
    ///
    /// This property doesn't have an effect when the sheet is in a compact-width and regular-height size class, or when [`prefersEdgeAttachedInCompactHeight`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/3801907-prefersscrollingexpandswhenscrol) is `false`.
    /// The scroll expansion preference can be modified using the ``PageSheetCore/SheetPreference/scrollingExpandsWhenScrolledToEdge(_:)`` sheet preference.
    ///
    case widthFollowsPreferredContentSizeWhenEdgeAttached(Bool)
    
    /// Sets a Boolean value that determines whether scrolling expands the presenting sheet to a larger detent.
    ///
    /// The default value is `true`, which means if the sheet can expand to a larger detent than [`selectedDetentIdentifier`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/3801908-selecteddetentidentifier),
    /// scrolling up in the sheet increases its detent instead of scrolling the sheet's content. After the sheet reaches its largest detent, scrolling begins.
    ///
    /// Set this value to `false` if you want to avoid letting a scroll gesture expand the sheet.
    /// For example, you can set this value on a nonmodal sheet to avoid obscuring the content underneath the sheet.
    ///
    case scrollingExpandsWhenScrolledToEdge(Bool)
    
    /// Sets the preferred corner radius on the presenting sheet.
    ///
    /// The default value is `nil`. This property only has an effect when the presenting sheet is at the front of its sheet stack.
    ///
    case cornerRadius(CGFloat?)
}

/// Applies a ``PageSheetCore/SheetPreference`` and returns a new view.
///
/// You can use this modifier directly or preferably the convenience modifier `sheetPreference(_:)`:
///
/// ```swift
/// struct SheetContentView: View {
///   var body: some View {
///     VStack {
///       Text("Hello World.")
///     }
///     .sheetPreference(.grabberVisible(true))
///     .modifier(
///       SheetPreferenceViewModifier(.cornerRadius(10))
///     )
///   }
/// }
/// ```
///
public struct SheetPreferenceViewModifier: ViewModifier {
    /// Preference to be applied.
    public let preference: SheetPreference
    
    /// Gets the current body of the caller.
    @inlinable public func body(content: Content) -> some View {
        switch preference {
        case let .cornerRadius(value):
            content.preference(key: PageSheet.Preference.CornerRadius.self, value: value)
        case let .detents(value):
            content.preference(key: PageSheet.Preference.Detents.self, value: value)
        case let .largestUndimmedDetent(value):
            content.preference(
                key: PageSheet.Preference.LargestUndimmedDetentIdentifier.self, value: value)
        case let .selectedDetent(value):
            content.preference(key: PageSheet.Preference.SelectedDetentIdentifier.self, value: value)
        case let .edgeAttachedInCompactHeight(value):
            content.preference(key: PageSheet.Preference.EdgeAttachedInCompactHeight.self, value: value)
        case let .widthFollowsPreferredContentSizeWhenEdgeAttached(value):
            content.preference(
                key: PageSheet.Preference.WidthFollowsPreferredContentSizeWhenEdgeAttached.self,
                value: value)
        case let .grabberVisible(value):
            content.preference(key: PageSheet.Preference.GrabberVisible.self, value: value)
        case let .scrollingExpandsWhenScrolledToEdge(value):
            content.preference(
                key: PageSheet.Preference.ScrollingExpandsWhenScrolledToEdge.self, value: value)
        }
    }
    
    /// A structure that defines the ``PageSheetCore/SheetPreference`` needed to produce a new view with that preference applied.
    @inlinable public init(_ preference: SheetPreference) {
        self.preference = preference
    }
}
#endif
