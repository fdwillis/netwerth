namespace :issueProfit do 
  
  task ifCleared: :environment do 
    pullPayouts = []
    # Stripe::Payout.list['data']
    Stripe::Topup.list['data'].map{|d| !d['metadata']['fromPayout'].blank? && d['metadata']['payoutSent'] == false.to_s ? (pullPayouts.append(d)) : next}.compact.flatten
    if !pullPayouts.blank?
      principleInvestedArray = []
      pullPayouts.each do |payout|
        if Date.today > DateTime.strptime(payout['expected_availability_date'].to_s,'%s').to_date + 1  
          payoutPull = Stripe::Payout.retrieve(payout['metadata']['fromPayout'])
          lastDateClearFromBatch = DateTime.strptime(payoutPull['created'].to_s,'%s').to_date - 3 # 7 for high risk, somehow build for this

          validPaymentIntents = Stripe::PaymentIntent.list({created: {lt: lastDateClearFromBatch.to_time.to_i}})['data']
          #grab all reinvestments
          
          validPaymentIntents.each do |paymentInt|
            if paymentForPayout(paymentInt['metadata']['payout'], paymentInt['metadata']['topUp'])
              customerX = Stripe::Customer.retrieve(paymentInt['customer'])
              cusPrinci = (paymentInt['amount'] - ((paymentInt['amount']*0.029).to_i + 30))
              principleInvestedArray << {customerX['metadata']['cardHolder'].to_sym => (cusPrinci * customerX['metadata']['percentToInvest'].to_i/100)}
            end
          end
          #map through reinvestments << principleInvestedArray

          allCurrentCardholders = Stripe::Issuing::Cardholder.list()['data']
          groupPrinciple = principleInvestedArray.map(&:values).flatten.sum

          allCurrentCardholders.each do |cardholder|
            cardholderSym = cardholder['id'].to_sym
            payoutToCardHolder = principleInvestedArray.flatten.any? {|h| h[cardholderSym].present?}

            case true
            when payoutToCardHolder

              investmentTotalForUserX = principleInvestedArray.flatten.map{|cardholderIDSym, ownership| cardholderIDSym[cardholderSym]}.compact.sum        
              ownership = (investmentTotalForUserX.to_f/groupPrinciple.to_f)
              amountToIssue = (payout['amount'] * ownership).round
              

              validPaymentIntents.each do |paymentInt|
                if paymentForPayout(paymentInt['metadata']['payout'], paymentInt['metadata']['topUp'])
                  Stripe::PaymentIntent.update(paymentInt['id'], metadata: {payout: true, fromPayout: payoutPull['id'], paidBy: payout['id'], amountPaid: (amountToIssue/validPaymentIntents.size)})
                end
              end
            
              loadSpendingMeta = cardholder['spending_controls']['spending_limits']
              someCalAmount = loadSpendingMeta.empty? ? amountToIssue : loadSpendingMeta&.first['amount'].to_i + amountToIssue
              
              Stripe::Issuing::Cardholder.update(cardholder['id'],{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
              Stripe::Topup.update(payout['id'], metadata: {payoutSent: true})
              
              customerX = Stripe::Customer.retrieve(Stripe::Issuing::Cardholder.retrieve(cardholder['id'])['metadata']['stripeCustomerID'])
              puts ">>>>>>phone:#{customerX['phone']}>>>>>>>>>>>>>>>>>>>>>Your Stock Market Debit Card balance has increased by $#{(amountToIssue*0.01).round}.\nThanks for investing with Netwerth!\nGet invested in the next round with another deposit!"
              textSent = User.twilioText(customerX['phone'], "Your balance has increased by $#{(amountToIssue*0.01).round(2)}")
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