//
//  ContentView.swift
//  Leaf
//
//  Created by Laurent Fournier on 23/05/2020.
//  Copyright © 2020 Laurent Fournier. All rights reserved.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation
import Foundation
import Combine
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject {
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    let objectWillChange = PassthroughSubject<Void, Never>()
    @Published var status: CLAuthorizationStatus? {
        willSet { objectWillChange.send() }
    }
    @Published var location: CLLocation? {
        willSet { objectWillChange.send() }
    }
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }
    @Published var placemark: CLPlacemark? {
        willSet { objectWillChange.send() }
    }
    private func geocode() {
        guard let location = self.location else { return }
        geocoder.reverseGeocodeLocation(location, completionHandler: { (places, error) in
            if error == nil {
                self.placemark = places?[0]
            } else {
                self.placemark = nil
            }
        })
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        self.geocode()
    }
}

class TextBindingManager: ObservableObject {
    @Published var text = "" {
        didSet {
            if text.count > Limit && oldValue.count <= Limit { text = oldValue}
        }
    }
    let Limit: Int
    init(limit: Int = 3) { Limit = limit }
}

struct ContentView: View {
    @State private var selected = 0
    var body: some View {
        TabView(selection: $selected) {
            BoardView()
                .tabItem {
                    Image(systemName: (selected == 0 ? "square.fill" : "square"))
                    Text("Balance")
                }.tag(0)
            TransactionView()
                .tabItem {
                    Image(systemName: (selected == 1 ? "play.fill" : "play"))
                    Text("Transactions")
                }.tag(1)
            PayView()
                .tabItem {
                    Image(systemName: (selected == 2 ? "star.fill" : "star"))
                    Text("Pay")
                }.tag(2)
            IdentityView()
                .tabItem {
                    Image(systemName: (selected == 3 ? "circle.fill" : "circle"))
                    Text("Identity")
                }.tag(3)
            //CaptureView()
             //   .tabItem {
            //        Image(systemName: (selected == 4 ? "camera.fill" : "camera"))
             //       Text("Capture")
              //  }.tag(4)
        }
    }
}

struct CVError: View {
    var body: some View {
        VStack() {
            Spacer()
            HStack() {
                Spacer()
                Text("You cannot use this app !").foregroundColor(Color.white)
                Spacer()
            }
            Spacer()
        }.background(Color.orange)
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct Transaction: Codable {
    var num = 0
    var dat = ""
    var cod = ""
    var sgn = "+"
    var place = ""
    var price:Int = 0
    var lat:Double = 0.0
    var lng:Double = 0.0
}

extension CLLocation {
    var lat: Double { return self.coordinate.latitude }
    var lng: Double { return self.coordinate.longitude }
}

func f_latlng(_ s:String) -> String {
    let regex = try! NSRegularExpression(pattern: #"^Optional\((-?\d{1,2}\.\d{8})"#, options: .caseInsensitive)
    if let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
        return String(s[Range(match.range(at: 1), in: s)!])
    }
    return ""
}

func f_plc(_ s:String) -> String {
    let regex = try! NSRegularExpression(pattern: #"^(.*)@"#, options: .caseInsensitive)
    if let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
        return String(s[Range(match.range(at: 1), in: s)!])
    }
    return ""
}

struct PayView: View {
    @ObservedObject var lm = LocationManager()
    var latitude: String  { return("\(String(describing: lm.location?.lat))") }
    var longitude: String { return("\(String(describing: lm.location?.lng))") }
    var place: String { return("\(lm.placemark?.description ?? "X")") }
    //var status: String    { return("\(String(describing: lm.status))") }
    @ObservedObject var price = TextBindingManager(limit: 3)
    @State private var image: Image?
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    @State private var nb: Int = 0
    @State public var bal: String = "0"
    @State public var id1: String = String.random()
    @State public var id2: String = ""
    @State public var rec: String = ""
    @State public var pay: String = ""
    @State private var pricetopay: String = ""
    @State private var message: String = ""
    @State private var visible: Bool = true
    @State private var topay: String = "999"
    @State private var hiddenpay: Bool = false
    let dFormatter = DateFormatter()
    
    func generateQRCode(from string: String) -> UIImage {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
    
    func loadImage() {
        let price = String(format: "%03d", Int(self.price.text) ?? 0)
        let prctp = String(format: "%03d", Int(self.pricetopay) ?? 0)
        var msg: String = ""
        if self.id2 == "" {
            msg = self.id1 + price
        } else {
            msg = self.id1 + self.id2 + prctp
        }
        self.message = msg
        if price == "000" && prctp == "000" {
            self.visible = false
        } else {
            self.visible = true
        }
        image = Image(uiImage: generateQRCode(from: msg))
    }
    
    func processFoundCode(_ code: String) {
        self.nb += 1
        print ("NB", self.nb)
        let p = String(code.suffix(3))
        let id = String(code.prefix(12))
        var recs = UserDefaults.standard.object(forKey: "leaf") as? [Data] ?? [Data]()
        let lat:Double = lm.location?.coordinate.latitude ?? 0.0
        let lng:Double = lm.location?.coordinate.longitude ?? 0.0
        let plc:String = f_plc(self.place)
        let auth: authController = authController()
        
        if code.count == 15 { // DISPLAY 15
            if (p != "000") && (self.pay != id) {
                self.visible = true
                if auth.read(self, Int(p) ?? 0) {
                    self.bal = String((Int(self.bal) ?? 0) - (Int(p) ?? 0))
                    self.id2 = id
                    self.pricetopay = p
                    self.pay = id
                    self.dFormatter.dateFormat = "dd MMMM HH:mm:ss"
                    let tr = Transaction(num: self.nb, dat:self.dFormatter.string(from: Date()), cod: code, sgn:"-", place:plc, price:Int(p) ?? 0, lat:lat, lng:lng)
                    do { let jsonData = try JSONEncoder().encode(tr)
                        recs.insert(jsonData, at: 0)
                        UserDefaults.standard.set(recs, forKey: "leaf")
                    } catch { print("ERROR ENCODING")}
                } else { print("ko")}
                //self.hiddenpay = false
            }
            loadImage()
        } else if code.count == 27 { // DISPLAY 27
            self.visible = true
            let ids = String(code.prefix(24))
            let idd = String(ids.suffix(12))
            if idd != self.id1 {print ("ERROR ID", idd, self.id1)}
            if (idd == self.id1) && (self.rec != id) {
                self.bal = String((Int(self.bal) ?? 0) + (Int(p) ?? 0))
                self.id2 = ""
                self.rec = id
                let tr = Transaction(num: self.nb, dat:self.dFormatter.string(from: Date()), cod: code, sgn:"+", place:plc, price:Int(p) ?? 0, lat:lat, lng:lng)
                do { let jsonData = try JSONEncoder().encode(tr)
                    recs.insert(jsonData, at: 0)
                    UserDefaults.standard.set(recs, forKey: "leaf")
                } catch { print("ERROR ENCODING")}
            }
            self.id2 = ""
            self.price.text = ""
            loadImage()
        } else {print ("ERROR 2", code.count)}
    }
    var body: some View {
        VStack(spacing:0) {
            ZStack() {
                QRCodeScan(onCodeScanned: {self.processFoundCode($0)})
                    .edgesIgnoringSafeArea(.all)
                Text(topay)
                    .font(.system(size: 160))
                    .foregroundColor(Color.red)
                    .opacity(self.hiddenpay ? 1.0 : 0.0)
                TextField("0", text: $price.text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 160))
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.center)
                
            }
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color.white)
                .opacity(self.visible ? 1.0 : 0.0)
            image?
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .padding()
                .opacity(self.visible ? 1.0 : 0.0)
        }
        .background(Color.orange)
        .onTapGesture() {
            UIApplication.shared.endEditing()
            self.id1 = String.random()
            self.id2 = ""
            self.rec = ""
            self.pay = ""
            self.pricetopay = ""
            self.loadImage()
            self.dFormatter.dateFormat = "dd MMMM HH:mm:ss"
        }
        .onAppear(perform: loadImage)
    }
}

struct IdentityView: View {
    @State private var offset = CGSize.zero
    @State private var index = 0
    
    @State var initialImage = UIImage()
    @State private var pos:Int = 0
    @State private var name:String = ""
    let files = FileManager.default.urls(for: .documentDirectory) ?? []
    func next() {
        if files != [] {
            guard let url = URL(string: self.files[self.pos].absoluteString) else { return }
            self.name = String(self.files[self.pos].lastPathComponent.split(separator: ".").first!)
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard let data = data else { return }
                guard let image = UIImage(data: data) else { return }
                RunLoop.main.perform { self.initialImage = image }
            }.resume()
        }
    }
    var body: some View {
        HStack() {
            Spacer()
        ZStack() {
            HStack() {
            Image(uiImage: initialImage)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.size.height+2, height: 15, alignment: .center)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    self.next()
                }
                .onTapGesture() {
                    if self.files.count > 0 {
                        self.pos = (self.pos+1)%self.files.count
                        self.next()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { gesture in self.offset = gesture.translation }
                        .onEnded { _ in
                            if abs(self.offset.height) > 100 {
                                if self.offset.height < 0 {
                                    self.pos = (self.pos+1)%self.files.count
                                } else {
                                    self.pos -= 1
                                    if self.pos<0 { self.pos = self.files.count-1}
                                }
                                self.next()
                            } else {
                                self.offset = .zero
                            }
                        }
                )
            }.rotationEffect(.degrees(90))
            VStack() {
            Text(self.name)
                .foregroundColor(Color.white)
                .font(.system(.body, design: .monospaced))
            Text(String(self.pos+1))
                .foregroundColor(Color.white)
            Spacer()
            }.padding()
        }
        Spacer()
        }.background(Color.orange)
    }
}

struct BoardView: View {
    @State var isin: Bool = true
    var body: some View {
        VStack() {
            if isin { BalanceView() } else { SpaceView() }
        }
        .background(Color.orange)
            .edgesIgnoringSafeArea(.all)
        .onTapGesture() { self.isin = !self.isin}
    }
}

func Mfill(_ tr: Transaction) -> Mark {
    return Mark(coordinates: Coordinates(latitude: tr.lat, longitude: tr.lng))
}

struct SpaceView: View {
    let recs = UserDefaults.standard.object(forKey: "leaf") as? [Data] ?? [Data]()
    @ObservedObject var lm = LocationManager()
    @State var tr1: Transaction = Transaction(num: 0, dat:"", cod: "", sgn:"-", place:"", price:0, lat:48.0, lng:2.0)
    var body: some View {
        VStack() {
            HStack() {
                //MapViewAll(tr1: self.tr1)
                MapViewAll()
            }
        }
        .background(Color.orange)
        .onAppear() {
            let lat = f_latlng("\(String(describing: self.lm.location?.lat))")
            let lng = f_latlng("\(String(describing: self.lm.location?.lng))")
            self.tr1 = Transaction(num: 0, dat:"", cod: "", sgn:"-", place:"", price:0, lat:Double(lat) ?? 0.0, lng:Double(lng) ?? 0.0)
        }
    }
}
struct MapViewAll: UIViewRepresentable {
    let recs = UserDefaults.standard.object(forKey: "leaf") as? [Data] ?? [Data]()
    class LAnnotation: NSObject, MKAnnotation {
        var title: String?
        var coordinate: CLLocationCoordinate2D
        init(_ lm: Pt) {
            self.title = lm.name
            self.coordinate = lm.location
        }
    }
    func makeUIView(context: Context) -> MKMapView { MKMapView(frame: .zero) }
    func updateUIView(_ uiView: MKMapView, context: Context) {
        print ("update All map")
        let paris = Transaction(num: 0, dat:"Paris", cod: "", sgn:"-", place:"", price:0, lat:48.85, lng:2.34)
        let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        let region = MKCoordinateRegion(center: Mfill(paris).locationCoordinate, span: span)
        var tab: [Pt] = []
        tab.append(Pt(name: paris.dat, location: .init(latitude: paris.lat , longitude: paris.lng)))
        for i in recs {
            let dt = gettr(i)
            tab.append(Pt(name: dt.dat, location: .init(latitude: dt.lat , longitude: dt.lng)))
        }
        uiView.setRegion(region, animated: true)
        uiView.removeAnnotations(uiView.annotations)
        let newAnnot = tab.map { LAnnotation($0) }
        uiView.addAnnotations(newAnnot)
    }
}

struct BalanceView: View {
    let recs = UserDefaults.standard.object(forKey: "leaf") as? [Data] ?? [Data]()
    @State var date = Date()
    @State var solde: Int = 0
    @State public var bigbal: String = ""
    @State private var sgn: String = ""
    let dFormatter = DateFormatter()
    @State private var here: String = ""
    let plus: String = "+"
    let moins: String = "(-)"
    @ObservedObject var lm = LocationManager()
    var latitude:  String { return("\(String(describing: lm.location?.lat))") }
    var longitude: String { return("\(String(describing: lm.location?.lng))") }
    var place: String { return("\(lm.placemark?.description ?? "X")") }
    var body: some View {
        VStack {
            Spacer()
            Text("Balance").foregroundColor(Color.white)
            Text(sgn)
                .font(.system(size: 90))
                .foregroundColor(Color.gray)
            HStack {
                Spacer()
                Text(self.bigbal).font(.system(size: 120))
                Spacer()
            }
            Spacer()
            Text(self.dFormatter.string(from: Date()))
                .foregroundColor(Color.white)
                .font(.subheadline)
                .onAppear() {
                    let _ = self.updateTimer
                    self.dFormatter.dateFormat = "dd MMMM HH:mm:ss"
                }
            Spacer()
            HStack() {
                Text(self.here)
                    .foregroundColor(Color.white)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .onAppear() { let _ = self.updateTimer }
                    .padding(.horizontal)
                Spacer()
            }
            Spacer()
            Spacer()
        }
        .background(Color.orange)
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            self.solde = computeBalance(self.recs)
            if self.solde<0 {
                self.bigbal = "\(-self.solde)"
                self.sgn = "(-)"
            } else {
                self.bigbal = "\(self.solde)"
                self.sgn = "+"
            }
        }
    }
    var updateTimer: Timer {
         Timer.scheduledTimer(withTimeInterval: 5, repeats: true,
                              block: {_ in
                                self.date = Date()
                                let lat:String = f_latlng(self.latitude)
                                let lng:String = f_latlng(self.longitude)
                                let plc:String = f_plc(self.place)
                                self.here = "Latitude:\t" + lat + "\nLongitude:\t" + lng + "\n" + plc
         })
    }
}

struct QRCodeScan: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self)}
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: ScannerViewController, context: Context) {}
    class Coordinator: NSObject, QRCodeScannerDelegate {
        func codeDidFind(_ code: String) {parent.onCodeScanned(code)}
        var parent: QRCodeScan
        init(_ parent: QRCodeScan) {self.parent = parent}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
