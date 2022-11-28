class Api::V2::StripeWebhooksController < ApiController

	def update
    event = params['stripe_webhook']['type']

    if event == 'issuing_authorization.request'
      customerIDToGrab = params['data']['object']['card']['cardholder']['metadata']['stripeCustomerID'].strip
    elsif event == 'charge.succeeded' || event == 'charge.refunded'
      paymentIntentID = params['data']['object']['payment_intent']
      paymentIntentX = Stripe::PaymentIntent.retrieve(paymentIntentID)
      customerIDToGrab = params['data']['object']['customer'].strip
    end
    
    if customerIDToGrab.present?
      customerToGrab = Stripe::Customer.retrieve(customerIDToGrab)
      cardHolderID = customerToGrab['metadata']['cardHolder'].strip
      cardholder = Stripe::Issuing::Cardholder.retrieve(cardHolderID)
      loadSpendingMeta = cardholder['spending_controls']['spending_limits']
      percentToIssue = (1 - (customerToGrab['metadata']['percentToInvest'].to_f/100).to_f).to_f
    end

    case event
    when 'issuing_authorization.request'

      amountToCharge = params['data']['object']['pending_request']['amount']
      maxSpend = loadSpendingMeta&.first['amount']
      authToProcess = params['data']['object']['id']
      
      if amountToCharge <= maxSpend
        limitAfterAuth = maxSpend - amountToCharge
        if limitAfterAuth <= 500
          Stripe::Issuing::Authorization.decline(authToProcess)
          render json: {
            success: false
          }
        else
          Stripe::Issuing::Authorization.approve(authToProcess)
          Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: limitAfterAuth, interval: 'per_authorization']}})
        end
      else
        Stripe::Issuing::Authorization.decline(authToProcess)
        render json: {
          success: false
        }
      end
      return
    when 'charge.succeeded'
      chargeAmount = params['data']['object']['amount']
      chargeSourceType = params['data']['object']['payment_method_details']['type']
      stripeFee = chargeSourceType == 'card' ? (chargeAmount*0.029).to_i + 30 : (chargeAmount*0.008).to_i  
      amountToIssue = ((chargeAmount - stripeFee) * percentToIssue).to_i
      someCalAmount = loadSpendingMeta.empty? ? amountToIssue : loadSpendingMeta&.first['amount'].to_i + amountToIssue

      if customerToGrab['metadata']['percentToInvest'] != 100
        topUp = Stripe::Topup.create({
          amount: amountToIssue,
          currency: 'usd',
          description: "#{cardHolderID} approximate deposit: $#{(chargeAmount - stripeFee).to_f * 0.01}",
          statement_descriptor: 'Top-up',
          destination_balance: 'issuing',
          metadata: {cardHolder: cardHolderID, deposit: true}
        })
      else
        topUp = {"id" => 'tu_customDueToWebhook'}
      end

      case loadSpendingMeta&.empty?
      when true
        Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: amountToIssue, interval: 'per_authorization']}})
      when false 
        Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
      end
      
      Stripe::PaymentIntent.update(paymentIntentID, metadata: {topUp: topUp['id'], payout: false, percentToInvest: customerToGrab['metadata']['percentToInvest']})
      Stripe::Issuing::Card.update(customerToGrab['metadata']['issuedCard'].strip, status: 'active')
      return
    else
        puts "Unhandled event type: #{event}"
    end

	end
end

