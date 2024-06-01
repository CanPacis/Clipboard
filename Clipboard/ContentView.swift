//
//  ContentView.swift
//  Clipboard
//
//  Created by Muhammed Ali Can on 14.03.2024.
//

import SwiftUI
import CryptoKit
import CoreTransferable
import SwiftLinkPreview
import SwiftData
import SwiftUI

class SLP {
    var instance = SwiftLinkPreview(
        session: URLSession.shared,
        workQueue: SwiftLinkPreview.defaultWorkQueue,
        responseQueue: DispatchQueue.main,
        cache: DisabledCache.instance
    )
}

class ClipboardEntry: Identifiable {
    var ID = UUID()
    var date = Date.now
    var hash = ""
    
    init(ID: UUID = UUID(), date: Foundation.Date = Date.now, hash: String = "") {
        self.ID = ID
        self.date = date
        self.hash = hash
    }
}

class TextClipboardEntry: ClipboardEntry {
    var data = ""
}

class URLClipboardEntry: ClipboardEntry {
    var data = URL(string: "https://canpacis.net")!
}

class ImageClipboardEntry: ClipboardEntry {
    var image = Image("")
    var data = Data()
}

class AppState: ObservableObject {
    @Published var items: [ClipboardEntry]
    @Published var active: String?

    init(items: [ClipboardEntry], active: String? = nil) {
        self.items = items
        self.active = active
    }
}

struct ContentView: View {
    @StateObject var state = AppState(items: [])
    
    func watch(entry: ClipboardEntry) {
        let index = state.items
            .firstIndex(where: { $0.hash == entry.hash })
        
        if index == nil {
            withAnimation(.easeInOut) {
                state.items.append(entry)
            }
        }else {
            if index != state.items.count - 1 {
                withAnimation(.easeInOut) {
                    let item = state.items[index!]
                    state.items.remove(at: index!)
                    state.items.append(item)
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack {
                    HStack {
                        Text("Your Clipboard")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Clear", role: .destructive, action: {
                            withAnimation(.easeInOut) {
                                state.items = []
                            }
                        })
                    }
                    
                    if state.items.count == 0 {
                        VStack {
                            Text("No Clipboard Item Yet")
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }else {
                        ForEach(state.items.reversed(), id: \.self.id) { item in
                            ClipboardView(entry: item, remove: { id in
                                let index = state.items.firstIndex(where: { $0.ID == id })
                                
                                if index != nil {
                                    withAnimation(.easeInOut) {
                                        state.items.remove(at: index!)
                                    }
                                }
                            })
                        }
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 320, maxWidth: 500)
        .dropDestination(for: DropItem.self) { droppedList, _ in
            let dropped = droppedList.first!
            
            switch dropped {
            case .url(url: let url):
                withAnimation(.easeInOut) {
                    let entry = URLClipboardEntry()
                    entry.data = url
                    entry.hash = url.absoluteString
                    state.items.append(entry)
                }
                return true
            case .text(text: let text):
                withAnimation(.easeInOut) {
                    let entry = TextClipboardEntry()
                    entry.data = text
                    entry.hash = text
                    state.items.append(entry)
                }
                return true
            case .data(data: let data):
                withAnimation(.easeInOut) {
                    let entry = ImageClipboardEntry()
                    entry.image = createImage(data)
                    entry.hash = createHash(data)
                    entry.data = data
                    state.items.append(entry)
                }
                return true
            default:
                return false
            }
        }
        .onAppear(perform: {
            watchText { text in
                state.active = text.hash
                watch(entry: text)
            }
            
            watchImage { image in
                state.active = image.hash
                watch(entry: image)
            }
        })
        .environmentObject(state)
        // .modelContainer(for: [ClipboardEntry.self])
    }
}

struct ClipboardView: View {
    var entry: ClipboardEntry
    var remove: (_: UUID) -> Void
    @EnvironmentObject var dataModel: AppState
    @State private var scale = 1.0
    @State private var copyDone = false
    
    func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch entry {
        case is TextClipboardEntry:
            let data = (entry as! TextClipboardEntry).data
            pasteboard.setString(data, forType: .string)
        case is URLClipboardEntry:
            pasteboard.setString(entry.hash, forType: .string)
        case is ImageClipboardEntry:
            let image = (entry as! ImageClipboardEntry).data
            pasteboard.setData(image, forType: .tiff)
        default: break
        }
        
        copyDone = true
    }
    
    var body: some View {
        VStack {
            VStack {
                switch entry {
                case is TextClipboardEntry:
                    Text((entry as! TextClipboardEntry).data)
                case is URLClipboardEntry:
                    let url = entry as! URLClipboardEntry
                    URLPreview(url: url)
                case is ImageClipboardEntry:
                    let image = (entry as! ImageClipboardEntry)
                    ImagePreview(image: image)
                default:
                    Text("Unknown clipborad entry")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            VStack {
                Text(entry.date.formatted(.dateTime.month().day().hour().minute()))
                    .foregroundColor(Color.white.opacity(0.6))
                    .font(.caption)
            }
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6.0)
        .scaleEffect(scale)
        .animation(.snappy(duration: 0.200), value: scale)
        .overlay(
            dataModel.active == entry.hash ? RoundedRectangle(cornerRadius: 6.0)
                .stroke(.blue, lineWidth: 1) : RoundedRectangle(cornerRadius: 6.0)
                .stroke(.blue.opacity(0), lineWidth: 1)
        )
        .onTapGesture {
            copy()
        }
        .onHover(perform: { hovering in
            if hovering {
                NSCursor.pointingHand.push()
                scale = 1.02
            }else {
                scale = 1.0
                NSCursor.pop()
            }
        })
        .modifier(PressActions(
            onPress: {
                scale = 0.98
            },
            onRelease: {
                scale = 1
            }
        ))
        .contextMenu(ContextMenu(menuItems: {
            Button {
                copy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc.fill")
            }
            if entry is ImageClipboardEntry {
                Button {
                    let data = (entry as! ImageClipboardEntry).data
                    let url = URL.downloadsDirectory.appending(path: "\(entry.ID).jpg")
                     
                    do {
                        try data.write(to: url, options: [.atomic, .completeFileProtection])
                    } catch {
                        print(error)
                    }
                } label: {
                    Label("Save Image", systemImage: "photo.fill")
                }
            }
            Button {
                remove(entry.ID)
            } label: {
                Label("Remove", systemImage: "trash.fill")
            }
        }))
    }
}

struct ImagePreview: View {
    var image: ImageClipboardEntry
    
    var body: some View {
        image.image
            .resizable()
            .frame(maxWidth: .infinity, alignment: .center)
            .aspectRatio(contentMode: .fit)
            .cornerRadius(4.0)
    }
}

struct URLPreview: View {
    var url: URLClipboardEntry
    @State var loading = true
    @State var error = false
    @State var icon = ""
    @State var heading = ""
    @State var title = ""
    @State var description = ""
    @State var image = ""
    
    func getMetaData() {
        let slp = SLP()
        
        slp.instance.preview(
            url.hash,
            onSuccess: { result in
                loading = false
                error = false
                
                if result.canonicalUrl != nil {
                    heading = result.canonicalUrl!
                }
                
                if result.title != nil {
                    title = result.title!
                }
                
                if result.description != nil {
                    description = result.description!
                }
                
                if result.icon != nil {
                    icon = result.icon!
                }
                
                if result.image != nil {
                    image = result.image!
                }
            },
            onError: { e in
                print(e)
                loading = false
                error = true
            }
        )
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if error {
                Text(url.hash)
                    .foregroundColor(.blue)
            }else {
                if loading {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.mini)
                            .frame(width: 40, height: 40)
                        Text(url.hash)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }else {
                    VStack {
                        AsyncImage(url: URL(string: icon)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .help(url.hash)
                        } placeholder: {
                            ProgressView()
                                .controlSize(.mini)
                                .frame(width: 40, height: 40)
                        }
                        
                        Spacer()
                    }
                    .frame(alignment: .topLeading)
                    
                    VStack(spacing: 6) {
                        Text(heading)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fontWeight(.black)
                            .font(.title3)
                            .lineLimit(1)
                            .foregroundColor(.blue)
                            .help(heading)
                        
                        if !title.isEmpty {
                            Text(title)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .help(title)
                        }
                        
                        if !description.isEmpty {
                            Text(description)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .lineLimit(4)
                                .help(description)
                        }
                        
                        if !image.isEmpty {
                            AsyncImage(url: URL(string: image)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(8.0)
                            } placeholder: {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                }
            }
        }
        .onAppear(perform: {
            getMetaData()
        })
    }
}

struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ _ in
                        onPress()
                    })
                    .onEnded({ _ in
                        onRelease()
                    })
            )
    }
}

enum DropItem: Codable, Transferable {
    case none
    case text(String)
    case url(URL)
    case data(Data)
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { DropItem.url($0) }
        ProxyRepresentation { DropItem.text($0) }
        ProxyRepresentation { DropItem.data($0) }
    }
    
    var url: URL? {
        switch self {
            case .url(let url): return url
            default: return nil
        }
    }
    
    var text: String? {
        switch self {
            case .text(let str): return str
            default: return nil
        }
    }
    
    var data: Data? {
        switch self {
            case.data(let data): return data
            default: return nil
        }
    }
}

func watchText(using closure: @escaping (_ copiedString: ClipboardEntry) -> Void) {
    let pasteboard = NSPasteboard.general
    var changeCount = NSPasteboard.general.changeCount

    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        guard let copiedString = pasteboard.string(forType: .string),
              pasteboard.changeCount != changeCount else { return }

        defer {
            changeCount = pasteboard.changeCount
        }
        
        if copiedString.isValidURL {
            let entry = URLClipboardEntry()
            entry.data = URL(string: copiedString)!
            entry.hash = copiedString
            closure(entry)
        }else {
            let entry = TextClipboardEntry()
            entry.data = copiedString
            entry.hash = copiedString
            closure(entry)
        }
    }
}

func watchImage(using closure: @escaping (_ copiedImage: ImageClipboardEntry) -> Void) {
    let pasteboard = NSPasteboard.general
    var changeCount = NSPasteboard.general.changeCount
    
    Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
        guard let copiedImage = pasteboard.data(forType: .tiff),
              pasteboard.changeCount != changeCount else { return }
        
        defer {
            changeCount = pasteboard.changeCount
        }
        
        let entry = ImageClipboardEntry()
        entry.data = copiedImage
        entry.image = createImage(copiedImage)
        entry.hash = createHash(copiedImage)
        closure(entry)
    }
}

extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
}

func createImage(_ value: Data) -> Image {
#if canImport(UIKit)
    let songArtwork: UIImage = UIImage(data: value) ?? UIImage()
    return Image(uiImage: songArtwork)
#elseif canImport(AppKit)
    let songArtwork: NSImage = NSImage(data: value) ?? NSImage()
    let image = Image(nsImage: songArtwork)
    return image
#else
    return Image(systemImage: "some_default")
#endif
}

func createHash(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    let hashString = digest
        .compactMap { String(format: "%02x", $0) }
        .joined()
    return hashString
}

#Preview {
    ContentView()
}
