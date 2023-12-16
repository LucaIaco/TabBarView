//
//  TabBarView.Item.swift
//  TabBarView
//
//  Created by Luca Iaconis on 03.12.23.
//

import SwiftUI

//MARK: - TabBarView.Item data model

extension TabBarView {
    
    /// Data model representing the single tab bar item
    struct Item: Identifiable, Hashable {
        let id = UUID()
        
        /// The view to be displayed for this tab bar item. This can be a `UIViewController` based object or a SwiftUI `any View`
        let view: any TabBarViewItemProtocol
        
        /// If `view` is a `UINaviationController`, this property references the root view controller which is/was contained into that navigation controller. This is done in order to recover it on pop back if such item would be shown under 'More', as we push the root vc directly from the SwiftUI Navigation and not from his original navigaiton controller (in order to avoid the nested navigations). By doing so, the original `UINaviationController` based object will intrinsically lose the reference to it
        private(set) weak var uiKitNavigationRootViewController: UIViewController?
        
        /// Tab bar item title
        let title:String
        /// Tab bar item icon image
        let image:UIImage?
        
        //MARK: Initializer
        
        init(view: any TabBarViewItemProtocol) {
            self.view = view
            self.title = view.tabViewItemTitle
            self.image = view.tabViewItemIcon
            self.uiKitNavigationRootViewController = (view as? UINavigationController)?.viewControllers.first
        }
        
        //MARK: Identifiable, Hashable
        
        func hash(into hasher: inout Hasher) { hasher.combine(self.id) }
        static func == (lhs: TabBarView.Item, rhs: TabBarView.Item) -> Bool { lhs.id == rhs.id }
        
        //MARK: Public
        
        /// Convenience method which returns the view controller for this item. It's itself a view conteroller if `view` was already a `UIViewController` based object, otherwise will be an `UIHostingController` wrapping the SwiftUI view
        /// - Parameter wrapSwiftUIInNavigation: Default is `true`. In case `view` is a SwiftUI view, indicates if it should be wrapped in a NavigationView/Stack before being wrapped in a `UIHostingController`
        /// - Returns: the resulting view controller, or `nil` on error
        func viewcontroller(_ wrapSwiftUIInNavigation:Bool = true) -> UIViewController? {
            var vc: UIViewController? = nil
            if let swiftUIView = self.view as? (any View) {
                if wrapSwiftUIInNavigation {
                    vc = UIHostingController(rootView: AnyView(swiftUIView).wrappedInNavigation )
                } else {
                    vc = UIHostingController(rootView: AnyView(swiftUIView))
                }
            } else if let uiV = self.view as? UIViewController { vc = uiV }
            
            // set the tab bar item title
            let viewTitle = self.title.trimmed
            if !viewTitle.isEmpty {
                vc?.tabBarItem.title = viewTitle
            }
            // set the tab bar item icon if any
            if let viewIcon = self.image {
                vc?.tabBarItem.image = viewIcon
            }
            
            return vc
        }
        
        /// Convenience method that returns the SwiftUI `any View` which is behind the `view`.
        /// If the `item.view` is a `UIViewController` based object, this will be the
        /// `UIViewControllerRepresentable` of that view controller
        /// - Parameter handleUIKitNavigation: Default is `true`. It handles the case where `view` is itself a `UINavigationController` based object, so for UIKit only. See discussion below for details
        ///
        /// If `handleUIKitNavigation` is `true` and the `view` `UINavigationController` based object, then the returned view will be a `UIViewControllerRepresentable` of the root view controller which was contained in the navigation controller, in order to avoid the double navigation bar.
        ///
        /// - Returns: the SwiftUI view
        func swiftUIView(handleUIKitNavigation:Bool = true) -> any View {
            if let swiftUIView = self.view as? (any View) {
                return swiftUIView.navigationBarHidden(false)
            } else if let uiV = self.view as? UIViewController {
                var vcToWrap = uiV
                if handleUIKitNavigation, let uiKitNavigationRootViewController {
                    vcToWrap = uiKitNavigationRootViewController
                }
                return TabBarView.UIVCWrapperView(handleNavigationItem: handleUIKitNavigation) { _ in vcToWrap }
            } else {
                return Text("Unable to load the view for item '\(self.title)'")
            }
        }
        
        /// Convenience method which returns the `item.image` represented in a SwiftUI `Image`
        /// - Returns: the SwiftUI image
        func switUIImage() -> some View {
            var image = Image(systemName: "circle")
            if let img = self.image { image = Image(uiImage: img) }
            return image.renderingMode(.template).foregroundColor(.blue)
        }
    
    }
}


//MARK: - String extension
fileprivate extension String {
    
    /// Trimmed representation of this string
    var trimmed:String { self.trimmingCharacters(in:.whitespacesAndNewlines) }
}
