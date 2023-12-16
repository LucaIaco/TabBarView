//
//  SampleViews.swift
//  TabBarView
//
//  Created by Luca Iaconis on 04.12.23.
//

import SwiftUI

//MARK: - SampleViews namespace

enum SampleViews { }

//MARK: - SampleViews Utilities

extension SampleViews {
    
    //MARK: Public
    
    enum ViewType:String {
        /// Indicates if the view type should be UIKit
        case uiKit
        /// Indicates if the view type should be SwiftUI
        case swiftUI
    }
    
    enum ViewConfig:String {
        /// No special view configuration
        case normal
        /// Shows the navigation bar title in SwiftUI, and wraps the view in a `UINavitationController` for UIKit. Lastly, it shows a button to further push a dummy view
        case withNavigation
    }
    
    /// Builds and returns a new view item
    /// - Parameters:
    ///   - viewType: whether should be a UIKit or a SwiftUI based view
    ///   - viewConfig: the view configuration
    ///   - againstItems: the current displayed set of tab bar view items, used to generate a new unique one
    /// - Returns: the resulting tab bar item to be added to the `TabBarView`
    static func newItem(viewType:SampleViews.ViewType, viewConfig:SampleViews.ViewConfig, againstItems:[TabBarView.Item]) -> TabBarView.Item {
        let newTitle = Self.generateName(against: againstItems)
        switch viewType {
        case .uiKit:
            let view: TabBarViewItemProtocol
            let vc = SampleViews.UIKitView(itemName: newTitle, config: viewConfig)
            switch viewConfig {
            case .normal:  view = vc
            case .withNavigation: view = SampleViews.UIKitNavigation(rootViewController: vc)
            }
            return .init(view: view)
        case .swiftUI:
            return .init(view: SampleViews.SwiftUIView(itemName: newTitle, config: viewConfig))
        }
    }
    
    //MARK: Private
    
    /// Sample full list of icon names
    static let sampleNames = (0...50).map({ "\($0).circle" })
    
    /// Fallback item name
    fileprivate static let fallbackName = "figure.walk.circle"
    
    /// Generates a new system icon name to be used as icon and title for a tab bar view item
    /// - Parameter tabItems: the reference tab bar items to check against in order to avoid duplicates
    /// - Returns: the resulting system icon name
    private static func generateName(against tabItems:[TabBarView.Item]) -> String {
        let tabItemNames = tabItems.compactMap({ $0.title })
        guard let newName = Self.sampleNames.first(where: { !tabItemNames.contains($0) }) else {
            return Self.fallbackName
        }
        return newName
    }
    
}

//MARK: - SampleViews.UIKitView

fileprivate extension SampleViews {
    
    final class UIKitView: UIViewController, TabBarViewItemProtocol {
        
        //MARK: TabBarViewItemProtocol implementation
        
        var tabViewItemTitle: String { self.itemName }
        var tabViewItemIcon: UIImage? { UIImage(systemName: self.itemName ) }
        
        //MARK: Properties
        
        private let itemName:String
        private let config: SampleViews.ViewConfig
        
        //MARK: Initializers
        
        init(itemName:String, config:SampleViews.ViewConfig) {
            self.itemName = itemName
            self.config = config
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            self.itemName = SampleViews.fallbackName
            self.config = .normal
            super.init(coder: coder)
        }
        
        //MARK: View lifecycle
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.setup()
        }
        
        //MARK: Private
        
        private func setup() {
            self.view.backgroundColor = .systemBackground
            
            let stack = UIStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.spacing = 16.0
            stack.axis = .vertical
            stack.alignment = .center
            self.view.addSubview(stack)
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16).isActive = true
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16).isActive = true
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
            
            let imgView = UIImageView(image: self.tabViewItemIcon ?? UIImage(systemName: "xmark.circle"))
            imgView.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
            imgView.widthAnchor.constraint(equalTo: imgView.heightAnchor).isActive = true
            imgView.contentMode = .scaleAspectFit
            stack.addArrangedSubview(imgView)
            
            let lblBody = UILabel()
            lblBody.textAlignment = .center
            lblBody.numberOfLines = 0
            lblBody.font = .systemFont(ofSize: 20)
            switch self.config {
            case .normal:
                lblBody.text = "Sample UIKit view conforming to `TabBarViewItemProtocol`."
            case .withNavigation:
                lblBody.text = "Sample UIKit view conforming to `TabBarViewItemProtocol`.\n\nThis view is configured to have navigation, so navigation bar title and support to push views under it are provided."
            }
            stack.addArrangedSubview(lblBody)
            
            let btnShowBadge = UIButton(type: .custom, primaryAction: .init(title: "Show TabBar item badge") { [weak self] _ in
                self?.updateTabViewBadge("\((Int.random(in: 1..<100)))")
            })
            btnShowBadge.setTitleColor(.systemBlue, for: .normal)
            let btnHideBadge = UIButton(type: .custom, primaryAction: .init(title: "Hide TabBar item badge") { [weak self] _ in
                self?.updateTabViewBadge(nil)
            })
            btnHideBadge.setTitleColor(.systemRed, for: .normal)
            let stackBtnBadge = UIStackView(arrangedSubviews: [btnShowBadge, btnHideBadge])
            stackBtnBadge.axis = .vertical
            stack.addArrangedSubview(stackBtnBadge)
            
            if self.config == .withNavigation {
                
                self.navigationItem.title = self.tabViewItemTitle
                
                let btnPushView = UIButton(type: .custom, primaryAction: .init(title: "Push another view") { [weak self] _ in
                    self?.navigationController?.pushViewController(SampleViews.DummyUIKitView(nibName: nil, bundle: nil), animated: true)
                })
                btnPushView.setTitleColor(.systemBlue, for: .normal)
                stack.addArrangedSubview(btnPushView)
            }
        }
        
    }
}

//MARK: - SampleViews.SwiftUIView

fileprivate extension SampleViews {
    
    struct SwiftUIView:View, TabBarViewItemProtocol {
        
        //MARK: TabBarViewItemProtocol implementation
        
        var tabViewItemTitle: String { self.itemName }
        var tabViewItemIcon: UIImage? { UIImage(systemName: self.itemName ) }
        
        //MARK: Properties
        
        private let itemName:String
        private let config: SampleViews.ViewConfig
        
        //MARK: Initializer
        
        init(itemName: String, config: SampleViews.ViewConfig) {
            self.itemName = itemName
            self.config = config
        }
        
        //MARK: View
        
        var body: some View {
            ScrollView {
                VStack(alignment: .center, spacing: 16.0) {
                    Image(uiImage: self.tabViewItemIcon ?? UIImage(systemName: "xmark.circle")!)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundStyle(Color.blue)
                    
                    Text(bodyText)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20))
                    
                    Group {
                        Button("Show TabBar item badge") {
                            self.updateTabViewBadge("\((Int.random(in: 1..<100)))")
                        }
                        Button("Hide TabBar item badge", role:.destructive) {
                            self.updateTabViewBadge(nil)
                        }
                    }
                    
                    if self.config == .withNavigation {
                        NavigationLink("Push another view") { dummySwiftUIView }
                    }
                }
                .padding()
                .if(self.config == .withNavigation) { view in
                    view.navigationTitle(self.tabViewItemTitle)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .if(self.config == .normal) { view in
                    view.navigationBarHidden(true)
                }
            }
        }
        
        //MARK: Private
        
        private var bodyText: LocalizedStringKey {
            switch config {
            case .normal:
                return "Sample **SwiftUI** view conforming to `TabBarViewItemProtocol`."
            case .withNavigation:
                return "Sample **SwiftUI** view conforming to `TabBarViewItemProtocol`.\n\nThis view is configured to have navigation, so navigation bar title and support to push views under it are provided."
            }
        }
        
        @ViewBuilder private var dummySwiftUIView: some View {
            ScrollView {
                VStack {
                    Text("Empty SwiftUI view")
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("Empty SwiftUI view")
                .navigationBarTitleDisplayMode(.inline)
            }
        }

    }
}

//MARK: - SampleViews.UIKitNavigation

fileprivate extension SampleViews {
    
    final class UIKitNavigation:UINavigationController, TabBarViewItemProtocol {
        
        //MARK: TabBarViewItemProtocol implementation
        
        var tabViewItemTitle: String {
            // propagate the title of the first view controller if this is conforming to the protocol TabBarViewItemProtocol
            guard let viewProtocol = self.viewControllers.first as? TabBarViewItemProtocol else { return "" }
            return viewProtocol.tabViewItemTitle
        }
        
        var tabViewItemIcon: UIImage? {
            // propagate the icon of the first view controller if this is conforming to the protocol TabBarViewItemProtocol
            guard let viewProtocol = self.viewControllers.first as? TabBarViewItemProtocol else { return nil }
            return viewProtocol.tabViewItemIcon
        }
    }
}

//MARK: - SampleViews.DummyUIKitView

fileprivate extension SampleViews {
    
    final class DummyUIKitView: UIViewController {
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.view.backgroundColor = .systemBackground
            
            let lblBody = UILabel()
            lblBody.translatesAutoresizingMaskIntoConstraints = false
            lblBody.textAlignment = .center
            lblBody.numberOfLines = 0
            lblBody.font = .systemFont(ofSize: 20)
            lblBody.text = "Empty UIKit view"
            self.view.addSubview(lblBody)
            lblBody.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16).isActive = true
            lblBody.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16).isActive = true
            lblBody.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
            
            self.navigationItem.title = lblBody.text
        }
    }
}

//MARK: - View extension

fileprivate extension View {
    
    @ViewBuilder func `if`<Content:View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
