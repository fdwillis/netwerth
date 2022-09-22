class Api::V2::SessionsController < ApiController 
	protect_from_forgery with: :null_session

	def new
	end
	
	def create
		begin
			user = User.find_by(email: params[:email])
			
			if !user.blank? && user&.valid_password?(params[:password])
				user.update(authentication_token: user.generate_authentication_token!)
				
				if Rails.env.production?
					# Keen.publish(:newSession, { uuid: user.uuid })
				end
				render json: {
					email: user.email,
					accessPin: user.accessPin,
					uuid: user.uuid, 
					stripeCustomerID: user.stripeCustomerID, 
					authentication_token: user.authentication_token,
					success: true,
				}
			else
				render json: {
					message: "Email and Password combination not found"
				}
			end
		rescue Exception => e
			render json: {
				message: e
			}
		end
	end

	def destroy
		authorize do |user|
			begin
				if user == User.find_by(uuid: params[:id])
					if user&.update(authentication_token:nil)

						if Rails.env.production?
							# Keen.publish(:deletedSession, { uuid: @user.uuid })
						end
						
						render json: {
							message: "Signed Out",
							success: true
						}, status: 200
					else
						head(:unauthorized)
					end
				else
					render json: :unauthorized
				end
			rescue Exception => e
				render json: {
					error: e
				}
			end
		end
	end
end