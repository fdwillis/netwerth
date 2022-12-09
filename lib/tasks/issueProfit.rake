namespace :issueProfit do 
  
  task ifCleared: :environment do 
    pullPayouts = []
    
    Stripe::Topup.list({limit: 100})['data'].map{|d| d['metadata']['payoutSent'] == false.to_s ? (pullPayouts.append(d)) : next}.compact.flatten
    if !pullPayouts.blank?
      principleInvestedArray = []
      pullPayouts.each do |payoutForInvestors|
        if payoutForInvestors['status'] == 'succeeded'
          startDate = DateTime.strptime(payoutForInvestors['metadata']['startDate'].to_s,"%Y-%m-%d %H:%M").to_date
          endDate = DateTime.strptime(payoutForInvestors['metadata']['endDate'].to_s,"%Y-%m-%d %H:%M").to_date

          validPaymentIntents = Stripe::PaymentIntent.list({limit: 100, created: {lt: endDate.to_time.to_i, gt: startDate.to_time.to_i}})['data'].reject{|e| e['charges']['data'][0]['refunded'] == true}.reject{|e| e['charges']['data'][0]['captured'] == false}
          #grab all reinvestments
          validPaymentIntents.each do |paymentInt|
            if !paymentInt['metadata'].blank? && paymentInt['metadata']['percentToInvest'].to_i > 0 
              customerX = Stripe::Customer.retrieve(paymentInt['customer'])

              chargeXChargeAmount = User.paymentIntentNet(paymentInt['id'])[:amount] * 0.01
              chargeXChargeNet = User.paymentIntentNet(paymentInt['id'])[:net] * 0.01
              

              netForDeposit = chargeXChargeNet
              investedAmount = netForDeposit * (paymentInt['metadata']['percentToInvest'].to_i * 0.01)

              cusPrinci = (netForDeposit)
              principleInvestedArray << {customerX['metadata']['cardHolder'].to_sym => (investedAmount)}
            end
          end
          #map through reinvestments << principleInvestedArray -> Stripe::Payout.list['data'] with some meta

          allCurrentCardholders = Stripe::Issuing::Cardholder.list()['data']
          groupPrinciple = principleInvestedArray.map(&:values).flatten.sum

          allCurrentCardholders.each do |cardholder|
            cardholderSym = cardholder['id'].to_sym
            payoutToCardHolder = principleInvestedArray.flatten.any? {|h| h[cardholderSym].present?}

            if payoutToCardHolder
              customerX = Stripe::Customer.retrieve(Stripe::Issuing::Cardholder.retrieve(cardholder['id'])['metadata']['stripeCustomerID'])
              # test dividing amount issued by number of deposits per customer

              investmentTotalForUserX = principleInvestedArray.flatten.map{|cardholderIDSym, ownership| cardholderIDSym[cardholderSym]}.compact.sum        
              ownership = (investmentTotalForUserX.to_f/groupPrinciple.to_f)
              @amountToIssue = (payoutForInvestors['amount'] * ownership).round
              
              loadSpendingMeta = cardholder['spending_controls']['spending_limits']
              someCalAmount = loadSpendingMeta.empty? ? @amountToIssue : loadSpendingMeta&.first['amount'].to_i + @amountToIssue
              
              Stripe::Issuing::Cardholder.update(cardholder['id'],{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
              netwerthMessage = "Your Stock Market Debit Card balance has increased by $#{(@amountToIssue*0.01).round}.\nThank you for investing using the Stock Market Debit Card by Netwerth!\nGet invested in the next round with another deposit!"
              puts ">>>>>>phone:#{customerX['phone']}>>>>>>>>>>>>>>>>>>>>>#{netwerthMessage}"
              textSent = User.twilioText(customerX['phone'], "#{netwerthMessage}")
            end
          end

          validPaymentIntents.each do |paymentInt|
            loadMultiPayIDs = paymentInt['metadata']['paidBy'].blank? ? "#{payoutForInvestors['id']}, " : "#{paymentInt['metadata']['paidBy']}#{payoutForInvestors['id']}, "
            
            Stripe::PaymentIntent.update(paymentInt['id'], metadata: {payout: true, paidBy: loadMultiPayIDs})
          end
          Stripe::Topup.update(payoutForInvestors['id'], metadata: {payoutSent: true})
          
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