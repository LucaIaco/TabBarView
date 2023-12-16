//
//  TabBarViewApp.swift
//  TabBarView
//
//  Created by Luca Iaconis on 02.12.23.
//

import SwiftUI

//MARK: - Demo app launcher

@main
struct TabBarViewApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

//MARK: - HomeView - Demo content screen

struct HomeView:View {
    
    //MARK: Properties
    
    /// The set of views which are currently loaded in the `TabBarView` component
    @State private var tabViewItems:[TabBarView.Item] = []
    
    /// The currently selected tab bar view item
    @State private var selectedItem:TabBarView.Item?
    
    /// Show/Hide the demo panel view
    @State private var isDemoPanelVisible = false
    
    @State private var segmentNewItemType:SampleViews.ViewType = .swiftUI
    @State private var segmentConfiguration:SampleViews.ViewConfig = .normal
    
    //MARK: View
    
    var body: some View {
        VStack(spacing:0) {
            // Demo Panel view located on top of the screen
            demoPanelView
            // The actual TabBarView component
            TabBarView(items: $tabViewItems, selection: $selectedItem) {
                Text("Fallback view shown when no items are loaded in the `TabBarView`.\n\n Tap on **Show demo panel** to access the demo panel and add / remove items in the `TabBarView`")
                    .multilineTextAlignment(.center)
                    .padding()
            }.ignoresSafeArea(.all)
        }
    }
    
}

//MARK: - HomeView - Demo panel view
extension HomeView {
    
    /// The demo panel view shown at the top of the demo screen
    @ViewBuilder private var demoPanelView: some View {
        VStack(alignment: .leading, spacing:8.0) {
            
            Divider()
            HStack {
                Spacer()
                Button(isDemoPanelVisible ? "Hide demo panel" : "Show demo panel" ) {
                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
                        isDemoPanelVisible.toggle()
                    }
                }
            }
            Divider()
            
            if isDemoPanelVisible {
                Group {
                    Text("Add new `TabBarView.Item`")
                    HStack {
                        Text("View type")
                        Picker("", selection: $segmentNewItemType) {
                            Text("SwiftUI view").tag(SampleViews.ViewType.swiftUI)
                            Text("UIKit view").tag(SampleViews.ViewType.uiKit)
                        }.pickerStyle(.segmented)
                    }
                    HStack {
                        Text("View config")
                        Picker("", selection: $segmentConfiguration) {
                            Text("Normal").tag(SampleViews.ViewConfig.normal)
                            Text("Navigation").tag(SampleViews.ViewConfig.withNavigation)
                        }.pickerStyle(.segmented)
                    }
                    HStack {
                        Button("Append Item") {
                            tabViewItems.append(buildNewItem)
                        }.disabled(!canAdd)
                        Spacer()
                        Button("Prepend Item") {
                            tabViewItems.insert(buildNewItem, at: 0)
                        }.disabled(!canAdd)
                    }
                }
                Divider()
                Group {
                    HStack {
                        Group {
                            Button("Shuffle") {
                                tabViewItems.shuffle()
                            }.disabled(!canRemove)
                            Spacer()
                            Divider().frame(height:25).overlay(.black)
                        }
                        Spacer()
                        Group {
                            Text("Remove:").foregroundStyle(Color.black.opacity(0.7))
                            
                            Group {
                                Spacer()
                                Button("First", role: .destructive) {
                                    tabViewItems.removeFirst()
                                }.disabled(!canRemove)
                                Spacer()
                                Divider().frame(height:25)
                            }
                            
                            Group {
                                Spacer()
                                Button("Last", role: .destructive) {
                                    tabViewItems.removeLast()
                                }.disabled(!canRemove)
                                Spacer()
                                Divider().frame(height:25)
                            }
                                
                            Group {
                                Spacer()
                                Button("All", role: .destructive) {
                                    tabViewItems.removeAll()
                                }.disabled(!canRemove)
                            }
                        }
                    }
                }
                Divider()
                HStack(spacing:8) {
                    Text("`selectedItem.title`:").font(.footnote)
                    Text(selectedItem?.title ?? "<N/A>").font(.footnote).bold()
                    Spacer()
                    Button("Select first") {
                        selectedItem = tabViewItems.first
                    }.disabled(!canRemove)
                }
                Divider()
            }
        }
        .padding([.leading, .trailing])
        .background(content: { Color.cyan.opacity(0.07) })
    }
    
    /// Convenience getter which builds and return a new `TabBarView.Item` for the current demo configuraiton
    private var buildNewItem:TabBarView.Item {
        SampleViews.newItem(viewType: segmentNewItemType,
                            viewConfig: segmentConfiguration,
                            againstItems: tabViewItems)
    }
    
    private var canAdd: Bool { tabViewItems.count < SampleViews.sampleNames.count }
    
    private var canRemove: Bool { !tabViewItems.isEmpty }
}
