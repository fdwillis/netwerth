class ApiController < ApplicationController 
  protect_from_forgery with: :null_session

  def buildTradingViewData(dataX)
    buildData = {
      'timeframe' => dataX[0],
      'ticker' => dataX[1],
      'rsi' => dataX[2].to_f,
      'close' => dataX[3].to_f,
      'open' => dataX[4].to_f,
      'high' => dataX[5].to_f,
      'low' => dataX[6].to_f,
      'time' => dataX[7].to_datetime,
    }
  end


  def cardToken(params)
      token = Stripe::Token.create(
        :card => {
          :currency => "usd",
          :number => params[:number],
          :exp_month => params[:exp_month],
          :exp_year => params[:exp_year],
          :cvc => params[:cvc]
        }
      )
    return token
  end

  def bankToken(params)
      token = Stripe::Token.create({
        bank_account: {
          country: 'US',
          currency: 'usd',
          account_holder_name: params['account_holder_name'],
          account_holder_type: params['account_holder_type'],
          routing_number: params['routing_number'],
          account_number: params['account_number'],
        },
      })
    return token
  end

  
  # AUTHORIZATIONS
  def authorize
    if user = findUser
      if user&.hasAccess
        yield user
      else
        render json: {message: "Please choose an account type", success: false}
      end
    else
      render json: {message: "Invalid Token", success: false}, status: 401
    end
  end

  def customer
    user = findUser
    
    if user&.customer?
      yield user
    else
      render json: {message: "Unauthorized"}
    end
  end

  def owner
    user = findUser
    if user&.owner?
      yield user
    else
      render json: {message: "Unauthorized"}
    end
  end

  def manager
    user = findUser
    
    if user&.manager?
      yield user
    else
      render json: {message: "Unauthorized"}
    end
  end

  def trustee
    user = findUser
    
    if user&.trustee?
      yield user
    else
      render json: {message: "Unauthorized"}
    end
  end

  def admin
    user = findUser
    
    if user&.admin?
      yield user
    else
      render json: {message: "Unauthorized"}
    end
  end

  private

  def verifiedMerchants
    ENV['verifiedBrandMerchants'].delete(' ').split(",").reject(&:blank?)
  end

  def verifiedappNames
    ENV['verifiedBrandappNames'].delete(' ').split(",").reject(&:blank?)
  end

  def findUser
    if !authorization_token.blank?
      user = User.find_by(authentication_token: authorization_token)
    else
      user = current_user
    end
  end
  
  def authorization_token
    @authorization_token ||= authorization_header
  end

  def googleAuthToken
    @googleAuth ||= authorization_google
  end


  def authorization_header 
    request.headers['nxtwxrthxxthToken']
  end 

  def appNameHeader 
    request.headers['appName']
  end 
end