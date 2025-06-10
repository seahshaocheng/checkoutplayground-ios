import SwiftUI
import AdyenEncryption

struct CardPaymentView: View {
    @State private var cardNumber = ""
    @State private var expiryMonth = ""
    @State private var expiryYear = ""
    @State private var cvc = ""
    @State private var message = ""

    private let publicKey = "10001|Your_Adyen_Public_Key" // Replace with yours
    
    func loadPublicKey() -> String? {
        if let path = Bundle.main.path(forResource: "secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["AdyenPublicKey"] as? String {
            return key
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Card Number", text: $cardNumber)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("MM", text: $expiryMonth)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("YY", text: $expiryYear)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("CVC", text: $cvc)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button("Pay Now") {
                encryptAndSend()
            }

            Text(message)
                .foregroundColor(.gray)
                .padding(.top)
        }
        .padding()
    }

    func encryptAndSend() {
        do {
            if let publicKey = loadPublicKey() {
                // use publicKey here
                let card = Card(
                    number: cardNumber,
                    securityCode: cvc,
                    expiryMonth: expiryMonth,
                    expiryYear: expiryYear
                )
                let encrypted = try CardEncryptor.encrypt(card: card, with: publicKey)

                guard
                       let encryptedNumber = encrypted.number,
                       let encryptedExpiryMonth = encrypted.expiryMonth,
                       let encryptedExpiryYear = encrypted.expiryYear,
                       let encryptedSecurityCode = encrypted.securityCode
                   else {
                       message = "Encryption failed: Missing encrypted values"
                       return
                   }

                   let payload: [String: String] = [
                       "encryptedCardNumber": encryptedNumber,
                       "encryptedExpiryMonth": encryptedExpiryMonth,
                       "encryptedExpiryYear": encryptedExpiryYear,
                       "encryptedSecurityCode": encryptedSecurityCode
                   ]
                
                print("Encrypted payload: \(payload)")
                //postToBackend(payload: payload)
            }
            else{
                message = "Failed to load public key"
            }

        } catch {
            message = "Encryption failed: \(error.localizedDescription)"
        }
    }

    func postToBackend(payload: [String: String]) {
        guard let url = URL(string: "https://your.backend.endpoint/api/checkout") else {
            message = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            message = "Encoding error: \(error.localizedDescription)"
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    message = "Network error: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    message = "Payment sent successfully!"
                } else {
                    message = "Payment failed."
                }
            }
        }.resume()
    }
}
