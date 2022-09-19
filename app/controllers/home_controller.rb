class HomeController < ApiController 

	def chris
	end

	def home
	end

	def signals
		
	end

	def discount
	end

	def profile
		
	end

	def updateUser
		authorize do |user|
			user.update(user_params)
			if user&.save
				user&.createConnectAccount
				flash[:success] = "Updated Info"
				redirect_to authenticated_root_path
			else
				flash[:error] = "Something went wrong"
				redirect_to authenticated_root_path
			end
		end
	end

	def addBankSource
		token = User.bankToken(bankTokenParams)
		
		bankAdded = Stripe::Account.create_external_account(
		  current_user&.stripeMerchantID,
		  {
		    external_account: token['id'],
		  },
		)

		if bankAdded
			flash[:success] = "Updated Info"
			redirect_to authenticated_root_path
		else
			flash[:error] = "Something went wrong"
			redirect_to authenticated_root_path
		end
	end

	private

	def user_params
		paramsClean = params.require(:updateUser).permit(:uuid, :serviceFee, :twilioPhoneVerify, :tewCodeVerificationCode, :appName, :username, :accessPin, :maxHourly, :minHourly, :startTime, :endTime, :email, :password, :password_confirmation, :referredBy, :phone)
		
		return paramsClean.reject{|_, v| v.blank?}
	end

	def bankTokenParams
		paramsClean = params.require(:newStripeBankToken).permit(:account_number, :account_holder_name, :routing_number)
		
		return paramsClean.reject{|_, v| v.blank?}
	end
end