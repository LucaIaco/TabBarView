//
//  TabBarView.Utils.swift
//  TabBarView
//
//  Created by Luca Iaconis on 04.12.23.
//

import SwiftUI
import Combine

/// This protocol defines a set of functions which describe the `TabBarView.Item.view` view,
/// and can be implemented by a `SwiftUI` view or any `UIViewController` based object
protocol TabBarViewItemProtocol {
    
    /// The **unique** tab bar item title which is associated to this view once shown in the `TabBarView`
    var tabViewItemTitle:String { get }
    
    /// The optinal tab bar item icon which is associated to this view once shown in the `TabBarView`
    var tabViewItemIcon:UIImage? { get }
}

extension TabBarViewItemProtocol {
    
    /// Updates the tab bar item badge value for this view, shown in the responding `TabBarView`
    /// - Parameter badgeValue: the new tab bar item badge value, or `nil` to hide the badge value
    func updateTabViewBadge(_ badgeValue:String?) {
        TabBarView.BadgeEmitter.shared.updateBadge(for: self.tabViewItemTitle, badgeValue)
    }
}

//MARK: - TabBarView extension
extension TabBarView {
    
    //MARK: TabBarView.UIVCWrapperView

    /// Base generic View representable which allows to display a `UIViewController` based object
    struct UIVCWrapperView<T:UIViewController>: UIViewControllerRepresentable {
        
        typealias VCType = T
        
        final class Coordinator {
            var parentObserver: NSKeyValueObservation?
        }
        
        let blockMake: (_ context:Context) -> VCType
        
        let handleNavigationItem: Bool
        
        /// Initializes the view controller wrapper view
        /// - Parameters:
        ///   - handleNavigationItem: if `true`, the view controller.parent will get sync his `navigationItem.title` and `navigationItem.rightBarButtonItems` to the view controller returned by `blockMake` closure. This is helpful when the view controller gets pushed from a SwiftUI view
        ///   - blockMake: the closure which injects the actual View controller to display
        init(handleNavigationItem:Bool, blockMake: @escaping (_: Context) -> VCType) {
            self.handleNavigationItem = handleNavigationItem
            self.blockMake = blockMake
        }
        
        func makeUIViewController(context: Context) -> VCType {
            let resultVC = blockMake(context)
            
            if handleNavigationItem {
                // this will assign the navigation item title and right bar button items from the view controller
                // to the intermediate parent view controller which is placed between the `resultVC` and the
                // parent SwiftUI view which will contain this view, in case this gets pushed from NavigationView/Stack
                context.coordinator.parentObserver = resultVC.observe(\.parent, changeHandler: { vc, _ in
                    vc.parent?.navigationItem.title = vc.navigationItem.title
                    vc.parent?.navigationItem.rightBarButtonItems = vc.navigationItem.rightBarButtonItems
                })
            }
            return resultVC
        }
        
        func updateUIViewController(_ vc: VCType, context: Context) { }
        
        func makeCoordinator() -> Self.Coordinator { .init() }
    }
    
    //MARK: - TabBarView.DatasetsHolder
    
    /// This class holds the dataset for the items shown directly in the tab bar controller and those under More
    /// It's observable in order to be kept in memory as a StateObject across the view lifecycle of the TabBarView
    /// but it does not publishes the dataset to the view, as we manually handle them
    final class DatasetsHolder:ObservableObject {
        
        //MARK: Properties
        
        /// List of processed view controllers to be directly shown in the tab bar controller
        var plainVCs:[UIViewController] = []
        
        /// List of items to be processed and shown under the "More" view
        var moreItems:[TabBarView.Item] = [] {
            didSet {
                if oldValue != moreItems { self.moreItemsSubject.send(moreItems) }
            }
        }
     
        /// The publisher at which `MoreView` subscribes in order to intercept the change of `moreItems`
        let moreItemsPublisher: AnyPublisher<[TabBarView.Item], Never>
        private let moreItemsSubject:PassthroughSubject<[TabBarView.Item], Never>
        
        //MARK: Initializer
        
        init() {
            self.moreItemsSubject = PassthroughSubject<[TabBarView.Item], Never>()
            self.moreItemsPublisher = self.moreItemsSubject.eraseToAnyPublisher()
        }
        
        //MARK: Public
        
        /// Resets the internal state of the object, clearing any retained view controller or `TabBarView.Item` reference
        func reset() {
            self.plainVCs.removeAll()
            self.moreItems.removeAll()
        }
    }
    
    //MARK: - TabBarView.BadgeEmitter
    
    /// Component that handles the tab bar item badgeValue of the `UITabBarController` within the `TabBarView`
    final class BadgeEmitter {
        
        //MARK: Properties
        
        /// Shared instance communicating to the various `TabBarView` instances
        static let shared = BadgeEmitter()
        
        /// List of tab bar controller which are currently tracked
        private var tabControllerRefs:[TabBarView.BadgeEmitter.WeakRef<UITabBarController>] = []
        
        //MARK: Public
        
        /// Returns the badge value expected for the tab item with the given title, in the given tab bar controller
        /// - Parameters:
        ///   - tabItemTitle:
        ///   - inTabVC: the `UITabBarController` reference to look into
        /// - Returns: the badge value string
        func badge(for tabItemTitle:String, inTabVC:UITabBarController) -> String? {
            guard let tabControllerRef = tabControllerRefs.first(where: { $0.item == inTabVC }) else { return nil }
            return tabControllerRef.titleToBadge[tabItemTitle]
        }
        
        /// Updates the tab bar item badge value for the tab bar item with the given title, in all the tracked `TabBarView` views
        ///
        /// - Parameters:
        ///   - tabItemTitle: the tab bar item title reference
        ///   - badgeValue: the new tab bar item badge value
        func updateBadge(for tabItemTitle:String, _ badgeValue:String?) {
            self.purgeWeakRefs()
            for tabControllerRef in tabControllerRefs {
                
                guard let tabBarController = tabControllerRef.item else { continue }
                
                // apply the badge to the tab bar item if found
                if let tabBarItem = tabBarController.tabBar.items?.first(where: { $0.title == tabItemTitle }) {
                    tabBarItem.badgeValue = badgeValue
                }
                
                // keep the reference tabItemTitle->badgeValue
                if badgeValue == nil {
                    tabControllerRef.titleToBadge.removeValue(forKey: tabItemTitle)
                } else {
                    tabControllerRef.titleToBadge[tabItemTitle] = badgeValue
                }
            }
        }
        
        /// This method clean up the mapping of the tab bar item title->badgeValue based on the given `TabBarView.Item` dataset, for the addressed tab bar controller, in order to avoid legacy badge values from old item on eventual new ones with the same title
        /// - Parameters:
        ///   - items: the reference `TabBarView.Item` dataset
        ///   - inTabVC: the `UITabBarController` reference to look into
        func purgeDirtyBadges(basedOn items:[TabBarView.Item], inTabVC:UITabBarController) {
            guard let tabControllerRef = tabControllerRefs.first(where: { $0.item == inTabVC }) else { return }
            var newTitleToBadge:[String:String] = [:]
            for item in items {
                if let badgeValue = tabControllerRef.titleToBadge[item.title] {
                    newTitleToBadge[item.title] = badgeValue
                }
            }
            tabControllerRef.titleToBadge = newTitleToBadge
        }
        
        /// Tracks the given tab bar controller, if needed
        /// - Parameter tabBarController: the tab bar controller instance to track
        func trackTabBarController(_ tabBarController:UITabBarController) {
            self.purgeWeakRefs()
            guard !self.tabControllerRefs.contains(where: { $0.item == tabBarController }) else { return }
            self.tabControllerRefs.append(.init(item: tabBarController))
        }
        
        //MARK: Private
        
        /// Removes all the references to the released objects
        private func purgeWeakRefs() {
            self.tabControllerRefs.removeAll(where: { $0.item == nil })
        }
        
        //MARK: TabBarView.BadgeEmitter.WeakRef
        
        private final class WeakRef<T:AnyObject> {
            
            //MARK: Properties
            /// Weak reference to the item to refer to
            private(set) weak var item:T?
            
            /// Mapping of tab bar item title and tab bar badge value
            var titleToBadge:[String:String] = [:]
            
            //MARK: Initializer
            
            /// Initializes the object
            /// - Parameter item: the reference to weakly refer to
            init(item: T) { self.item = item }
        }
    }

}

//MARK: - View extension
extension View {
    
    /// Convenience getter which retuens this view, wrapped in a `NavigaitonView` or `NavigationStack` (the latter, if iOS 16+)
    @ViewBuilder var wrappedInNavigation: some View {
        Group {
            if #available(iOS 16, *) {
                NavigationStack { self }
            } else {
                NavigationView(content: { self }).navigationViewStyle(.stack)
            }
        }
    }
}
