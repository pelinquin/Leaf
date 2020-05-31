import SwiftUI
import MapKit
import UIKit
import CoreLocation

struct NavigationConfigurator: UIViewControllerRepresentable {
    var configure: (UINavigationController) -> Void = { _ in }
    func makeUIViewController(context: UIViewControllerRepresentableContext<NavigationConfigurator>) -> UIViewController {
        UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<NavigationConfigurator>) {
        if let nc = uiViewController.navigationController {
            self.configure(nc)
        }
    }
}
func gettr(_ name:Data) -> Transaction {
    let decoder = JSONDecoder()
    var user = Transaction()
    do { user = try decoder.decode(Transaction.self, from: name)
    } catch { print("ERROR") }
    return user
}
func computeBalance(_ tab: [Data]) -> Int {
    var total: Int = 0
    for x in tab {
        let item: Transaction = gettr(x)
        if item.cod.count == 15 {
            total -= item.price
        } else {
            total += item.price
        }
    }
    return total
}

struct TransactionView: View {
    let recs = UserDefaults.standard.object(forKey: "leaf") as? [Data] ?? [Data]()
    @State var solde: Int = 0
    var body: some View {
        NavigationView {
            List((0..<self.recs.count)) { i in
                NavigationLink(destination: DetailView(tr: gettr(self.recs[i]))) {
                    RowView(tr: gettr(self.recs[i]), pos:self.recs.count-i)
                }
            }
            .navigationBarTitle("Balance: \(self.solde)", displayMode: .inline)
        }
        .onAppear() { self.solde = computeBalance(self.recs) }
    }
    
}
struct RowView: View {
    var tr: Transaction
    var pos: Int
    @State var initialImage = UIImage()
    @State private var dataTask: URLSessionDataTask?
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    func downloadImage(from url: URL) {
        //print("Download Started")
        getData(from: url) { data, response, error in
            guard let data = data, error == nil else { return }
            //print(response?.suggestedFilename ?? url.lastPathComponent)
            //print("Download Finished")
            DispatchQueue.main.async() { [self] in self.initialImage = UIImage(data: data)! }
        }
    }
    func getImage(_ name:String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url2 = url.appendingPathComponent(name).absoluteString.removingPercentEncoding
        self.dataTask?.cancel()
        self.downloadImage(from: (URLComponents(string: String(url2 ?? ""))?.url!)!)
    }
    var body: some View {
        HStack {
            ZStack() {
            Image(uiImage: initialImage)
                .resizable()
                .frame(width: 50, height: 50)
                .onAppear { self.getImage(self.tr.cod + ".png") }
            Text("\(pos)").font(.system(size: 18)).foregroundColor(Color.white)
            }
            VStack(alignment: .leading) {
                Text(tr.dat).font(.system(size: 16))
                Text(self.tr.cod)
                    .font(.system(size: 7))
                Text("Lat:\(self.tr.lat) Lng:\(self.tr.lng)")
                    .font(.system(size: 8))
                    .foregroundColor(Color.blue)
                Text(self.tr.place)
                    .font(.system(size: 8))
                    .foregroundColor(Color.blue)
            }
            Spacer()
            Text(tr.sgn)
                .font(.title)
            if tr.sgn == "-" {
                Text("\(tr.price)")
                    .font(.title)
                    .foregroundColor(Color.red)
            } else {
                Text("\(tr.price)")
                    .font(.title)
                    .foregroundColor(Color.green)
            }
        }
    }
}
struct DetailView: View {
    var tr: Transaction
    @State var initialImage = UIImage()
    @State private var dataTask: URLSessionDataTask?
    
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    func downloadImage(from url: URL) {
        getData(from: url) { data, response, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async() { [self] in
                self.initialImage = UIImage(data: data)!
            }
        }
    }
    func getImage(_ name:String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url2 = url.appendingPathComponent(name).absoluteString.removingPercentEncoding
        //print ("URL->", url)
        self.dataTask?.cancel()
        self.downloadImage(from: (URLComponents(string: String(url2 ?? ""))?.url!)!)
    }
    var body: some View {
        VStack(spacing:0) {
            ZStack {
            Image(uiImage: initialImage)
                .resizable()
                .scaledToFit()
                .onAppear { self.getImage(self.tr.cod + ".png") }
            Text(self.tr.cod)
                .foregroundColor(Color.white)
                .font(.system(.body, design: .monospaced))
            }
            MapView(coord:  Mfill(self.tr).locationCoordinate, dat: self.tr.dat)
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Latitude:\(self.tr.lat)")
                    Text("Longitude:\(self.tr.lng)")
                    Text(self.tr.place).font(.system(size: 9))
                    .multilineTextAlignment(.leading)
                }
                .font(.subheadline)
                .lineLimit(nil)
                Spacer()
                Text(self.tr.sgn+"\(self.tr.price)")
                    .font(.system(size: 50))
                    .foregroundColor(Color.white)
            }.padding(.horizontal)
        }
        .navigationBarTitle(Text(tr.dat), displayMode: .inline)
        .background(Color.orange)
    }
}

struct MapView: UIViewRepresentable {
    var coord: CLLocationCoordinate2D
    var dat:String
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
        let tab: [Pt] = [Pt(name: dat, location: .init(latitude: self.coord.latitude, longitude: self.coord.longitude))]
        let span = MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        let region = MKCoordinateRegion(center: coord, span: span)
        uiView.setRegion(region, animated: true)
        uiView.removeAnnotations(uiView.annotations)
        let newAnnot = tab.map { LAnnotation($0) }
        uiView.addAnnotations(newAnnot)
    }
}

struct Pt {
    var name: String
    var location: CLLocationCoordinate2D
}

struct Mark {
    var coordinates: Coordinates
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude)
    }
}

struct Coordinates: Hashable, Codable {
    var latitude: Double
    var longitude: Double
}
