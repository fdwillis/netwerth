class Api::V2::StripeCustomersController < ApiController 
#display stripe status of subscription to know if user has access or not

	def index
		admin do |user|
			bankAccounts = Stripe::Customer.list_sources(
			  user&.stripeCustomerID,
			  {object: 'bank_account'},
			)
			

			cards = Stripe::Customer.list_sources(
			  user&.stripeCustomerID,
			  {object: 'card'},
			)
			
			render json: {
				cards: cards,
				bank_accounts: bankAccounts,
				success: true,
			}
		end
	end

	def create
		authorize do |user|
			begin
				if user&.stripeCustomerID		
					updated = Stripe::Customer.update(user&.stripeCustomerID,source: stripeAllowed[:source])
				end
				
				user.update(email: stripeAllowed[:email], phone: stripeAllowed[:phone])

				render json: {
					success: true
				}
				return
				
			rescue Stripe::StripeError => e
				render json: {
					message: e,
					success: false
				}, status: 422
				
			rescue Exception => e
				
				render json: {
					message: e,
					success: false
				}, status: 422
			end
		end
	end

	def show
		authorize do |user|	
			begin
				customerToShow = Stripe::Customer.retrieve(user&.stripeCustomerID)

				bankAccounts = Stripe::Customer.list_sources(
				  user&.stripeCustomerID,
				  {object: 'bank_account'},
				)
				

				cards = Stripe::Customer.list_sources(
				  user&.stripeCustomerID,
				  {object: 'card'},
				)

				render json: {
					stripeCustomer: customerToShow,
					bankAccounts: bankAccounts['data'],
					cards: cards['data'],
					success: true
				}
				return
			rescue Stripe::StripeError => e
				
				render json: {
					error: e
				}, status: 422
			rescue Exception => e
				render json: {
					error: e
				}, status: 422
			end
		end
	end

	def update
		authorize do |user|
			if user&.stripeCustomerID		
				updated = Stripe::Customer.update(
					user&.stripeCustomerID,{
				   	source: stripeAllowed[:source],
				   	email: stripeAllowed[:email],
				   	phone: stripeAllowed[:phone],
				   	metadata: {percentToInvest: stripeAllowed[:percentToInvest]},
				  }
				)
			end
			
			user.update(email: stripeAllowed[:email], phone: stripeAllowed[:phone], percentToInvest: stripeAllowed[:percentToInvest])

			render json: {
				success: true
			}
			return
		end
	end

	private

	def stripeAllowed
		paramsClean = params.permit(:source, :name, :email, :phone, :connectAccount, :percentToInvest)
		return paramsClean.reject{|_, v| v.blank?}
	end

	def userAllowed
		paramsClean = params.permit(:accessPin)
		return paramsClean.reject{|_, v| v.blank?}
	end

	def individualInfoUpdate
		paramsClean = params.permit(:line1, :address, :postal_code, :country, :city, :state, :dob, :email, :first_name, :phone, :last_name, :ssn_last_4)
		return paramsClean.reject{|_, v| v.blank?}
	end

end