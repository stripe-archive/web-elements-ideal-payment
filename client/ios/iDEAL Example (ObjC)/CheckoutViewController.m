//
//  ViewController.m
//  iDEAL Example (ObjC)
//
//  Created by Cameron Sabol on 12/4/19.
//  Copyright © 2019 Stripe. All rights reserved.
//

#import "CheckoutViewController.h"

@import Stripe;

/**
* To run this app, you'll need to first run the sample server locally.
* Follow the "How to run locally" instructions in the root directory's README.md to get started.
* Once you've started the server, open http://localhost:4242 in your browser to check that the
* server is running locally.
* After verifying the sample server is running locally, build and run the app using the iOS simulator.
*/
NSString *const BackendUrl = @"http://127.0.0.1:4242/";

typedef NS_ENUM(NSInteger, IDEALBank) {
    IDEALBankABNAMRO,
    IDEALBankASNBank,
    IDEALBankBunq,
    IDEALBankHandelsbanken,
    IDEALBankING,
    IDEALBankKnab,
    IDEALBankMoneyou,
    IDEALBankRabobank,
    IDEALBankRegioBank,
    IDEALBankSNSBank,
    IDEALBankTriodosBank,
    IDEALBankVanLanschot,
};

static const NSInteger IDEALBankCount = 12;

NS_INLINE NSString * StripeCodeForiDEALBank(IDEALBank bank) {
    switch (bank) {
        case IDEALBankABNAMRO:
            return @"abn_amro";
        case IDEALBankASNBank:
            return @"asn_bank";
        case IDEALBankBunq:
            return @"bunq";
        case IDEALBankHandelsbanken:
            return @"handelsbanken";
        case IDEALBankING:
            return @"ing";
        case IDEALBankKnab:
            return @"knab";
        case IDEALBankMoneyou:
            return @"moneyou";
        case IDEALBankRabobank:
            return @"rabobank";
        case IDEALBankRegioBank:
            return @"regiobank";
        case IDEALBankSNSBank:
            return @"sns_bank";
        case IDEALBankTriodosBank:
            return @"triodos_bank";
        case IDEALBankVanLanschot:
            return @"van_lanschot";
    }
}


NS_INLINE NSString * DisplayNameForiDEALBank(IDEALBank bank) {
    switch (bank) {
        case IDEALBankABNAMRO:
            return @"ABN AMRO";
        case IDEALBankASNBank:
            return @"ASN Bank";
        case IDEALBankBunq:
            return @"Bunq";
        case IDEALBankHandelsbanken:
            return @"Handelsbanken";
        case IDEALBankING:
            return @"ING";
        case IDEALBankKnab:
            return @"Knab";
        case IDEALBankMoneyou:
            return @"Moneyou";
        case IDEALBankRabobank:
            return @"Rabobank";
        case IDEALBankRegioBank:
            return @"RegioBank";
        case IDEALBankSNSBank:
            return @"SNS Bank (De Volksbank)";
        case IDEALBankTriodosBank:
            return @"Triodos Bank";
        case IDEALBankVanLanschot:
            return @"Van Lanschot";
    }
}



@interface CheckoutViewController () <STPAuthenticationContext, UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, readonly) UIPickerView *bankPicker;
@property (nonatomic, readonly) UITextField *nameField;
@property (nonatomic, readonly) UIButton *payButton;

@property (nonatomic, copy) NSString *paymentIntentClientSecret;

@end

@implementation CheckoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    _nameField = [[UITextField alloc] init];
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.placeholder = @"Full Name";

    _bankPicker = [[UIPickerView alloc] init];
    self.bankPicker.dataSource = self;
    self.bankPicker.delegate = self;

    _payButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.payButton .layer.cornerRadius = 5;
    self.payButton .backgroundColor = [UIColor systemBlueColor];
    self.payButton .titleLabel.font = [UIFont systemFontOfSize:22];
    [self.payButton  setTitle:@"Pay" forState:UIControlStateNormal];
    [self.payButton  addTarget:self action:@selector(pay) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameField, self.bankPicker, self.payButton]];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.spacing = 20;
    [self.view addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        [stackView.leftAnchor constraintEqualToSystemSpacingAfterAnchor:self.view.safeAreaLayoutGuide.leftAnchor multiplier:2],
        [self.view.rightAnchor constraintEqualToSystemSpacingAfterAnchor:stackView.safeAreaLayoutGuide.rightAnchor multiplier:2],
        [stackView.topAnchor constraintEqualToSystemSpacingBelowAnchor:self.view.safeAreaLayoutGuide.topAnchor multiplier:2],
    ]];

    [self startCheckout];

}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message restartDemo:(BOOL)restartDemo {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        if (restartDemo) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Restart demo" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self.nameField setText:nil];
                [self.bankPicker selectRow:0 inComponent:0 animated:NO];
                [self startCheckout];
            }]];
        } else {
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        }
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)startCheckout {
    // Create a PaymentIntent by calling the sample server's /create-payment-intent endpoint.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@create-payment-intent", BackendUrl]];
    NSMutableURLRequest *request = [[NSURLRequest requestWithURL:url] mutableCopy];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{@"items": @1, @"currency": @"eur"} options:0 error:NULL]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
        NSError *error = requestError;
        if (data != nil) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (error != nil || httpResponse.statusCode != 200 || json[@"publishableKey"] == nil) {
                [self displayAlertWithTitle:@"Error loading page" message:error.localizedDescription ?: @"" restartDemo:NO];
            } else {
                self.paymentIntentClientSecret = json[@"clientSecret"];
                NSString *stripePublishableKey = json[@"publishableKey"];
                // Configure the SDK with your Stripe publishable key so that it can make requests to the Stripe API
                [StripeAPI setDefaultPublishableKey:stripePublishableKey];
            }
        } else {
            [self displayAlertWithTitle:@"Error loading page" message:error.localizedDescription ?: @"" restartDemo:NO];

        }
    }];
    [task resume];
}

- (void)pay {

    NSInteger selectedRow = [self.bankPicker selectedRowInComponent:0];
    if (selectedRow < 0 || selectedRow >= IDEALBankCount) {
        return;
    }

    // Collect iDEAL details on the client
    IDEALBank selectedBank = (IDEALBank)selectedRow;
    STPPaymentMethodiDEALParams *iDEALParams = [[STPPaymentMethodiDEALParams alloc] init];
    iDEALParams.bankName = StripeCodeForiDEALBank(selectedBank);

    // Collect customer information
    STPPaymentMethodBillingDetails *billingDetails = [[STPPaymentMethodBillingDetails alloc] init];
    billingDetails.name = self.nameField.text;

    STPPaymentIntentParams *paymentIntentParams = [[STPPaymentIntentParams alloc] initWithClientSecret:self.paymentIntentClientSecret];

    paymentIntentParams.paymentMethodParams = [STPPaymentMethodParams paramsWithiDEAL:iDEALParams
                                                                           billingDetails:billingDetails
                                                                                 metadata:nil];

    paymentIntentParams.returnURL = @"ideal-example://stripe-redirect";
    [[STPPaymentHandler sharedHandler] confirmPayment:paymentIntentParams
                            withAuthenticationContext:self
                                           completion:^(STPPaymentHandlerActionStatus handlerStatus, STPPaymentIntent * handledIntent, NSError * _Nullable handlerError) {
        switch (handlerStatus) {
            case STPPaymentHandlerActionStatusFailed:
                [self displayAlertWithTitle:@"Payment failed" message:handlerError.localizedDescription ?: @"" restartDemo:NO];
                break;
            case STPPaymentHandlerActionStatusCanceled:
                [self displayAlertWithTitle:@"Canceled" message:handlerError.localizedDescription ?: @"" restartDemo:NO];
                break;
            case STPPaymentHandlerActionStatusSucceeded:
                [self displayAlertWithTitle:@"Payment successfully created" message:handlerError.localizedDescription ?: @"" restartDemo:YES];
                break;
        }
    }];
}

#pragma mark - STPAuthenticationContext
- (UIViewController *)authenticationPresentingViewController {
    return self;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return IDEALBankCount;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row < 0 || row >= IDEALBankCount) {
        return @"";
    }
    return DisplayNameForiDEALBank((IDEALBank)row);
}

@end
