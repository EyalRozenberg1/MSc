function [A, P] = WavePropagation_SSF3(Undepleted, Lambda, w0, NumOfPoints, PlaneGauss_, dx_prop, CrystalPropAxis, DeltaK, K, Omega, n, I, InteractionType, deff, A_from_I, Kappa, P_from_A, samples)
% Split step fourier solution for Plane wave propagation
tic 
    switch InteractionType
        case 'Type1 SHG'
            if(PlaneGauss_) % Plane Wave
                P=0;
                % memory allocation
                A.in1 = zeros(NumOfPoints,1);
                A.in2 = 0;
                A.out = zeros(NumOfPoints,1);
                
                % Initialize waves at the start of crystal
                A.in1(1)   = A_from_I(I.in1,n.in1(1));
                A.out(1)   = A_from_I(I.out,n.out(1));
                for i=2:length(CrystalPropAxis)
                    % General Definitions
                    KappaIn  = Kappa(deff,Omega.in1,K.in1,i);
                    Kappaout = Kappa(deff,Omega.out,K.out,i);

                    % coupled equations, boyd pg. 98 equations 2.7.10-12:
                    xi    = i * dx_prop;
                    dAin1 = 2*KappaIn*A.out(i-1).*conj(A.in1(i-1))*exp(-1i*DeltaK(i)*xi);
                    dAout = Kappaout*A.in1(i-1).^2*exp(1i*DeltaK(i)*xi);
                    
                    if(Undepleted)
                    A.in1(i) = A.in1(1); % Undepleted Pump
                    else
                    A.in1(i) = A.in1(i-1) + dAin1*dx_prop;
                    end
                    A.out(i) = A.out(i-1) + dAout*dx_prop;
                end
            else % Gaussian Wave
                A=0;
                x = NumOfPoints * dx_prop;
                % Hankel definitions
                % Note: we can be defined some parameters as const because change in very little
                Kin1        = K.in1(1);
                Kout        = K.out(1);
                
                zr.in1      = pi*n.in1(1)*w0.in1^2/Lambda.in1;     % [m] Reighley range with consider of Lambda in
%                 zr.out      = zr.in1;                              % [m] Reighley range with consider of Lambda out
                
                w_max.in1    = w0.in1*sqrt(1+(x/zr.in1)^2);
                w_max.out    = w_max.in1/sqrt(2);
                
                rmax.in1      = 2*w_max.in1;
                rmax.max      = rmax.in1;

                mat_H2        = hankel_matrix2(0, rmax.max, samples);
                r_            = mat_H2.r;                  % Radius of beam =	xy coordinate
                fr_sq_        = (mat_H2.v).^2;             %   =	tranform coordinate
                
                % Hankel Transform & Inverse Hankel Transform for out wave
                ht2         = @(f) mat_H2.JV .* (mat_H2.T * (f./mat_H2.JR)) /(2*pi);
                iht2        = @(F) mat_H2.JR .* (mat_H2.T * (F./mat_H2.JV)) *(2*pi);
                
                % propagation H same as Split Step
                H              = @(PropT, k) exp(PropT).*exp(-1i*k*dx_prop);
                % Prop term
                PropTerm       = @(lambda,n_) 1i*dx_prop*2*pi* sqrt((n_/lambda).^2 - fr_sq_);
                    
                % according to boyd pg. 118 equations 2.10.5b-c:
                b_         = @(k,w_0) k*w_0^2;
                b          = b_(Kin1, w0.in1);
                
                chi_       = @(B) 2*x/B;
                chi        = chi_(b);
                
                % Result for the start of the crystal
                % memory allocation
                P.in1 = zeros(1,NumOfPoints);
                P.out = zeros(1,NumOfPoints);
                
                % according to boyd pg. 117 equation 2.10.8-9:
                Ain1   = A_from_I(I.in1,n.in1(1))/(1+1i*chi)*exp(-  (r_.^2)/(w0.in1^2*(1+1i*chi)));
                Aout   = A_from_I(I.out,n.out(1))/(1+1i*chi)*exp(-2*(r_.^2)/(w0.in1^2*(1+1i*chi)));

                P.in1(1) = P_from_A(Ain1, r_, n.in1(1));
                P.out(1) = P_from_A(Aout, r_, n.out(1));
                
                for i=2:NumOfPoints
                    
                    propterm.in1    = PropTerm(Lambda.in1 ,n.in1(i));
                    propterm.out    = PropTerm(Lambda.out ,n.out(i));
                    
                    % General Definitions
                    KappaIn  = Kappa(deff,Omega.in1,K.in1,i);
                    Kappaout = Kappa(deff,Omega.out,K.out,i);

                    % coupled equations, boyd pg. 98 equations 2.7.10-12:
                    xi    = i * dx_prop;
                    dAin1 = 2*KappaIn*Aout.*conj(Ain1)*exp(-1i*DeltaK(i)*xi);
                    dAout = Kappaout*Ain1.^2*exp( 1i*DeltaK(i)*xi);
                    
                    Ew_in1 = ht2(Ain1);
                    Ew_out = ht2(Aout);
                    
                    Hw.in1 = H(propterm.in1, K.in1(i));
                    Hw.out = H(propterm.out, K.out(i));                    
                
                    Ew_in1 = Ew_in1 .* Hw.in1;
                    Ew_out = Ew_out .* Hw.out;
                    
                    Ain1_temp = iht2(Ew_in1);
                    Aout_temp = iht2(Ew_out);
                    
                    if(Undepleted)
                        Ain1 = Ain1;
                    else
                        Ain1 = Ain1_temp + dAin1*dx_prop;
                    end
                    Aout = Aout_temp + dAout*dx_prop;
                    
                    if(Undepleted)
                        P.in1(i) = P.in1(1); % Undepleted Pump
                    else
                        P.in1(i) = P_from_A(Ain1, r_, n.in1(i));                        
                    end
                    P.out(i) = P_from_A(Aout, r_, n.out(i));
                    
                    if(isnan(P.out(i)) || isnan(P.in1(i)))
                        error('ERROR: numerical issue while calculating BW. Exit code');
                    end
                    if(mod(i,round(NumOfPoints/10))==0 || i==NumOfPoints || i==2)
                        disp(['Calc Split step. Done: ', num2str(round(100*i/NumOfPoints)),'%',...
                            '   Pin=', num2str(P.in1(i)), '   Pout=', num2str(P.out(i)),'    Sum=', num2str(P.in1(i)+P.out(i))]);
                        figure;
                        plotyy(r_,abs(Ain1),r_,abs(Aout)); title( num2str(round(100*i/NumOfPoints)));
                        drawnow;
                    end
                end
            end     
        case 'Type1 THG'
             % compute for this case %
    end
toc    
end

