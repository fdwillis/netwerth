class Api::V2::StripePayoutsController < ApiController 
# #display stripe status of Charge to know if user has access or not

	def index
		authorize do |user|
			begin
				pullPayouts = []
				payoutsArray = []
				Stripe::Topup.list({limit: 100})['data'].map{|d| (!d['metadata']['startDate'].blank? && !d['metadata']['endDate'].blank?) ? (pullPayouts.append(d)) : next}.compact.flatten

				validateTopUps = []
				groupPrincipleArray = []

				pullPayouts.each do |payout|
					investedAmountRunning = 0
					personalPayoutTotal = 0
					validPaymentIntents = Stripe::PaymentIntent.list({limit: 100, created: {lt: payout['metadata']['endDate'].to_time.to_i, gt: payout['metadata']['startDate'].to_time.to_i}})['data'].reject{|e| e['charges']['data'][0]['refunded'] == true}.reject{|e| e['charges']['data'][0]['captured'] == false}
					payoutTotal = payout['amount']

					validPaymentIntents.each do |payint|
						if payint['metadata']['percentToInvest'].to_i > 0 

							chargeXChargeAmount = User.paymentIntentNet(payint['id'])[:amount] * 0.01
							chargeXChargeNet = User.paymentIntentNet(payint['id'])[:net] * 0.01
							

							netForDeposit = chargeXChargeNet
							investedAmount = netForDeposit * (payint['metadata']['percentToInvest'].to_i * 0.01)
							investedAmountRunning += investedAmount
							groupPrincipleArray << {invested: (chargeXChargeNet * (payint['metadata']['percentToInvest'].to_i * 0.01).to_f), topUpAmount: payint['metadata']['topUp'].present? ? Stripe::Topup.retrieve(payint['metadata']['topUp'])['amount'] * 0.01 : 0 ,amount: chargeXChargeAmount,net: chargeXChargeNet, payint['customer'].to_sym => (chargeXChargeNet * (payint['metadata']['percentToInvest'].to_i * 0.01).to_f) }
						
						end


					end


					investedTotal = groupPrincipleArray.flatten.map{|e| e[:invested]}.compact.sum
					amountTotal = groupPrincipleArray.flatten.map{|e| e[:amount]}.compact.sum
					netTotal = groupPrincipleArray.flatten.map{|e| e[:net]}.compact.sum
					asideToSpend = groupPrincipleArray.flatten.map{|e| e[:topUpAmount]}.compact.sum
					returnOnInvestmentPercentage = ((payoutTotal * 0.01) - investedTotal)/investedTotal
					# 6000 3000 -> (6000-3000)/started
					# 2000 4000 -> (2000-4000)/4000
					ownershipOfPayout = investedAmountRunning/(investedTotal)
					numberOfInvestors = validPaymentIntents.map(&:customer).uniq.size
					payoutsArray << {investedTotal: investedTotal, investedDuringPayout: investedAmountRunning, ownershipOfPayout: ownershipOfPayout, amountTotal: amountTotal, netTotal: netTotal, asideToSpend: asideToSpend, deposits: validPaymentIntents, payoutID: payout['id'], personalPayoutTotal: personalPayoutTotal,returnOnInvestmentPercentage: returnOnInvestmentPercentage,payoutTotal: payoutTotal,numberOfInvestors: numberOfInvestors, }
					groupPrincipleArray = []
				end



				render json: {
					payoutsArray: payoutsArray,
					success: true
				}
			rescue Stripe::StripeError => e
				render json: {
					error: e,
					success: false
				}
			rescue Exception => e
				render json: {
					message: e
				}
			end	
		end
	end

	def create
		authorize do |user|
			begin
				stripeAmountX = User.stripeAmount(params[:amount].to_i)
				charge = Stripe::PaymentIntent.create({
				  amount: stripeAmountX + (stripeAmountX*0.029).to_i.round(-1) + 30,
				  currency: 'usd',
				  customer: user&.stripeCustomerID, #request to token endpoint?
				  description: "Netwerth Card Deposit: #{params[:amount].to_i}",
				  confirm: true
				})
				

				render json: {
					success: true,
					charge: charge
				}
			rescue Stripe::StripeError => e
				render json: {
					message: e.error.message
				}
			rescue Exception => e
				render json: {
					message: e
				}
			end
		end
	end

	private

	def stripeAllowed
		paramsClean = params.permit(:amount, :description, :connectAccount, :source, :inHouse)
		return paramsClean.reject{|_, v| v.blank?}
	end

	def cardTokenParams
		platparamsClean = params.permit(:number, :exp_year, :exp_month, :cvc)
		return platparamsClean.reject{|_, v| v.blank?}
	end
end