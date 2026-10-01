import SwiftUI
import MapKit

// MKMapView works on iOS 16 and keeps Apple's attribution and interactive controls.
struct CampusMap: UIViewRepresentable {
    var locations: [Location] = Location.sampleLocations
    var onSelect: ((String) -> Void)?
    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.mapType = .mutedStandard
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 33.003, longitude: -7.618), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)), animated: false)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onSelect = onSelect
        let ids = locations.map(\.id)
        guard ids != context.coordinator.placeIDs else { return }
        context.coordinator.placeIDs = ids
        map.removeAnnotations(map.annotations)
        map.addAnnotations(locations.map { PlaceAnnotation(location: $0) })
        if locations.count == 2 { map.showAnnotations(map.annotations, animated: false) }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelect: ((String) -> Void)?
        var placeIDs: [String] = []
        init(onSelect: ((String) -> Void)?) { self.onSelect = onSelect }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PlaceAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "place")
            view.annotation = annotation; view.markerTintColor = UIColor(UniRideTheme.lime); view.glyphTintColor = .black
            view.glyphImage = UIImage(systemName: "graduationcap.fill"); view.canShowCallout = true
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) { if let place = view.annotation as? PlaceAnnotation { onSelect?(place.location.id) } }
    }
    final class PlaceAnnotation: NSObject, MKAnnotation {
        let location: Location
        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude) }
        var title: String? { location.name }
        init(location: Location) { self.location = location }
    }
}
