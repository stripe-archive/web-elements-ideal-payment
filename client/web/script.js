// A reference to Stripe.js
var stripe;

var orderData = {
  items: [{ id: "photo-subscription" }],
  currency: "eur" // iDEAL only accepts EUR
};

fetch("/create-payment-intent", {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify(orderData)
})
  .then(function(result) {
    return result.json();
  })
  .then(function(data) {
    return setupElements(data);
  })
  .then(function({ stripe, card, ideal, clientSecret }) {
    document.querySelector("form").addEventListener("submit", function(evt) {
      evt.preventDefault();
      // Initiate payment when the submit button is clicked
      pay(stripe, card, ideal, clientSecret);
    });
    document.querySelectorAll(".sr-pm-button").forEach(function(el) {
      el.addEventListener("click", function(evt) {
        var id = evt.target.id;
        if (id === "card-button") {
          showElement("#card-element");
          hideElement("#ideal-bank-element");
          document.querySelector("#card-button").classList.add("selected");
          document.querySelector("#ideal-button").classList.remove("selected");
        } else {
          hideElement("#card-element");
          showElement("#ideal-bank-element");
          document.querySelector("#card-button").classList.remove("selected");
          document.querySelector("#ideal-button").classList.add("selected");
        }
      });
    });
  });

// Set up Stripe.js and Elements to use in checkout form
var setupElements = function(data) {
  stripe = Stripe(data.publishableKey, { betas: ["ideal_pm_beta_1"] });
  var elements = stripe.elements();
  var style = {
    base: {
      color: "#32325d",
      fontFamily: '"Helvetica Neue", Helvetica, sans-serif',
      fontSmoothing: "antialiased",
      fontSize: "16px",
      "::placeholder": {
        color: "#aab7c4"
      },
      padding: "10px 12px"
    },
    invalid: {
      color: "#fa755a",
      iconColor: "#fa755a"
    }
  };

  var card = elements.create("card", { style: style });
  card.mount("#card-element");

  var idealBank = elements.create("idealBank", { style: style });
  idealBank.mount("#ideal-bank-element");

  return {
    stripe: stripe,
    card: card,
    ideal: idealBank,
    clientSecret: data.clientSecret
  };
};

/*
 * Calls stripe.handleCardPayment which creates a pop-up modal to
 * prompt the user to enter extra authentication details without leaving your page
 */
var pay = function(stripe, card, ideal, clientSecret) {
  changeLoadingState(true);

  const selectedPaymentMethod = document.querySelector(
    ".sr-pm-button.selected"
  );

  switch (selectedPaymentMethod.id) {
    case "card-button":
      payWithCard(stripe, clientSecret, card);
      return;
    case "ideal-button":
      payWithiDEAL(stripe, clientSecret, ideal);
      return;
    default:
      console.log("Error: no payment method selected");
  }
};

var payWithCard = function(stripe, clientSecret, card) {
  // Initiate the payment.
  // If authentication is required, confirmCardPayment will automatically display a modal
  stripe
    .confirmCardPayment(clientSecret, { payment_method: { card: card } })
    .then(function(result) {
      if (result.error) {
        // Show error to your customer
        showError(result.error.message);
      } else {
        // The payment has been processed!
        orderComplete(clientSecret);
      }
    });
};

var payWithiDEAL = function(stripe, clientSecret, ideal) {
  // Initiate the payment.
  // confirmIdealPayment will redirect the customer to their bank
  stripe
    .confirmIdealPayment(clientSecret, {
      payment_method: {
        ideal: ideal
      },
      return_url: `${window.location.href}complete`
    })
    .then(function(result) {
      if (result.error) {
        // Show error to your customer
        showError(result.error.message);
      } else {
        // The payment has been processed!
        orderComplete(clientSecret);
      }
    });
};

/* ------- Post-payment helpers ------- */

/* Shows a success / error message when the payment is complete */
var orderComplete = function(clientSecret) {
  stripe.retrievePaymentIntent(clientSecret).then(function(result) {
    var paymentIntent = result.paymentIntent;
    var paymentIntentJson = JSON.stringify(paymentIntent, null, 2);

    document.querySelector(".sr-payment-form").classList.add("hidden");
    document.querySelector("pre").textContent = paymentIntentJson;
    document.querySelector(".sr-picker").classList.add("hidden");
    document.querySelector(".sr-result").classList.remove("hidden");
    setTimeout(function() {
      document.querySelector(".sr-result").classList.add("expand");
    }, 200);

    changeLoadingState(false);
  });
};

var showError = function(errorMsgText) {
  changeLoadingState(false);
  var errorMsg = document.querySelector(".sr-field-error");
  errorMsg.textContent = errorMsgText;
  setTimeout(function() {
    errorMsg.textContent = "";
  }, 4000);
};

// Show a spinner on payment submission
var changeLoadingState = function(isLoading) {
  if (isLoading) {
    showElement("#spinner");
    hideElement("#button-text");
    document.querySelector("#submit").disabled = true;
  } else {
    hideElement("#spinner");
    showElement("#button-text");
    document.querySelector("#submit").disabled = false;
  }
};

var showElement = function(query) {
  document.querySelector(query).classList.remove("hidden");
};

var hideElement = function(query) {
  document.querySelector(query).classList.add("hidden");
};
