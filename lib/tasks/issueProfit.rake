namespace :issueProfit do 
  
  task ifCleared: :environment do 
    pullPayouts = []
    # Stripe::Payout.list['data']
    Stripe::Topup.list['data'].map{|d| !d['metadata']['fromPayout'].blank? && d['metadata']['payoutSent'] == false.to_s ? (pullPayouts.append(d)) : next}.compact.flatten
    if !pullPayouts.blank?
      principleInvested = []
      pullPayouts.each do |payout|
        if Date.today > DateTime.strptime(payout['expected_availability_date'].to_s,'%s').to_date + 1  
          payoutPull = Stripe::Payout.retrieve(payout['metadata']['fromPayout'])
          amountInvested = payoutPull['amount']
          lastDateClearFromBatch = DateTime.strptime(payoutPull['created'].to_s,'%s').to_date - 3 # 7 for high risk, somehow build for this

          validPaymentIntents = Stripe::PaymentIntent.list({created: {lt: lastDateClearFromBatch.to_time.to_i}})['data']
          
          validPaymentIntents.each do |paymentInt|
            if paymentForPayout(paymentInt['metadata']['payout'], paymentInt['metadata']['topUp'])
              customerX = Stripe::Customer.retrieve(paymentInt['customer'])
              cusPrinci = (paymentInt['amount'] - ((paymentInt['amount']*0.029).to_i + 30))
              principleInvested << {customerX['metadata']['cardHolder'].to_sym => cusPrinci}
            end
          end

          allCurrentCardholders = Stripe::Issuing::Cardholder.list()['data']

          allCurrentCardholders.each do |cardholder|
            cardholderSym = cardholder['id'].to_sym
            payoutToCardHolder = principleInvested.flatten.any? {|h| h[cardholderSym].present?}

            case true
            when payoutToCardHolder

              investmentTotal = principleInvested.flatten.map{|cardholderIDSym, ownership| cardholderIDSym[cardholderSym]}.compact.sum        
              
              ownership = investmentTotal/amountInvested # check this is a stripe friendly integer as expected
              loadSpendingMeta = cardholder['spending_controls']['spending_limits']
              amountToIssue = payout['amount'] * ownership
              
              someCalAmount = loadSpendingMeta.empty? ? amountToIssue : loadSpendingMeta&.first['amount'].to_i + amountToIssue

              # send text to admin and investor of depsots made 
              
            
              Stripe::Issuing::Cardholder.update(cardholder['id'],{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
              Stripe::Topup.update(payout['id'], metadata: {payoutSent: true})

              validPaymentIntents.each do |paymentInt|
                if paymentForPayout(paymentInt['metadata']['payout'], paymentInt['metadata']['topUp'])
                  customerX = Stripe::Customer.retrieve(paymentInt['customer'])

                  Stripe::PaymentIntent.update(paymentInt['id'], metadata: {payout: true, payoutAmount: amountToIssue, fromPayout: payoutPull['id']})
                end
              end
            
            end
          end
        else
          puts "waiting to clear: alert payouts coming soon with expected deposit"
        end
      end
    else
      puts "Nothing to Run"
    end

    puts "-DONE-"
  end
end



def paymentForPayout(metaPayout, metaTopup)
  !metaPayout.blank? && metaPayout == false.to_s && !metaTopup.blank?
end