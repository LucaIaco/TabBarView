# TabBarView
This project provides a **SwiftUI** component as alternative to the native Apple `TabView`. It can display both `SwiftUI` and `UIViewController` based object, and provides support for handling the `NavigationView` / `NavigationStack` when the views are exceeding under More tab, for iOS 15 and iOS 16+ 

In a nutshell, this component is a `UIViewControllerRepresentable` wrapping the UIKit `UITabBarController`, and handles the logic to manage both `SwiftUI` and `UIViewController` views

- Used Xcode version: 15.1
- Tested on:
  - iOS 15.0 (iPhone and iPad)
  - iOS 17.2 (iPhone and iPad)
 
The project contains the reusable components that make the underlying mechanism to work. You can find them under the folder `Component`, which are `TabBarView.swift`, `TabBarView.Item.swift` and `TabBarView.Utils.swift`. The code is higly commented, I hope will give you a good understanding of all the showcased scenario

### Sample code

```swift
struct HomeView:View {
    
    //MARK: Properties
    
    /// The set of views which are currently loaded in the `TabBarView` component
    @State private var tabViewItems:[TabBarView.Item] = []

    /// The currently selected tab bar view item
    @State private var selectedItem:TabBarView.Item?

    //MARK: View
    
    var body: some View {
        VStack(spacing:0) {
            ...
            ..

            TabBarView(items: $tabViewItems, selection: $selectedItem) {
                Text("Fallback view shown when no items are loaded in the `TabBarView`")
                    .multilineTextAlignment(.center)
                    .padding()
            }.ignoresSafeArea(.all)
        }
    }
}
```

Alternative usages:

```swift
...
// Short init
TabBarView(items: $tabViewItems)
...
// Full init
TabBarView(items:, selection: , wrapSwiftUIInNavigation: , moreTabTitle: , popToRootOnSelectedTab: , fallbackContent: )
...
```

### Demo showcase

https://github.com/LucaIaco/TabBarView/assets/7451313/8554bc1a-b0a2-4a41-8300-16a86d599311

### TabBarViewItemProtocol

The `TabBarViewItemProtocol` shall be implemented by the `SwiftUI` view or `UIViewController` based object which we want to display in the `TabBarView`. It exposes the following getters:

```swift
    /// The **unique** tab bar item title which is associated to this view once shown in the `TabBarView`
    var tabViewItemTitle:String { get }
    
    /// The optional tab bar item icon which is associated to this view once shown in the `TabBarView`
    var tabViewItemIcon:UIImage? { get }
```

An object conforming to the `TabBarViewItemProtocol`, will get access to the implemented method `updateTabViewBadge(_ badgeValue:String?)`

It's very **IMPORTANT** to remember that the `tabViewItemTitle`:
- Is mandatory
- Shall not be an empty string
- Shall not be equal to the string `TabBarView.moreTabTitle`. By default this is "More". **Note** `moreTabTitle` can be changed in the `TabBarView` initializer with something else

*Under the hood, the `tabViewItemTitle`, (and therefore the `TabBarView.Item.title`) will be used as unique identifier to sync with the internal tab bar items in the `UITabBarController`*

### TabBarView.Item

This is the single data model unit which is given to the `TabBarView` in order to display his internal view. See the usage below:

```swift
/// My Sample SwiftUI view conforming to `TabBarViewItemProtocol`
struct MySwiftUIView:View, TabBarViewItemProtocol {
        
    //MARK: TabBarViewItemProtocol implementation
    
    var tabViewItemTitle: String { "MyTitle0" }
    var tabViewItemIcon: UIImage? { UIImage(systemName: "0.circle" ) }

    var body: some View { ... }
}

/// My Sample View Controller view conforming to `TabBarViewItemProtocol`
final class MyUIKitView: UIViewController, TabBarViewItemProtocol {

    //MARK: TabBarViewItemProtocol implementation
    
    var tabViewItemTitle: String { "MyTitle1" }
    var tabViewItemIcon: UIImage? { UIImage(systemName: "1.circle" ) }

    ...
}

/// Sample TabBarView.Item initialization
..
let myItem0:TabBarView.Item = .init(view: MySwiftUIView())
let myItem1:TabBarView.Item = .init(view: MyUIKitView())
..

// displaying it by assigning them to the observed item array:
..
tabViewItems = [myItem0, myItem1]
..

```

### The "More" tab and Navigation, under the hood

As per today, if we have too many view controllers in the Apple provided SwiftUI component `TabView` and so we see the "More" tab, we may encounter some glitches and issues under it. For example:
- in iOS 15, we may see undesired glitches when user goes under "More" tab, and edits the position of the items. in iOS 17 the "Edit" button seems to have been removed, and at least we don't end up in such scenario
- both before and after iOS 15, any `SwiftUI` view which implements inside a `NavigationView` or `NavigationStack` and gets pushed from under the native "More" tab, will result in having double navigation bar: the one provided by the More tab, and his own one.
  
As mentioned at the beginning, the `TabBarView` is a wrapper of the `UITabBarController`. To handle the exceeding views which may be shown under "More", we do not make use of the native More tab provided intrinsically by the `UITabBarController`, but instead we handle it manually, and the "More" tab is a custom SwiftUI view that gives the same look and feel of the original, but also allows us to handle the navigaiton problem. In details:
- regarding the views which are `UIViewController` based object, those gets just pushed in a `UIViewControllerRepresentable` way from the internal `NavigaitonView` / `NavigationStack`. Also, in case those are sublcass of `UINavigationController` conforming to `TabBarViewItemProtocol`, we handle them in a similar way as done by the UITabBarController.moreNavigationController, so that the navigation bar is always one, and works both inside and outside the "More" tab.
- regarding the views which are `SwiftUI`, by default the `TabBarView` wraps them in a `NavigaitonView` / `NavigationStack`, in order to make then capable of pushing further views. This means that in order to avoid the double navigation bar, the feeded view **MUST NOT** contain his own `NavigaitonView` / `NavigationStack`. By doing so, we are able to handle the navigaiton both inside and outside the "More" tab. If you don't need such special handling, and for example you do not expect to end up seeing the "More" tab ( eg. you will have max 5 tab item on iPhone or 6 tab item on iPad), then you can disable it by setting `wrapSwiftUIInNavigation` init parameter to `false` (eg. `TabBarView(items: $tabViewItems, wrapSwiftUIInNavigation:false)` )

You can see all the provided functionality at work in the sample project, and the relevant code is in the file `SampleViews.swift`, hopefully useful to further understand the navigation mechanism

### Limitations on some corner cases

- *Update tab item badge value corner case*: In order to keep the `TabBarViewItemProtocol` the simplest possible, we don't expect to add too much complexity on that side (such as expecting the views to declare stored properties or similar). This, together with the way the `TabBarView` is designed, will have a problem when is about using multiple `TabBarView` objects at the same time in the app in combination with the update of the tab bar item badge values (via `updateTabViewBadge(_ badgeValue:String?)`). In such scenario, if two existing `TabBarView` instances have a tab bar item with title "XYZ", and we aim to update the badge value for that, will endup updating it respectively in both the `TabBarView` instances. There are many ways to solve this edge case if needed, like indeed introducing identifiers in the `TabBarViewItemProtocol` and expecting all the views to expose them, or modifying the code to not notify the `TabBarView` which are not visible, etc. I didn't want to go that far at the moment, but feel free to modify the code at your need.
- *Lifecycle of the views pushed from under "More" tab and moving back outside of it*: with `TabBarView` we keep alive the components while are displayed, and so their internal states, for both `SwiftUI` and `UIViewController` based object. For views which are under the "More" tab, if those end up moving back to the visible area of the tab bar (eg if you remove first tab item and the total number fits the tab bar, eg is under or equal 5 on iPhone) then the `SwiftUI` view gets recreated, where the `UIViewController` based object is reused and so preserved BUT loses any further view controller which might have been pushed from his underlying navigation controller. Those problems do not exist if we only have max 5 tab bar items (or 6 in iPad) displayed in the `TabBarView`
