class Api::V2::StripeChargesController < ApiController 
# #display stripe status of Charge to know if user has access or not

	def index
		authorize do |user|
			begin
				render json: {
					deposits: user.admin? ? Stripe::PaymentIntent.list()['data'] : Stripe::PaymentIntent.list(customer: user&.stripeCustomerID)['data'],
					success: true
				}
			rescue Stripe::StripeError => e
				render json: {
					error: e.error.message,
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
				stripeAmountX = User.stripeAmount(stripeAllowed[:amount].to_s)
				charge = Stripe::PaymentIntent.create({
				  amount: stripeAmountX + (stripeAmountX*0.029).to_i.round(-1) + 30,
				  currency: 'usd',
				  customer: user&.stripeCustomerID, #request to token endpoint?
				  description: "Netwerth Card Deposit: #{stripeAllowed[:amount].to_s * 0.01}",
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