class Api::V2::CardPipelineController < ApiController

	def create
    begin
      if buildAddress && buildContact
        if findType == 'company' || findType == 'individual'
          cardHolderNew = Stripe::Issuing::Cardholder.create({
            type: params['type'],
            name: params['name'],
            email: params['email'],
            phone_number: params['phone_number'],
            billing: {
              address: {
                line1: params['address']['line1'],
                city: params['address']['city'],
                state: params['address']['state'],
                country: params['address']['country'],
                postal_code: params['address']['postal_code'],
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
              name: params['name'],
              address: {
                line1: params['address']['line1'],
                city: params['address']['city'],
                state: params['address']['state'],
                country: params['address']['country'],
                postal_code: params['address']['postal_code'],
              }
            }
          })

          customerViaStripe = Stripe::Customer.create({
            description: 'Netwerth Debit Card Holder',
            name: params['name'],
            email: params['email'],
            phone: params['phone_number'],
            address: {
              line1: params['address']['line1'],
              city: params['address']['city'],
              state: params['address']['state'],
              country: params['address']['country'],
              postal_code: params['address']['postal_code'],
            },
            metadata: {
              cardHolder: cardHolderNew['id'],
              issuedCard: cardNew['id'],
              percentToInvest: params['percentToInvest'],
            }
          })

          Stripe::Issuing::Cardholder.update(cardHolderNew['id'], metadata: {stripeCustomerID: customerViaStripe['id']})
          # make user account so they can access the app and make transfers

          @user = User.create!(uuid: SecureRandom.uuid[0..7], stripeCustomerID: customerViaStripe['id'], appName: 'netwethcard', accessPin: 'customer', email: params['email'], password: params['password'], password_confirmation: params['password_confirmation'], referredBy: params['referredBy'].nil? ? "admin" : params['referredBy'], phone: params['phone'])
          render json: {message: "#{findType} card created", success: true}
        else
          render json: {message: "Type needed", success: false}
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
    params['address'].blank? ? false : !params['address']['line1'].blank? && !params['address']['city'].blank? && !params['address']['state'].blank? && !params['address']['country'].blank? && !params['address']['postal_code'].blank?
  end

  def buildContact
    !params['name'].blank? && !params['email'].blank? && !params['phone_number'].blank? && !params['percentToInvest'].blank? && !params['password'].blank?
  end

  def findType
    case !params['type'].blank?

    when true
      params['type']
    when false
      {}
    end
  end

  def user_params
    paramsClean = params.permit(:uuid, :stripeCustomerID, :appName, :accessPin, :email, :password, :password_confirmation, :referredBy, :phone)
    return paramsClean.reject{|_, v| v.blank?}
  end
end