import SwiftUI

/// Utility methods to inspect the UIKit view hierarchy.
public enum Introspect {
    
    /// Finds a subview of the specified type.
    /// This method will recursively look for this view.
    /// Returns nil if it can't find a view of the specified type.
    public static func findChild<AnyViewType: UIView>(
        ofType type: AnyViewType.Type,
        in root: UIView
    ) -> AnyViewType? {
        for subview in root.subviews {
            if let typed = subview as? AnyViewType {
                return typed
            } else if let typed = findChild(ofType: type, in: subview) {
                return typed
            }
        }
        return nil
    }
    
    /// Finds a sibling that contains a view of the specified type.
    /// This method inspects siblings recursively.
    /// Returns nil if no sibling contains the specified type.
    public static func firstSibling<AnyViewType: UIView>(
        containing type: AnyViewType.Type,
        from entry: UIView
    ) -> AnyViewType? {
        
        guard let superview = entry.superview,
            let entryIndex = superview.subviews.firstIndex(of: entry)
        else {
            return nil
        }
        
        for subview in superview.subviews[entryIndex..<superview.subviews.endIndex] {
            if let typed = findChild(ofType: type, in: subview) {
                return typed
            }
        }
        
        return nil
    }
    
    /// Finds an ancestor of the specified type.
    /// If it reaches the top of the view without finding the specified view type, it returns nil.
    public static func findAncestor<AnyViewType: UIView>(ofType type: AnyViewType.Type, from entry: UIView) -> AnyViewType? {
        var superview = entry.superview
        while let s = superview {
            if let typed = s as? AnyViewType {
                return typed
            }
            superview = s.superview
        }
        return nil
    }
    
    /// Finds the hosting view of a specific subview.
    /// Hosting views generally contain subviews for one specific SwiftUI element.
    /// For instance, if there are multiple text fields in a VStack, the hosting view will contain those text fields (and their host views, see below).
    /// Returns nil if it couldn't find a hosting view. This should never happen when called with an IntrospectionView.
    public static func findHostingView(from entry: UIView) -> UIView? {
        var superview = entry.superview
        while let s = superview {
            if NSStringFromClass(type(of: s)).contains("UIHostingView") {
                return s
            }
            superview = s.superview
        }
        return nil
    }
    
    /// Finds the view host of a specific view.
    /// SwiftUI wraps each UIView within a ViewHost, then within a HostingView.
    /// Returns nil if it couldn't find a view host. This should never happen when called with an IntrospectionView.
    public static func findViewHost(from entry: UIView) -> UIView? {
        var superview = entry.superview
        while let s = superview {
            if NSStringFromClass(type(of: s)).contains("ViewHost") {
                return s
            }
            superview = s.superview
        }
        return nil
    }
}

/// Allows to safely access an array element by index
/// Usage: array[safe: 2]
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
}

/// Introspection UIView that is inserted alongside the target view.
public class IntrospectionUIView: UIView {
    
    required init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Introspection View that is injected into the UIKit hierarchy alongside the target view.
/// After `updateUIView` is called, it calls `selector` to find the target view, then `customize` when the target view is found.
public struct IntrospectionView<TargetViewType: UIView>: UIViewRepresentable {
    
    /// Method that introspects the view hierarchy to find the target view.
    /// First argument is the introspection view itself, which is contained in a view host alongside the target view.
    let selector: (IntrospectionUIView) -> TargetViewType?
    
    /// User-provided customization method for the target view.
    let customize: (TargetViewType) -> Void
    
    public init(
        selector: @escaping (UIView) -> TargetViewType?,
        customize: @escaping (TargetViewType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }
    
    public func makeUIView(context: UIViewRepresentableContext<IntrospectionView>) -> IntrospectionUIView {
        let view = IntrospectionUIView()
        view.accessibilityLabel = "IntrospectionUIView<\(TargetViewType.self)>"
        return view
    }

    /// When `updateUiView` is called after creating the Introspection view, it is not yet in the UIKit hierarchy.
    /// At this point, `introspectionView.superview.superview` is nil and we can't access the target UIKit view.
    /// To workaround this, we wait until the runloop is done inserting the introspection view in the hierarchy, then run the selector.
    /// Finding the target view fails silently if the selector yield no result. This happens when `updateUIView`
    /// gets called when the introspection view gets removed from the hierarchy.
    public func updateUIView(
        _ uiView: IntrospectionUIView,
        context: UIViewRepresentableContext<IntrospectionView>
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            guard let targetView = self.selector(uiView) else {
                return
            }
            self.customize(targetView)
        }
    }
}

/// Introspection UIViewController that is inserted alongside the target view controller.
public class IntrospectionUIViewController: UIViewController {
    required init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// This is the same logic as IntrospectionView but for view controllers. Please see details above.
public struct IntrospectionViewController<TargetViewControllerType: UIViewController>: UIViewControllerRepresentable {
    
    let selector: (IntrospectionUIViewController) -> TargetViewControllerType?
    let customize: (TargetViewControllerType) -> Void
    
    public init(
        selector: @escaping (UIViewController) -> TargetViewControllerType?,
        customize: @escaping (TargetViewControllerType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<IntrospectionViewController>
    ) -> IntrospectionUIViewController {
        let viewController = IntrospectionUIViewController()
        viewController.accessibilityLabel = "IntrospectionUIViewController<\(TargetViewControllerType.self)>"
        return viewController
    }
    
    public func updateUIViewController(
        _ uiViewController: IntrospectionUIViewController,
        context: UIViewControllerRepresentableContext<IntrospectionViewController>
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            guard let targetView = self.selector(uiViewController) else {
                return
            }
            self.customize(targetView)
        }
    }
}


extension View {
    
    public func inject<SomeView>(_ view: SomeView) -> some View where SomeView: View {
        return overlay(view.frame(width: 0, height: 0))
    }
    
    /// Finds a `UITableView` from a `SwiftUI.List`, or `SwiftUI.List` child.
    public func introspectTableView(customize: @escaping (UITableView) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in

                // Search in ancestors
                if let tableView = Introspect.findAncestor(ofType: UITableView.self, from: introspectionView) {
                    return tableView
                }

                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }

                // Search in siblings
                return Introspect.firstSibling(containing: UITableView.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UIScrollView` from a `SwiftUI.ScrollView`, or `SwiftUI.ScrollView` child.
    public func introspectScrollView(customize: @escaping (UIScrollView) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                
                // Search in ancestors
                if let tableView = Introspect.findAncestor(ofType: UIScrollView.self, from: introspectionView) {
                    return tableView
                }
                
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                
                // Search in siblings
                return Introspect.firstSibling(containing: UIScrollView.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UINavigationController` from any view embedded in a `SwiftUI.NavigationView`.
    public func introspectNavigationController(customize: @escaping (UINavigationController) -> ()) -> some View {
        return inject(IntrospectionViewController(
            selector: { $0.navigationController },
            customize: customize
        ))
    }

    /// Finds a `UITabBarController` from any SwiftUI view embedded in a `SwiftUI.TabView`
    public func introspectTabBarController(customize: @escaping (UITabBarController) -> ()) -> some View {
        return inject(IntrospectionViewController(
            selector: { $0.tabBarController },
            customize: customize
        ))
    }
    
    /// Finds a `UITextField` from a `SwiftUI.TextField`
    public func introspectTextField(customize: @escaping (UITextField) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                return Introspect.firstSibling(containing: UITextField.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UISwitch` from a `SwiftUI.Toggle`
    public func introspectSwitch(customize: @escaping (UISwitch) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                return Introspect.firstSibling(containing: UISwitch.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UISlider` from a `SwiftUI.Slider`
    public func introspectSlider(customize: @escaping (UISlider) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                return Introspect.firstSibling(containing: UISlider.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UIStepper` from a `SwiftUI.Stepper`
    public func introspectStepper(customize: @escaping (UIStepper) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                return Introspect.firstSibling(containing: UIStepper.self, from: viewHost)
            },
            customize: customize
        ))
    }
    
    /// Finds a `UIDatePicker` from a `SwiftUI.DatePicker`
    public func introspectDatePicker(customize: @escaping (UIDatePicker) -> ()) -> some View {
        return inject(IntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
                    return nil
                }
                return Introspect.firstSibling(containing: UIDatePicker.self, from: viewHost)
            },
            customize: customize
        ))
    }
}
