class Api::V2::StripePayoutsController < ApiController 
# #display stripe status of Charge to know if user has access or not

	def index
		authorize do |user|
			begin
				payoutArray = []
				if user&.admin?
				else
					pullPaymentsToFilter = Stripe::PaymentIntent.list(customer: user&.stripeCustomerID)['data'].map{|e| (!e['metadata']['paidBy'].blank? && e['metadata']['payout'] == 'true') ? payoutArray.push(e) : next }.flatten
				end

				debugger

				payoutArray.map{|e| e['amountPaid']}.sum

				render json: {
					payouts: payoutArray,
					returnOnInvestmentPercentage: returnOnInvestmentPercentage,
					returnOnInvestmentNumber: returnOnInvestmentNumber,
					depositTotal: payoutArray.map{|e| e['amount']}.sum,
					payoutTotal: payoutTotal,
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