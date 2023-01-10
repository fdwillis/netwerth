class Api::V2::TradingviewController < ApiController 

	def create
		cleanData = buildTradingViewData(request.body.string.split(","))
		
		alertMade = TradingviewAlert.create_or_find_by(cleanData)

	end
end