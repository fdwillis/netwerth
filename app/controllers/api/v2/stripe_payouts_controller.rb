class Api::V2::StripePayoutsController < ApiController 
# #display stripe status of Charge to know if user has access or not

	def index
		authorize do |user|
			begin
				pullPayouts = []
				payoutsArray = []
				Stripe::Topup.list({limit: 100})['data'].map{|d| (!d['metadata']['startDate'].blank? && d['metadata']['payoutSent'] == "false" && !d['metadata']['endDate'].blank?) ? (pullPayouts.append(d)) : next}.compact.flatten

				validateTopUps = []

				pullPayouts.each do |payout|
					investedAmountRunning = 0
					personalPayoutTotal = 0
					validPaymentIntents = Stripe::PaymentIntent.list({created: {lt: payout['metadata']['endDate'].to_time.to_i, gt: payout['metadata']['startDate'].to_time.to_i}})['data']
					validTopups = Stripe::Topup.list({created: {lt: payout['metadata']['endDate'].to_time.to_i, gt: payout['metadata']['startDate'].to_time.to_i}})['data']

					validTopups.each do |tup|
						if tup['metadata']['deposit'] == 'true'
							validateTopUps << tup
						end
					end

					payoutTotal = payout['amount']

					validPaymentIntents.each do |payint|
						if payint['customer'] == user&.stripeCustomerID
							amountForDeposit = payint['amount'] - (payint['amount']*0.029).to_i + 30
							investedAmount = amountForDeposit * (payint['metadata']['percentToInvest'].to_i * 0.01)
							investedAmountRunning += investedAmount
						end


					end
							
					returnOnInvestmentPercentage = (payoutTotal - (validPaymentIntents.map(&:amount).sum-validateTopUps.map(&:amount).sum).to_f)/(validPaymentIntents.map(&:amount).sum-validateTopUps.map(&:amount).sum).to_f
					# 6000 3000 -> (6000-3000)/started
					# 2000 4000 -> (2000-4000)/4000
					ownershipOfPayout = investedAmountRunning/((validPaymentIntents.map(&:amount).sum-validateTopUps.map(&:amount).sum).to_f)
					numberOfInvestors = validPaymentIntents.map(&:customer).uniq.size
					payoutsArray << {investedDuringPayout: investedAmountRunning, ownershipOfPayout: ownershipOfPayout, depositTotal: validPaymentIntents.map(&:amount).sum, asideToSpend: validateTopUps.map(&:amount).sum, deposits: validPaymentIntents, payoutID: payout['id'], personalPayoutTotal: personalPayoutTotal,returnOnInvestmentPercentage: returnOnInvestmentPercentage,payoutTotal: payoutTotal,numberOfInvestors: numberOfInvestors, }
					validateTopUps = []
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