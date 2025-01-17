import Flutter
import UIKit
import SafariServices

/// Handle the call from channel `hyperpay`
///
/// Currently supported brands: VISA, MastrCard, MADA
public class SwiftHyperpayPlugin: NSObject, FlutterPlugin, SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var checkoutID:String = "";
    var provider:OPPPaymentProvider = OPPPaymentProvider(mode: OPPProviderMode.test)
    var brand:Brand = Brand.UNKNOWN;
    
    var cardHolder:String = "";
    var cardNumber:String = "";
    var expiryMonth:String = "";
    var expiryYear:String = "";
    var cvv:String = "";
    
    var transaction:OPPTransaction?;
    var paymentResult: FlutterResult?;
    var safariVC:SFSafariViewController?;
    var shopperResultURL:String = "";
    
    var paymentMode:String = "";
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "hyperpay", binaryMessenger: registrar.messenger())
        let instance = SwiftHyperpayPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    
    
    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        var handler:Bool = false
        
        // Compare the recieved URL with our URL type
        if url.scheme!.caseInsensitiveCompare(Bundle.main.bundleIdentifier! + ".payments") == .orderedSame {
            self.didReceiveAsynchronousPaymentCallback(result: self.paymentResult!)
            
            handler = true
        }
        
        return handler
    }
    
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.paymentResult!("canceled")
    }
    
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.paymentResult!("canceled")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.paymentResult = result
        
        if(call.method == "setup_service") {
            let args = call.arguments as! Dictionary<String, Any>
            paymentMode = args["mode"] as! String
            
            if(paymentMode == "LIVE") {
                self.provider.mode = OPPProviderMode.live
            }
            
            NSLog("Payment mode is set to \(paymentMode)")
            
            result(nil)
            
        } else if (call.method == "start_payment_transaction") {
            
            let args = call.arguments as! Dictionary<String, Any>
            
            let checkoutID = args["checkoutID"] as! String
            self.checkoutID = checkoutID
            
            
            let brand = args["brand"] as! String
            self.brand = Brand.init(rawValue: brand) ?? Brand.UNKNOWN
            
            // Collecting card details coming from the platform channel arguments
            let card = args["card"] as! Dictionary<String, Any>
            self.cardHolder = card["holder"] as! String
            self.cardNumber = card["number"] as! String
            self.expiryMonth = card["expiryMonth"] as! String
            self.expiryYear = card["expiryYear"] as! String
            self.cvv = card["cvv"] as! String
            
            switch self.brand {
            case Brand.UNKNOWN:
                result(
                    FlutterError(
                        code: "0.1",
                        message: "Please provide a valid brand",
                        details: ""
                    )
                )
            // Default goes for credit cards (VISA, MADA and MasterCard)
            default:
                // Check if credit card params are valid
                checkCreditCardValid(result: result)
                
                // If all are valid, start a transaction
                do {
                    let params = try OPPCardPaymentParams(
                        checkoutID: self.checkoutID,
                        paymentBrand: self.brand.rawValue,
                        holder: self.cardHolder,
                        number: self.cardNumber,
                        expiryMonth: self.expiryMonth,
                        expiryYear: self.expiryYear,
                        cvv: self.cvv
                    )
                    
                    params.shopperResultURL = Bundle.main.bundleIdentifier! + ".payments://result"
                    
                    self.transaction  = OPPTransaction(paymentParams: params)
                    self.provider.submitTransaction(self.transaction!) {
                        (transaction, error) in
                        guard let transaction = self.transaction else {
                            result(
                                FlutterError(
                                    code: "0.2",
                                    message: error!.localizedDescription,
                                    details: ""
                                )
                            )
                            
                            return
                        }
                        
                        if transaction.type == .asynchronous {
                            
                            self.safariVC = SFSafariViewController(url: self.transaction!.redirectURL!)
                            self.safariVC?.delegate = self;
                            UIApplication.shared.windows.first?.rootViewController!.present(self.safariVC!, animated: true, completion: nil)
                            
                        } else if transaction.type == .synchronous {
                            // Send request to your server to obtain transaction status
                            result("success")
                        } else {
                            // Handle the error
                            result(
                                FlutterError(
                                    code: "0.2",
                                    message: error?.localizedDescription,
                                    details: ""
                                )
                            )
                        }
                    }
                    
                } catch {
                    result(
                        FlutterError(
                            code: "0.2",
                            message: error.localizedDescription,
                            details: ""
                        )
                    )
                }
            }
            
        } else if (call.method == "start_stc_pay_transaction") {
            let args = call.arguments as! Dictionary<String, Any>
            
            let checkoutID = args["checkoutID"] as! String
            self.checkoutID = checkoutID
            
            do {
                let params = try OPPPaymentParams(checkoutID: self.checkoutID, paymentBrand: "STC_PAY")
                
                params.shopperResultURL = Bundle.main.bundleIdentifier! + ".payments://result"
                
                
                self.transaction  = OPPTransaction(paymentParams: params)
                self.provider.submitTransaction(self.transaction!) { (transaction, error) in
                    guard let transaction = self.transaction else {
                        // Handle invalid transaction, check error
                        result(
                            FlutterError(
                                code: "0.2",
                                message: error!.localizedDescription,
                                details: ""
                            )
                        )
                        return
                    }
                    
                    if transaction.type == .asynchronous {
                        self.safariVC = SFSafariViewController(url: self.transaction!.redirectURL!)
                        self.safariVC?.delegate = self;
                        UIApplication.shared.windows.first?.rootViewController!.present(self.safariVC!, animated: true, completion: nil)
                        
                    } else if transaction.type == .synchronous {
                        // Send request to your server to obtain transaction status
                        result("success")
                    } else {
                        // Handle the error
                        result(
                            FlutterError(
                                code: "0.2",
                                message: error?.localizedDescription,
                                details: ""
                            )
                        )
                    }
                }
                
            } catch {
                result(
                    FlutterError(
                        code: "0.2",
                        message: error.localizedDescription,
                        details: ""
                    )
                )
            }
            
            
        } else if (call.method == "start_apple_pay_transaction") {
            let args = call.arguments as! Dictionary<String, Any>
            
            let checkoutID = args["checkoutID"] as! String
            self.checkoutID = checkoutID
            
            let merchantId = args["apple_merchant_id"] as! String
            let language = args["language_code"] as! String
            let accentColorCode = args["accent_color_code"] as? String
            
            DispatchQueue.main.async {
                
                //Settings setup
                let checkoutSettings = OPPCheckoutSettings()
                
                checkoutSettings.language = language
                checkoutSettings.theme.style = .light
                
                if accentColorCode != nil, let color = UIColor(hexaRGB: accentColorCode!) {
                    checkoutSettings.theme.confirmationButtonColor = color
                    checkoutSettings.theme.confirmationButtonTextColor = .black
                }
                
                
                let paymentRequest = OPPPaymentProvider.paymentRequest(withMerchantIdentifier: merchantId, countryCode: "SA")
            
                
                if #available(iOS 12.1.1, *) {
                    paymentRequest.supportedNetworks = [ PKPaymentNetwork.mada,
                                                         PKPaymentNetwork.visa,
                                                         PKPaymentNetwork.masterCard ]
                } else {
                    // Fallback on earlier versions
                    paymentRequest.supportedNetworks = [ PKPaymentNetwork.visa,
                                                         PKPaymentNetwork.masterCard ]
                }
                
                checkoutSettings.applePayPaymentRequest = paymentRequest
                checkoutSettings.paymentBrands = ["APPLEPAY"]
                
                let checkoutProvider = OPPCheckoutProvider(paymentProvider: self.provider, checkoutID: checkoutID, settings: checkoutSettings)
                
                //Open Ready UI
                
                checkoutProvider?.presentCheckout(withPaymentBrand: "APPLEPAY",
                   loadingHandler: { (inProgress) in
                    // Executed whenever SDK sends request to the server or receives the answer.
                    // You can start or stop loading animation based on inProgress parameter.
                }, completionHandler: { (transaction, error) in
                    if error != nil {
                        // See code attribute (OPPErrorCode) and NSLocalizedDescription to identify the reason of failure.
                        result(
                            FlutterError(
                                code: "0.2",
                                message: error?.localizedDescription,
                                details: ""
                            )
                        )
                    } else {
                        guard let transaction = self.transaction else {
                            // Handle invalid transaction, check error
                            result(
                                FlutterError(
                                    code: "0.2",
                                    message: error!.localizedDescription,
                                    details: ""
                                )
                            )
                            return
                        }
                        
                        if transaction.type == .asynchronous {
                            self.safariVC = SFSafariViewController(url: self.transaction!.redirectURL!)
                            self.safariVC?.delegate = self;
                            UIApplication.shared.windows.first?.rootViewController!.present(self.safariVC!, animated: true, completion: nil)
                            
                        } else if transaction.type == .synchronous {
                            // Send request to your server to obtain transaction status
                            result("success")
                        } else {
                            // Handle the error
                            result(
                                FlutterError(
                                    code: "0.2",
                                    message: error?.localizedDescription,
                                    details: ""
                                )
                            )
                        }
                        
                    }
                }, cancelHandler: {
                    // Executed if the shopper closes the payment page prematurely.
                })
                
            }
                        
        }
        else {
            result(
                FlutterError(code: "", message: "Method not implemented", details: "Method name: \(call.method) not implemented")
            )
        }
    }
    
    @objc func didReceiveAsynchronousPaymentCallback(result: @escaping FlutterResult) {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name(rawValue: "AsyncPaymentCompletedNotificationKey"),
            object: nil
        )
        
        self.safariVC?.dismiss(animated: true) {
            DispatchQueue.main.async {
                result("success")
                
                // TODO: send notification to request payment status
            }
        }
        
    }
    
    /// This function checks the provided card params and return a PlatformException to Flutter if any are not valid.
    ///
    private func checkCreditCardValid(result: @escaping FlutterResult) {
        if !OPPCardPaymentParams.isNumberValid(self.cardNumber, luhnCheck: true) {
            result(
                FlutterError(
                    code: "1.1",
                    message: "Card number is not valid for brand \(self.brand)",
                    details: ""
                )
            )
        }
        else if !OPPCardPaymentParams.isHolderValid(self.cardHolder) {
            result(
                FlutterError(
                    code: "1.2",
                    message: "Holder name is not valid",
                    details: ""
                )
            )
        }
        else if !OPPCardPaymentParams.isExpiryMonthValid(self.expiryMonth) {
            result(
                FlutterError(
                    code: "1.3",
                    message: "Expiry month is not valid",
                    details: "The month should be in MM format"
                )
            )
        }
        else if !OPPCardPaymentParams.isExpiryYearValid(self.expiryYear) {
            result(
                FlutterError(
                    code: "1.4",
                    message: "Expiry year is not valid",
                    details: ""
                )
            )
        }
        else if !OPPCardPaymentParams.isCvvValid(self.cvv) {
            result(
                FlutterError(
                    code: "1.5",
                    message: "CVV is not valid",
                    details: ""
                )
            )
        }
    }
    
}

extension UIColor {
    convenience init?(hexaRGB: String, alpha: CGFloat = 1) {
        var chars = Array(hexaRGB.hasPrefix("#") ? hexaRGB.dropFirst() : hexaRGB[...])
        switch chars.count {
        case 3: chars = chars.flatMap { [$0, $0] }
        case 6: break
        default: return nil
        }
        self.init(red: .init(strtoul(String(chars[0...1]), nil, 16)) / 255,
                green: .init(strtoul(String(chars[2...3]), nil, 16)) / 255,
                 blue: .init(strtoul(String(chars[4...5]), nil, 16)) / 255,
                alpha: alpha)
    }

}
