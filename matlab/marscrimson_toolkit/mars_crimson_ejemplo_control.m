% Construye un objeto que sirve de interfaz con la placa:
placaMotores = MarsCrimson();

% Conecta con la placa física:
placaMotores.conectar('COM4');

VALOR_CONSIGNA_VEL  = 0.5;  % volts
CONTROLADOR_KP      = 10;

DURACION_ITERACIONES = 100;

% Asegurar que el motor está parado:
placaMotores.escribir_voltaje(0);
pause(0.2);


salida_vel = 0;
for i=1:DURACION_ITERACIONES,
   [vel_actual] = placaMotores.escribir_voltaje_y_leer(salida_vel);
   
   % Controlador proporcional:
   salida_vel = CONTROLADOR_KP * (VALOR_CONSIGNA_VEL-vel_actual);
   fprintf('Iter=%4i  vel=%+8.03f  actuacion=%+8.02f\n', i, vel_actual, salida_vel);
end

% Asegurar que el motor está parado:
placaMotores.escribir_voltaje(0);

