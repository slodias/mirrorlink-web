import Foundation
import Combine

struct UPnPService {
    let type: String
    let controlURL: String
}

struct UPnPDevice {
    let name: String
    let deviceType: String
    let services: [UPnPService]
}

private final class DeviceDescriptionReader: NSObject, XMLParserDelegate {
    var name = ""
    var deviceType = ""
    var services: [UPnPService] = []
    private var currentElement = ""
    private var buffer = ""
    private var inService = false
    private var serviceType = ""
    private var serviceControl = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        buffer = ""
        if elementName == "service" {
            inService = true
            serviceType = ""
            serviceControl = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "friendlyName":
            if name.isEmpty { name = text }
        case "deviceType":
            if deviceType.isEmpty { deviceType = text }
        case "serviceType":
            if inService { serviceType = text }
        case "controlURL":
            if inService { serviceControl = text }
        case "service":
            if !serviceType.isEmpty && !serviceControl.isEmpty {
                services.append(UPnPService(type: serviceType,
                                            controlURL: serviceControl))
            }
            inService = false
        default:
            break
        }
        currentElement = ""
        buffer = ""
    }
}

private struct DescriptionHit {
    let url: URL
    let data: Data
}

private func parseDescription(_ data: Data) -> UPnPDevice? {
    let reader = DeviceDescriptionReader()
    let parser = XMLParser(data: data)
    parser.delegate = reader
    guard parser.parse() else { return nil }
    guard !reader.name.isEmpty || !reader.deviceType.isEmpty || !reader.services.isEmpty
    else { return nil }
    return UPnPDevice(name: reader.name.isEmpty ? "Bilinmeyen cihaz" : reader.name,
                      deviceType: reader.deviceType, services: reader.services)
}

private func privateIPv4(_ input: String) -> Bool {
    let chunks = input.split(separator: ".", omittingEmptySubsequences: false)
    guard chunks.count == 4 else { return false }
    var numbers: [Int] = []
    for chunk in chunks {
        guard let n = Int(chunk), n >= 0, n <= 255 else { return false }
        numbers.append(n)
    }
    return numbers[0] == 10 ||
        (numbers[0] == 172 && (16...31).contains(numbers[1])) ||
        (numbers[0] == 192 && numbers[1] == 168)
}

@MainActor
final class DLNAProbe: ObservableObject {
    @Published var isBusy = false
    @Published var status = "TV IP adresini girerek teste başla."
    @Published var details = "Henüz bağlantı denenmedi."
    @Published var deviceName: String?
    @Published var avTransportURL: URL?

    private var serviceType: String?

    func probe(ip: String, manualURL: String) async {
        let ip = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard privateIPv4(ip) else {
            status = "Geçerli bir yerel ağ IPv4 adresi gir (örn. 192.168.1.25)."
            return
        }

        var urls: [URL] = []
        let custom = manualURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            guard let url = URL(string: custom), url.scheme == "http",
                  url.host == ip else {
                status = "Özel URL http:// ile başlamalı ve girilen TV IP'sini kullanmalı."
                return
            }
            urls = [url]
        } else {
            let candidates = [
                "http://\(ip):7676/",
                "http://\(ip):7676/description.xml",
                "http://\(ip):9197/",
                "http://\(ip):9197/description.xml",
                "http://\(ip):5000/description.xml",
                "http://\(ip):49152/description.xml",
                "http://\(ip):49152/rootDesc.xml",
                "http://\(ip):8080/description.xml",
                "http://\(ip):49494/description.xml"
            ]
            urls = candidates.compactMap(URL.init(string:))
        }

        isBusy = true
        defer { isBusy = false }
        deviceName = nil
        avTransportURL = nil
        serviceType = nil
        status = "TV'nin DLNA açıklama sayfaları deneniyor…"
        details = "Denenen adres sayısı: \(urls.count). Bunlar olası adreslerdir; her TV aynı portları kullanmaz."

        let hits: [DescriptionHit] = await withTaskGroup(of: DescriptionHit?.self) { group in
            for url in urls {
                group.addTask {
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 3
                    config.timeoutIntervalForResource = 4
                    let session = URLSession(configuration: config)
                    defer { session.invalidateAndCancel() }
                    do {
                        let (data, response) = try await session.data(from: url)
                        guard let http = response as? HTTPURLResponse,
                              http.statusCode == 200, data.count < 500_000 else { return nil }
                        return DescriptionHit(url: url, data: data)
                    } catch {
                        return nil
                    }
                }
            }
            var found: [DescriptionHit] = []
            for await response in group {
                if let response { found.append(response) }
            }
            return found
        }

        var descriptions: [(DescriptionHit, UPnPDevice)] = []
        for hit in hits {
            if let device = parseDescription(hit.data) {
                descriptions.append((hit, device))
            }
        }
        guard !descriptions.isEmpty else {
            status = "DLNA cihaz açıklaması bulunamadı."
            details = "Bu sonuç DLNA'nın olmadığı anlamına gelmez. TV başka bir port kullanıyor olabilir veya yalnızca MediaServer işlevi sunabilir. SSDP keşfi sonraki sürümde değerlendirilecek."
            return
        }

        let selected = descriptions.first(where: {
            $0.1.services.contains(where: { $0.type.contains(":AVTransport:") })
        }) ?? descriptions[0]
        let hit = selected.0
        let device = selected.1
        deviceName = device.name
        let types = device.services.map(\.type)
        details = "Açıklama: \(hit.url.absoluteString)\nCihaz tipi: \(device.deviceType)\nServisler:\n" + types.joined(separator: "\n")
        if let service = device.services.first(where: {
            $0.type.contains(":AVTransport:")
        }), let control = URL(string: service.controlURL, relativeTo: hit.url)?.absoluteURL,
           control.scheme == "http", control.host == ip {
            avTransportURL = control
            serviceType = service.type
            status = "AVTransport servisi bulundu. Oynatma durumu sorgulanabilir."
        } else {
            status = "DLNA cihaz açıklaması bulundu; AVTransport kontrol servisi görünmüyor."
        }
    }

    func checkTransportStatus() async {
        guard let url = avTransportURL, let serviceType else { return }
        isBusy = true
        defer { isBusy = false }
        status = "AVTransport durumu sorgulanıyor…"
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body><u:GetTransportInfo xmlns:u="\(serviceType)"><InstanceID>0</InstanceID></u:GetTransportInfo></s:Body>
        </s:Envelope>
        """
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#GetTransportInfo\"", forHTTPHeaderField: "SOAPAction")
        request.httpBody = Data(body.utf8)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                status = "Geçersiz HTTP yanıtı."
                return
            }
            if http.statusCode == 200 {
                status = "AVTransport yanıt verdi (HTTP 200)."
            } else {
                status = "AVTransport sunucusu HTTP \(http.statusCode) döndürdü."
            }
            details += "\nGetTransportInfo HTTP: \(http.statusCode)\nYanıt: " +
                String(decoding: data.prefix(700), as: UTF8.self)
        } catch {
            status = "AVTransport sorgusu başarısız: \(error.localizedDescription)"
        }
    }
}
