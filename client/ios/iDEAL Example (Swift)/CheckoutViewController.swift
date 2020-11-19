//
//  CheckoutViewController.swift
//  iDEAL Example (Swift)
//
//  Created by Cameron Sabol on 12/4/19.
//  Copyright © 2019 Stripe. All rights reserved.
//

import UIKit

import Stripe

enum IDEALBank: Int, CaseIterable {
    case ABNAMRO = 0,
    ASNBank,
    Bunq,
    Handlesbanked,
    ING,
    Knab,
    Moneyou,
    Rabobank,
    RegioBank,
    SNSBank,
    TriodosBank,
    VanLoschot

    var displayName: String {
        switch self {
        case .ABNAMRO:
            return "ABN AMRO"
        case .ASNBank:
            return "ASN Bank"
        case .Bunq:
            return "Bunq"
        case .Handlesbanked:
            return "Handlesbanken"
        case .ING:
            return "ING"
        case .Knab:
            return "Knab"
        case .Moneyou:
            return "Moneyou"
        case .Rabobank:
            return "Rabobank"
        case .RegioBank:
            return "RegioBank"
        case .SNSBank:
            return "SNS Bank (De Volksbank)"
        case .TriodosBank:
            return "Triodos Bank"
        case .VanLoschot:
            return "Van Lanschot"
        }
    }

    var stripeCode: String {
        switch self {
        case .ABNAMRO:
            return "abn_amro"
        case .ASNBank:
            return "asn_bank"
        case .Bunq:
            return "bunq"
        case .Handlesbanked:
            return "handelsbanken"
        case .ING:
            return "ing"
        case .Knab:
            return "knab"
        case .Moneyou:
            return "moneyou"
        case .Rabobank:
            return "rabobank"
        case .RegioBank:
            return "regiobank"
        case .SNSBank:
            return "sns_bank"
        case .TriodosBank:
            return "triodos_bank"
        case .VanLoschot:
            return "van_lanschot"
        }
    }
}

/**
 * To run this app, you'll need to first run the sample server locally.
 * Follow the "How to run locally" instructions in the root directory's README.md to get started.
 * Once you've started the server, open http://localhost:4242 in your browser to check that the
 * server is running locally.
 * After verifying the sample server is running locally, build and run the app using the iOS simulator.
 */
let BackendUrl = "http://127.0.0.1:4242/"

class CheckoutViewController: UIViewController {

    private let nameField = UITextField()
    private let bankPicker = UIPickerView()
    private let payButton = UIButton()

    private var paymentIntentClientSecret: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        nameField.borderStyle = .roundedRect
        nameField.placeholder = "Full Name"

        bankPicker.dataSource = self
        bankPicker.delegate = self

        payButton.layer.cornerRadius = 5
        payButton.backgroundColor = .systemBlue
        payButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        payButton.setTitle("Pay", for: .normal)
        payButton.addTarget(self, action: #selector(pay), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [nameField, bankPicker, payButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leftAnchor.constraint(equalToSystemSpacingAfter: view.safeAreaLayoutGuide.leftAnchor, multiplier: 2),
            view.rightAnchor.constraint(equalToSystemSpacingAfter: stackView.safeAreaLayoutGuide.rightAnchor, multiplier: 2),
            stackView.topAnchor.constraint(equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor, multiplier: 2),
        ])
        startCheckout()

    }

    func displayAlert(title: String, message: String, restartDemo: Bool = false) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            if restartDemo {
                alert.addAction(UIAlertAction(title: "Restart demo", style: .cancel) { _ in
                    self.nameField.text = nil
                    self.bankPicker.selectRow(0, inComponent: 0, animated: false)
                    self.startCheckout()
                })
            }
            else {
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            }
            self.present(alert, animated: true, completion: nil)
        }
    }

    func startCheckout() {
        // Create a PaymentIntent by calling the sample server's /create-payment-intent endpoint.
        let url = URL(string: BackendUrl + "create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try? JSONSerialization.data(withJSONObject: ["items": 1, "currency": "eur"], options: [])

        let task = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            guard let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let clientSecret = json["clientSecret"] as? String,
                let stripePublishableKey = json["publishableKey"] as? String else {
                    let message = error?.localizedDescription ?? "Failed to decode response from server."
                    self?.displayAlert(title: "Error loading page", message: message)
                    return
            }
            self?.paymentIntentClientSecret = clientSecret
            // Configure the SDK with your Stripe publishable key so that it can make requests to the Stripe API
            Stripe.setDefaultPublishableKey(stripePublishableKey)
        })
        task.resume()
    }

    @objc
    func pay() {
        guard let paymentIntentClientSecret = paymentIntentClientSecret else {
            return;
        }

        // Collect iDEAL details on the client
        guard let selectedBank = IDEALBank(rawValue: bankPicker.selectedRow(inComponent: 0)) else {
            return
        }

        let iDEALParams = STPPaymentMethodiDEALParams()
        iDEALParams.bankName = selectedBank.stripeCode

        // Collect customer information
        let billingDetails = STPPaymentMethodBillingDetails()
        billingDetails.name = nameField.text

        let paymentIntentParams = STPPaymentIntentParams(clientSecret: paymentIntentClientSecret)

        paymentIntentParams.paymentMethodParams = STPPaymentMethodParams(iDEAL: iDEALParams,
                                                                         billingDetails: billingDetails,
                                                                         metadata: nil)
        paymentIntentParams.returnURL = "ideal-example://stripe-redirect"

        STPPaymentHandler.shared().confirmPayment(paymentIntentParams,
                                                    with: self)
        { (handlerStatus, paymentIntent, error) in
            switch handlerStatus {
            case .succeeded:
                self.displayAlert(title: "Payment successfully created",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: true)

            case .canceled:
                self.displayAlert(title: "Canceled",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: false)

            case .failed:
                self.displayAlert(title: "Payment failed",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: false)

            @unknown default:
                fatalError()
            }
        }



    }

}

extension CheckoutViewController: STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        return self
    }
}

extension CheckoutViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return IDEALBank.allCases.count
    }
}

extension CheckoutViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard let bank = IDEALBank(rawValue: row) else {
            return nil
        }

        return bank.displayName
    }
}

