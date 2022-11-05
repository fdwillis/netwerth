class Api::V2::StripeChargesController < ApiController 
# #display stripe status of Charge to know if user has access or not

	def index
		authorize do |user|
			begin

				if user&.admin?
					deposits = []
					pullPaymentsToFilter = Stripe::PaymentIntent.list()['data'].map{|e| !e['metadata']['topUp'].blank? ? deposits.push(e) : next }.flatten
					available = Stripe::Issuing::Cardholder.list()['data'].map{|e| e['spending_controls']['spending_limits']}.flatten.sum
				else
					pullCardHolderx = Stripe::Issuing::Cardholder.retrieve(Stripe::Customer.retrieve(user&.stripeCustomerID)['metadata']['cardHolder'])
					deposits = Stripe::PaymentIntent.list(customer: user&.stripeCustomerID)['data']
					available = !pullCardHolderx['spending_controls']['spending_limits'].blank? ? pullCardHolderx['spending_controls']['spending_limits'].first['amount'] : 0
				end
				depositRejects = deposits.reject{|e| e['refunded'] == 'true'}.reject{|e| !e['metadata']['topUp'].present?}

				render json: {
					deposits: depositRejects,
					available: available,
					depositTotal: depositRejects.map(&:amount).flatten.sum ,
					invested: depositRejects.map{|e| (((e['amount'] - (e['amount']*0.029).to_i + 30)) - Stripe::Topup.retrieve(e['metadata']['topUp'])['amount'])}.flatten.sum  ,
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
				debugger
				stripeAmountX = User.stripeAmount(params[:amount].to_i)
				charge = Stripe::PaymentIntent.create({
				  amount: stripeAmountX + (stripeAmountX*0.029).to_i.round(-1) + 30,
				  currency: 'usd',
				  customer: user&.stripeCustomerID, #request to token endpoint?
				  description: "Netwerth Card Deposit: #{params[:amount].to_i * 0.01}",
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