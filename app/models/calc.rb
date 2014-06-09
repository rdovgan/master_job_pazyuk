class Calc < ActiveRecord::Base
  attr_accessor :mas_values, :probability, :dt, :y, :u, :u_count, :period, :x0, :ozn_prob
  
  X0 = 500 #стартовий капітал
  N = 12 #кількість місяців

  ##############################################################################  
  def initialize(x0 = nil, n = nil)
    @x0 = x0 || rand(X0)+50
    @n = n || rand(N)+8    
    @period = @n
    @y = [0] + (1..@n).map{|i| rand(100)} # надходження
    @u = [0] + (1..@n).map{|i| rand(200)} # видатки
    @u_count = [0] + (1..@n).map{|i| rand(8)+1} # кількість видатків на протязі i місяця
    @t = (0..@n).to_a
    @a = calc_a
    @b11 = calc_b11
    @b12 = calc_b12
    @b21 = calc_b21
    @b22 = calc_b22
    @M = calc_M
    @sigma = calc_sigma    
    @lbd = calc_lambda
  end
  
  ##############################################################################
  def calc_a
   return @a if @a
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + @y[i] }
   @a = s.to_f/@n
  end  
  
  ##############################################################################
  
  def calc_b11
   return @b11 if @b11
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + @y[i]*Math.cos(@t[i]) }
   @b11 = 2*s.to_f/@n
  end

  ##############################################################################

  def calc_b12
   return @b12 if @b12
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + @y[i]*Math.cos(2*@t[i]) }
   @b12 = 2*s.to_f/@n
  end

  ##############################################################################

  def calc_b21
   return @b21 if @b21
   suma = 0...@n
   s = suma.inject(0){ |sum,i| sum + @y[i]*Math.sin(@t[i]) }
   @b21 = 2*s.to_f/@n
  end

  ##############################################################################

  def calc_b22
   return @b21 if @b21
   suma = 0...@n
   s = suma.inject(0){ |sum,i| sum + @y[i]*Math.sin(2*@t[i]) }
   @b22 = 2*s.to_f/@n
  end
  
  ##############################################################################
    
  def c(t) 
   calc_a
   calc_b11
   calc_b12
   calc_b21
   calc_b22
   @a + @b11*Math.cos(t) + @b21*Math.sin(t) + @b12*Math.cos(2*t) + @b22*Math.sin(2*t)
  end

  ##############################################################################

  def calc_M
   return @M if @M
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + @u[i] }
   @M = s.to_f/@n
  end

  ##############################################################################

  def calc_sigma
   return @sigma if @sigma
   calc_M
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + (@u[i]-@M)*(@u[i]-@M) }
   @sigma = Math.sqrt(s.to_f/@n)   
  end
  
  ##############################################################################  
  
  def calc_lambda
   return @lbd if @lbd
   suma = 1..@n
   s = suma.inject(0){ |sum,i| sum + @u_count[i] }
   @lbd = s.to_f/@n
   return @lbd    
  end

  ##############################################################################  

  def N_t(t)
   calc_lambda
   n_t = rand
   v=-Math.log(1-n_t)*@lbd
   return v
  end 

  ##############################################################################  

  def ksi_i
   begin
    n1 = rand()
    n2 = rand()
    v1 = 2*n1 - 1
    v2 = 2*n2 - 1
    s= v1*v1 + v2*v2
   end while (s>=1) || (v1<0)
   ksi_iz = v1*Math.sqrt(-2*Math.log(s)/s)
   value = @a + ksi_iz * @sigma
   return value
  end

  ##############################################################################  

  def integrate(x0, x1, dx=(x1-x0)/1000.0)
   x = x0
   sum = 0
   return 0 if (x1-x0)==0 
   loop do
    y = yield(x)
    sum += dx * y
    x += dx
    break if x > x1
   end #end of loop
   sum
  end #end of def

  ##############################################################################  
  
  def int_f(t)
   Math.exp(-t*t)
  end  
  
  ##############################################################################  
    
  def erf(x)
   if x > 5   
    result = 0.5
   elsif x < 5  
    result = -0.5     
   else 
    result = (2.to_f/Math.sqrt(Math::PI))*integrate(0.0,x) {|t| int_f(t) }
   end 
   return result
  end

  ##############################################################################  

  def f(t)
   stepin_for_erf1 = (@s_ksi-(@x0+@koefA*t))/Math.sqrt(2*@koefB*t)
   erf1 = erf(stepin_for_erf1)
   stepin_for_erf2 = -(@x0+@koefA*t)/Math.sqrt(2*@koefB*t)
   erf2 = erf(stepin_for_erf2)
   result = @sigma_ksi_2*(2/Math::PI)*(erf1-erf2)
   return result
  end

  ##############################################################################  

  def p_jmov(t)
   stepin = -integrate(0.0,t){|t1| f(t1)}
   1 - Math.exp(stepin)
  end
  
  ##############################################################################  
  
  def calc_values
   @x = [@x0]
   @mas_values = [@x0]
   m = 10
   @dt = 1.to_f/m
   t = dt   
   i = 0
   @s_ksi = 0
   @ozn_prob = 0 
   xp = @x0   
   (1..@n).step(1) do |i|
    j=1
    begin
     x_t = xp + c(t)     
     puts "t=#{t} x(#{t})=#{x_t}"
     @mas_values << x_t    
     t += dt
     j += 1
    end while(j<=m)
       
    count = N_t(@t[i]).to_i
    suma = 1..count    
    @s_ksi = suma.inject(0){ |sum,i| sum + ksi_i }  
    x_t -= @s_ksi
    @mas_values[-1] = x_t    
    puts "Strubok new value x_t=#{x_t}"
    xp = x_t
    if x_t<0 
     @ozn_prob = 1 
     t = @t[i]
     break
    end
   end #end of step

   if @ozn_prob == 1 
    @sigma_ksi_2 = @sigma*@sigma 
    suma_for_sigma_y = 1..@n    
    @sigma_y_2 = suma_for_sigma_y.inject(0){ |sum,i| sum + (@y[i]-@M)*(@y[i]-@M)}/@n  
    c_t = c(t)
    @koefA = c_t*@sigma_y_2 - @sigma_ksi_2*@s_ksi

    @koefB = c_t*c_t*@sigma_y_2 + @sigma_ksi_2*@s_ksi*@s_ksi
    @probability = p_jmov(t)
   end   

  end #end of def


end
