class Api::V2::StripeTokensController < ApiController 
	def create
		authorize do |user|
			begin
				if !cardTokenParams.blank?
					token = cardToken(cardTokenParams)
				else
					token = bankToken(bankTokenParams)
				end
				
				render json: {
					token: token,
					success: true
				}
			rescue Stripe::StripeError => e
				render json: {
					error: e.error.message,
					success: false
				}
			rescue Exception => e
				render json: {
					message: e,
					success: false
				}
			end
		end
	end

	private

	def cardTokenParams
		connparamsClean = params.permit(:number, :exp_year, :exp_month, :cvc)
		return connparamsClean.reject{|_, v| v.blank?}
	end

	def bankTokenParams
		connparamsClean = params.permit(:account_holder_name, :account_holder_type, :routing_number, :account_number)
		return connparamsClean.reject{|_, v| v.blank?}
	end
end