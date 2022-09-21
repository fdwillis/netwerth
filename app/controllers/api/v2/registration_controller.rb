class Api::V2::RegistrationController < ApiController 

  def new
  end

	def create
		debugger
    begin
      if buildAddress && buildContact
	    	if params['password'] == params['password_confirmation']
	        if findType == 'company' || findType == 'individual'
	          cardHolderNew = Stripe::Issuing::Cardholder.create({
	            type: params['type'],
	            name: params['legalName'],
	            email: params['email'],
	            phone_number: params['phone_number'],
	            billing: {
	              address: {
	                line1: params['line1'],
	                city: params['city'],
	                state: params['state'],
	                country: "US",
	                postal_code: params['postal_code'],
	              },
	            },
	          })

	          cardNew = Stripe::Issuing::Card.create({
	            cardholder: cardHolderNew['id'],
	            currency: 'usd',
	            type: 'physical',
	            spending_controls: {spending_limits: {}},
	            status: 'active',
	            shipping: {
	              name: params['legalName'],
	              address: {
	                line1: params['line1'],
	                city: params['city'],
	                state: params['state'],
	                country: "US",
	                postal_code: params['postal_code'],
	              }
	            }
	          })

	          customerViaStripe = Stripe::Customer.create({
	            description: 'Netwerth Debit Card Holder',
	            name: params['legalName'],
	            email: params['email'],
	            phone: params['phone_number'],
	            address: {
	              line1: params['line1'],
	              city: params['city'],
	              state: params['state'],
	              country: "US",
	              postal_code: params['postal_code'],
	            },
	            metadata: {
	              cardHolder: cardHolderNew['id'],
	              issuedCard: cardNew['id'],
	              percentToInvest: params['percentToInvest'],
	            }
	          })

	          Stripe::Issuing::Cardholder.update(cardHolderNew['id'], metadata: {stripeCustomerID: customerViaStripe['id']})
	          # make user account so they can access the app and make transfers

	          @user = User.create!(percentToInvest: params['percentToInvest'], uuid: SecureRandom.uuid[0..7], stripeCustomerID: customerViaStripe['id'], appName: 'netwethCard', accessPin: 'customer', email: params['email'], password: params['password'], password_confirmation: params['password_confirmation'], referredBy: params['referredBy'].nil? ? "admin" : params['referredBy'], phone: params['phone'])

	          @user.update(authentication_token: @user.generate_authentication_token!)

	          render json: {success: true, user: @user}
					  
	        else
	          render json: {message: "Type needed", success: false}
	        end
        else
       		render json: {message: "Password Needed", success: false}
        end
      else
        render json: {message: "Complete contact information needed to ship your card", success: false}
      end
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

  def buildAddress
    params.blank? ? false : !params['line1'].blank? && !params['city'].blank? && !params['state'].blank? && !params['postal_code'].blank?
  end

  def buildContact
    !params['legalName'].blank? && !params['email'].blank? && !params['phone_number'].blank? && !params['percentToInvest'].blank? && !params['password'].blank?
  end

  def findType
    case !params['type'].blank?

    when true
      params['type']
    when false
      {}
    end
  end
end