class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def generate_authentication_token!
    Devise.friendly_token
  end

  def self.customers
    where(accessPin: 'customer')
  end

  def self.virtuals
    where(accessPin: 'virtual')
  end

  def self.managers
    where(accessPin: 'manager')
  end

  def self.admins
    where(accessPin: 'admin')
  end

  def hasAccess
    !accessPin.blank?
  end

   def customer?
    customerAccess.include?(accessPin)
  end

  def trustee?
    trusteeAccess.include?(accessPin)     
  end

  def manager?
    managerAccess.include?(accessPin)
  end

  def admin?
    adminAccess.include?(accessPin)     
  end

  def self.twilioText(number, message)
    if ENV['stripeLivePublish'].include?("pk_live_") && Rails.env.production? && number
      account_sid = ENV['twilioAccounSID']
      auth_token = ENV['twilioAuthToken']
      client = Twilio::REST::Client.new(account_sid, auth_token)
      
      from = '+18335152633'
      to = number

      client.messages.create(
        from: from,
        to: to,
        body: message
      )
    else
      :testing_mode
    end
  end

  def self.stripeAmount(string)
    if string.is_a?(String)
      if string.include?(".")
        dollars = string.split(".")[0]
        cents = string.split(".")[1]

        if cents.length == 2
          stripe_amount = "#{dollars}#{cents}"
        else
          if cents === "0"
            stripe_amount = ("#{dollars}00")
          else
            stripe_amount = ("#{dollars}#{cents.to_i * 0.10}")
          end
        end
      else
        stripe_amount = string * 100
      end
    else
      stripe_amount = string * 100
    end

    return stripe_amount
  end

  private

  def customerAccess
    return ['customer']
  end

  def trusteeAccess
    return ['trustee']
  end

  def managerAccess
    return ['manager', 'admin']
  end
  
  def adminAccess
    return ['admin' , 'trustee']
  end
end
