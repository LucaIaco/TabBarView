//
//  TabBarView.swift
//  TabBarView
//
//  Created by Luca Iaconis on 03.12.23.
//

import SwiftUI

/// The SwiftUI component which wraps the UIKit `UITabBarController` and handles his views and states
struct TabBarView: UIViewControllerRepresentable {
    
    //MARK: Properties
    
    /// Dataset of the items which are being loaded in the `TabBarView`
    @Binding var items:[TabBarView.Item]
    
    /// The currently selected `TabBarView.Item`. It can be `nil` if no tab bar item is selected or if the internal "More" tab is selected. Note: setting the wrapped value explicitly to nil will have no effect (so, the component will just sync the value back to the current selected tab item)
    @Binding var selection:TabBarView.Item?
    
    /// If `true`, all the `TabBarView.Item.view` which are SwiftUI views, will be wrapped in a `NavigationView` / `NavigaitonStack` before being wrapped in a `UIHostingController` to be plugged into the tab bar controller
    let wrapSwiftUIInNavigation:Bool
    
    /// The tab bar item title for the view "More", where the exceeding items are being displayed into
    let moreTabTitle:String
    
    /// A view to be displayed in case `items` is empty
    let fallbackContent: (() -> any View)?
    
    /// Instance of the object holding the internal datasets
    @StateObject private var datasetHolder = TabBarView.DatasetsHolder()
    
    /// Limit of items after which the More item should be displayed to the user
    /// (5 items for iPhone, 6 for iPad, after which the "More" tab item gets shown)
    private let countLimit = UIDevice.current.userInterfaceIdiom == .pad ? 6 : 5
    
    //MARK: Init
    
    /// Initializes the component
    /// - Parameters:
    ///   - items: Dataset of the items which are being loaded in the `TabBarView`
    ///   - selection: The currently selected `TabBarView.Item`. It can be `nil` if no tab bar item is selected or if the internal "More" tab is selected. Note: setting the wrapped value explicitly to nil will have no effect (so, the component will just sync the value back to the current selected tab item)
    ///   - wrapSwiftUIInNavigation: Default `true`, indicates that all the `TabBarView.Item.view` which are SwiftUI views, will be wrapped in a `NavigationView` / `NavigaitonStack` before being wrapped in a `UIHostingController` to be plugged into the tab bar controller
    ///   - moreTabTitle: The tab bar item title for the view "More", where the exceeding items are being displayed into. Default is string `More`
    ///   - fallbackContent: Default `nil`, is a view to be displayed in case `items` is empty. Put `nil` if not needed
    init(items: Binding<[TabBarView.Item]>, selection:Binding<TabBarView.Item?> = .constant(nil), wrapSwiftUIInNavigation:Bool = true, moreTabTitle:String = "More", fallbackContent: (() -> any View)? = nil) {
        self._items = items
        self._selection = selection
        self.wrapSwiftUIInNavigation = wrapSwiftUIInNavigation
        self.moreTabTitle = moreTabTitle
        self.fallbackContent = fallbackContent
    }
    
    //MARK: UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UITabBarController {
        let vc = UITabBarController()
        // Make sure the tab bar is opaque
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        vc.tabBar.scrollEdgeAppearance = tabBarAppearance
        // Track the instance in order to enable the event emitting
        TabBarView.BadgeEmitter.shared.trackTabBarController(vc)
        
        // Setup the coordinator class which be to the UITabBarController delegate
        vc.delegate = context.coordinator
        
        return vc
    }
    
    func updateUIViewController(_ vc: UITabBarController, context: Context) {
        // Prepare the datsets of view controller shown in the tab bar and, if needed, the More tab
        self.processDatasets(vc)
        // Apply the visible view controllers to the tab bar
        vc.viewControllers = self.datasetHolder.plainVCs
        // Sync the item selection
        DispatchQueue.main.async {
            self.updateTabToSelectionIfNeeded(vc)
            self.updateSelectionToTabIfNeeded(to: vc.selectedViewController)
        }
    }
    
    func makeCoordinator() -> Self.Coordinator { 
        return .init(tabBarDidSelect: { self.updateSelectionToTabIfNeeded(to: $0) })
    }
    
    //MARK: Private
    
    /// It updates the datasets of the plain and more slices
    /// - Parameter tabVC: the internal tab bar controller
    private func processDatasets(_ tabVC:UITabBarController) {
        // Get the new and existing(old) visible tab bar items view controller representation
        var newPlainVCs = limitedDataset.compactMap({ $0.viewcontroller(wrapSwiftUIInNavigation) })
        let oldPlainVCs = self.datasetHolder.plainVCs
        
        // Make sure no legacy badge are still mapped for this UITabBarController based on the newly provided items
        TabBarView.BadgeEmitter.shared.purgeDirtyBadges(basedOn: self.items, inTabVC: tabVC)
        
        // in case there's not vc in the dataset, we clear the internal data holder state and we show any provided fallback view
        guard !newPlainVCs.isEmpty else {
            self.datasetHolder.reset()
            if let fallbackViewController { self.datasetHolder.plainVCs = [fallbackViewController] }
            return
        }
        
        // More items dataset handling, including Hiding/Showing/Reusing the "More" tab item
        self.datasetHolder.moreItems = moreDataset
        if !self.datasetHolder.moreItems.isEmpty {
            newPlainVCs.append(oldPlainVCs.first(where: { $0.tabBarItem.title == self.moreTabTitle }) ?? self.moreViewController)
        }
        
        // Finalize the resulting item dataset to be rendered later in the tab bar controller
        let resultingVCs = self.updatedDataset(newDataset: newPlainVCs, oldDataset: oldPlainVCs)
        
        // Update the badge values fro all the view controllers which will be displayed in this TabBarView
        for resultingVC in resultingVCs {
            guard let tabItemTitle = resultingVC.tabBarItem.title else { continue }
            resultingVC.tabBarItem.badgeValue = TabBarView.BadgeEmitter.shared.badge(for: tabItemTitle, inTabVC: tabVC)
        }
        
        self.datasetHolder.plainVCs = resultingVCs
    }
    
    /// Returns an array of view controller, where the `newDataset` of vc will use the existing vc instances from the `oldDataset` where found
    ///
    /// This method allows us to preserve the exiting view controller instances (in order to not destroy them, or for example to not lose the internal states of those using SwiftUI)
    ///
    /// - Parameters:
    ///   - newDataset: the new dataset to be processed
    ///   - oldDataset: the existing dataset to use as reference
    /// - Returns: the resulting dataset
    private func updatedDataset(newDataset:[UIViewController], oldDataset:[UIViewController]) -> [UIViewController] {
        var resultVCs:[UIViewController] = []
        for newVC in newDataset {
            if let oldVC = oldDataset.first(where: { $0.tabBarItem.title == newVC.tabBarItem.title }) {
                resultVCs.append(oldVC)
            } else {
                resultVCs.append(newVC)
            }
        }
        return resultVCs
    }
    
    /// Updates the external `selection` binding value to the current selected tab bar item
    ///
    /// This method is the opposite of `updateTabToSelectionIfNeeded(_:)`. The value of `selection` will be `nil` if there is no selected view controller (eg empty tab bar controller) or the selected tab is "More"
    ///
    /// - Parameter selectedViewController: the `UITabBarController` selected view controller
    private func updateSelectionToTabIfNeeded(to selectedViewController:UIViewController?) {
        guard let curSelectedItemTitle = selectedViewController?.tabBarItem.title else { selection = nil; return }
        guard curSelectedItemTitle != selection?.title else { return }
        // If the selected tab is the More tab, then there's no valid selection item, and we reset it to nil
        guard curSelectedItemTitle != self.moreTabTitle else { selection = nil; return }
        selection = self.items.first(where: { $0.title == curSelectedItemTitle })
    }
    
    /// It selects the view controller within the `UITabBarController` based on the current `selection`
    ///
    /// This method is the opposite of `updateSelectionToTabIfNeeded(to:)`
    /// - Parameter tabVC: the internal tab bar controller
    private func updateTabToSelectionIfNeeded(_ tabVC:UITabBarController) {
        guard let selection else { return }
        guard tabVC.selectedViewController?.tabBarItem.title != selection.title else { return }
        guard let vcToSelect = datasetHolder.plainVCs.first(where: { $0.tabBarItem.title == selection.title }) else { return }
        tabVC.selectedViewController = vcToSelect
    }
}

//MARK: TabBarView internal convenience getters
fileprivate extension TabBarView {
    
    /// Convenience getter that returns the item dataset up the `countLimit`, so that the exceeded (More) would not be returned
    private var limitedDataset:[TabBarView.Item] {
        let resultItems = items.count > countLimit ? Array(items.prefix(countLimit - 1)) : items
        // Makes sure that if an item.view is an UINavigationController and his viewControllers.first doesn't exist or is not conforming TabBarViewItemProtocol, then will recover his root view originally acquired at the item creation (which can be emptied under the More tab). For more information see the 'uiKitNavigationRootViewController' documentation
        for resultItem in resultItems {
            if let nVC = resultItem.view as? UINavigationController,
               !(nVC.viewControllers.first is TabBarViewItemProtocol),
               let rootVC = resultItem.uiKitNavigationRootViewController {
                // if was pushed, pop it and assign it back to his original navigation controller
                rootVC.navigationController?.popToRootViewController(animated: false)
                DispatchQueue.main.async { nVC.viewControllers = [rootVC] }
            }
        }
        return resultItems
    }
    
    /// Convenience getter that returns the slice of item dataset exceeding the `countLimit`
    private var moreDataset:[TabBarView.Item] {
        return items.count > countLimit ? Array(items[(countLimit - 1)...]) : []
    }
    
    /// Convenience getter that builds and returns a new view controller instance for `fallbackContent` to be displayed if `items` is empty
    private var fallbackViewController: UIViewController? {
        guard let fallbackContent else { return nil }
        return UIHostingController(rootView: AnyView(fallbackContent()))
    }
    
    /// Convenience getter that builds and returns a new view controller instance for "More" tab bar item
    private var moreViewController: UIViewController {
        let vc = UIHostingController(rootView: MoreView(datasetHolder: self.datasetHolder, moreTabTitle: self.moreTabTitle))
        vc.tabBarItem.title = self.moreTabTitle
        vc.tabBarItem.image = UIImage(systemName: "ellipsis")
        return vc
    }
}

//MARK: - TabBarView.MoreView
fileprivate extension TabBarView {
    
    struct MoreView:View {
        
        let datasetHolder: TabBarView.DatasetsHolder
        let moreTabTitle:String
        
        @State private var items:[TabBarView.Item] = []
        
        var body: some View {
            List(items) { item in
                NavigationLink {
                    AnyView(item.swiftUIView())
                } label: {
                    Label( title: { Text(item.title) }, icon: { item.switUIImage() })
                }
            }
            .listStyle(.plain)
            .navigationTitle(self.moreTabTitle)
            .navigationBarTitleDisplayMode(.inline)
            .wrappedInNavigation
            .onReceive(datasetHolder.moreItemsPublisher.receive(on: DispatchQueue.main), perform: { newItems in items = newItems })
            .onAppear(perform: { items = datasetHolder.moreItems })
        }
    }
}

//MARK: - TabBarView.Coordinator
extension TabBarView {
    
    final class Coordinator:NSObject, UITabBarControllerDelegate {
        
        //MARK: Properties
        
        /// Closure called when user selects a different view controller in the `UITabBarController`
        let tabBarDidSelect: (UIViewController) -> ()
        
        //MARK: Initializer
        
        /// Initializes the coordinator delegate object
        /// - Parameter tabBarDidSelect: Closure called when user selects a different view controller in the `UITabBarController`
        init(tabBarDidSelect: @escaping (UIViewController) -> Void) { self.tabBarDidSelect = tabBarDidSelect }
        
        //MARK: UITabBarControllerDelegate methods
        
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            self.tabBarDidSelect(viewController)
        }
    }
}
