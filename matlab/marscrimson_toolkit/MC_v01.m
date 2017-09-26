function [sys,x0,str,ts]=MC_v01(t,x,u,flag,Ts,COM,filter)

%transferFunction S-function que modela un sistema en espacio estados
%discreto
%
%   See sfuntmpl.m for a general S-function template.
%
%   See also SFUNTMPL.

%
% Dispatch the flag. The switch function controls the calls to 
% S-function routines at each simulation stage of the S-function.
%
switch flag,
  %%%%%%%%%%%%%%%%%%
  % Initialization %
  %%%%%%%%%%%%%%%%%%
  % Initialize the states, sample times, and state ordering strings.
  case 0
    [sys,x0,str,ts] = mdlInitializeSizes(Ts,COM);

  %%%%%%%%%%
  % Update %
  %%%%%%%%%%
  case 2,                                                
    sys = mdlUpdates(t,x,u,Ts,filter); 

  %%%%%%%%%%%
  % Outputs %
  %%%%%%%%%%%
  % Return the outputs of the S-function block.
  case 3
    sys = mdlOutputs(t,x,u);

  %%%%%%%%%%%%%
  % Terminate %
  %%%%%%%%%%%%%
  case 9,
    sys = mdlTerminate(t,x,u);
    
  %%%%%%%%%%%%%%%%%%%
  % Unhandled flags %
  %%%%%%%%%%%%%%%%%%%
  % There are no termination tasks (flag=9) to be handled.
  % Also, there are no discrete states,
  % so flags 2 and 4 are not used, so return an empty
  % matrix 
  case {1, 4}
    sys = [];
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Unexpected flags (error handling)%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Return an error message for unhandled flag values.
  otherwise
    error(['Unhandled flag = ',num2str(flag)]);

end

% end discreteSS

%
%=============================================================================
% mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%=============================================================================
%
function [sys,x0,str,ts,placaMotores] = mdlInitializeSizes(Ts,COM)

global placaMotores
global inputSignal
global pastOutputSignal

sizes = simsizes;
sizes.NumContStates  = 0;   % Numero de estados continuos
sizes.NumDiscStates  = 1;   % Numero de estados discretos
sizes.NumOutputs     = 1;   % Numero de salidas
sizes.NumInputs      = 1;   % Numero de entradas
sizes.DirFeedthrough = 1;   % Permite utilizar las entradas 'u' para calcular las salidas en 'mdlOutputs'
sizes.NumSampleTimes = 1;   % Numero de tiempos de muestras

sys = simsizes(sizes);
str = [];                   % M-file S-functions must set this to the empty matrix
x0  = 0;   % Inicializo los estados
ts  = [Ts 0];

% Construye un objeto que sirve de interfaz con la placa:
placaMotores = MarsCrimson();

% Conecta con la placa física:
placaMotores.conectarPuerto(COM);

PERIODO_LECTURA_MS = Ts * 1e3;  % milisecs

% Asegurar que el motor está parado:
placaMotores.escribir_voltaje(0);
inputSignal = 0;
pastOutputSignal = 0;
pause(0.2);

placaMotores.iniciar_medicion_continua(PERIODO_LECTURA_MS);
pause(0.1);

placaMotores.limpiar_buffer();
% end mdlInitializeSizes

%
%=============================================================================
% mdlDerivatives
% Return the derivatives for the continuous states.
%=============================================================================
%
function sys = mdlUpdates(t,x,u,Ts,filter)

global placaMotores
global inputSignal
global pastOutputSignal

%placaMotores.limpiar_buffer();
if (u == inputSignal)   
    [volt, tim] = placaMotores.leer_velocidad();
else
    [volt, tim] = placaMotores.escribir_voltaje_y_leer(u);
end
%pause(Ts);

inputSignal = u;
if (filter)
    %[num den] = tfdata(c2d(tf(1,[0.02 1]),Ts),'v');
    %volt = -den(2) * pastOutputSignal + num(2) * volt;
    volt = 0.9512 * pastOutputSignal + 0.0488 * volt;
    pastOutputSignal = volt;
end

sys = volt;

% end mdlDerivatives

%
%=============================================================================
% mdlOutputs
% Return the output vector for the S-function
%=============================================================================
%
function sys = mdlOutputs(t,x,u)

sys = x;

% end mdlOutputs

%
%=============================================================================
% mdlTerminate
% Perform any end of simulation tasks.
%=============================================================================
%
function sys = mdlTerminate(t,x,u)

global placaMotores

placaMotores.escribir_voltaje(0);
pause(0.2);
placaMotores.parar_medicion_continua();
placaMotores.close();

sys = [];

% end mdlTerminate



