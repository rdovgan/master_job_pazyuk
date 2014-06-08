class RunAppController < ApplicationController
 def startapp
  @obj = Calc.new
  @obj.calc_values
  logger.debug "#{@mas_values}"
 end
end
