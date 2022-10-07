namespace :issueProfit do 
  
  task ifCleared: :environment do 
    pullPayouts = []
    # Stripe::Payout.list['data']
    Stripe::Topup.list['data'].map{|d| !d['metadata']['fromPayout'].blank? && d['metadata']['payoutSent'] == false.to_s ? (pullPayouts.append(d)) : next}.compact.flatten
    principleInvested = []
    if !pullPayouts.blank?
      pullPayouts.each do |payout|
        payoutPull = Stripe::Payout.retrieve(payout['metadata']['fromPayout'])
        payoutInitiatedDate = DateTime.strptime(payoutPull['created'].to_s,'%s').to_date - 3
        amountInvested = payoutPull['amount']
        if pullPayouts.count == 1
          dateToStartFrom = "09-01-2022"
        else


        end
        
        validPaymentIntents = Stripe::PaymentIntent.list({created: {gte: dateToStartFrom.to_time.to_i, lt: payoutInitiatedDate.to_time.to_i}})['data']
        validPaymentIntents.each do |paymentInt|
          customerX = Stripe::Customer.retrieve(paymentInt['customer'])
          cusPrinci = (paymentInt['amount'] - ((paymentInt['amount']*0.029).to_i + 30))
          principleInvested << {customerX['metadata']['cardHolder'].to_sym => cusPrinci}
        end


        allCurrentCardholders = Stripe::Issuing::Cardholder.list()['data']

        allCurrentCardholders.each do |cardholder|
          cardholderSym = cardholder['id'].to_sym
          payoutToCardHolder = principleInvested.flatten.any? {|h| h[cardholderSym].present?}

          case true
          when payoutToCardHolder
            investmentTotal = principleInvested.flatten.map{|cardholderIDSym, ownership| cardholderIDSym[cardholderSym]}.sum        
            
            ownership = investmentTotal/amountInvested
            loadSpendingMeta = cardholder['spending_controls']['spending_limits']
            amountToIssue = payout['amount'] * ownership
            someCalAmount = loadSpendingMeta.empty? ? amountToIssue : loadSpendingMeta&.first['amount'].to_i + amountToIssue
            # send text to admin the day before this runs
            if Date.today <= DateTime.strptime(payout['expected_availability_date'].to_s,'%s').to_date + 1
              Stripe::Issuing::Cardholder.update(cardholder['id'],{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
              Stripe::Topup.update(payout['id'], metadata: {payoutSent: true})
            else
              puts "waiting to clear"
            end
          end


        end
      end
    else
      puts "Nothing to Run"
    end

    puts "Profits Deposited"
  end
end