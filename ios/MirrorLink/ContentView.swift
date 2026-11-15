import SwiftUI

struct ContentView: View {
    @StateObject private var model = DLNAProbe()
    @State private var address = ""
    @State private var descriptionURL = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("MirrorLink", systemImage: "tv.and.hifispeaker.fill")
                            .font(.largeTitle.bold())
                        Text("Samsung UE40H6470 • DLNA bağlantı testi")
                            .foregroundStyle(.secondary)
                        Text("Bu sürüm ekran yansıtmaz. Önce TV'nin DLNA MediaRenderer ve AVTransport kontrolünü destekleyip desteklemediğini inceler.")
                            .font(.callout)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("TV'nin IP adresi").font(.headline)
                        TextField("Örn. 192.168.1.25", text: $address)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Text("TV: Menü → Ağ → Ağ Durumu → IP Ayarları. Telefon ve TV aynı Wi-Fi ağında olmalı.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        DisclosureGroup("Gelişmiş: DLNA cihaz açıklaması URL'si") {
                            TextField("http://192.168.1.25:port/description.xml",
                                      text: $descriptionURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            Text("İsteğe bağlıdır. Otomatik adres denemeleri başarısızsa bilinen bir cihaz açıklama URL'si girebilirsin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task { await model.probe(ip: address, manualURL: descriptionURL) }
                        } label: {
                            if model.isBusy {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Label("TV bağlantısını test et", systemImage: "network")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test sonucu").font(.headline)
                        Text(model.status)
                            .textSelection(.enabled)
                        if let name = model.deviceName {
                            Label(name, systemImage: "tv")
                        }
                        if let control = model.avTransportURL {
                            Text("AVTransport: \(control.absoluteString)")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Button("Oynatma durumunu sorgula (salt okunur)") {
                                Task { await model.checkTransportStatus() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy)
                        }
                        Text(model.details)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    Text("Bu uygulama Miracast değildir. Otomatik SSDP keşfi bu sürümde yoktur; iOS çoklu yayın (multicast) yetkisi ayrıca gerektirebilir. Ekran yayını sonraki geliştirme aşamasıdır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("DLNA Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
