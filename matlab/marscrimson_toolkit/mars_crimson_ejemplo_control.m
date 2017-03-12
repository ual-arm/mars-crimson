% Construye un objeto que sirve de interfaz con la placa:
placaMotores = MarsCrimson();

% Conecta con la placa física:
placaMotores.conectar();

VALOR_CONSIGNA_VEL  = 3.5;  % volts
CONTROLADOR_KP      = 3;

DURACION_ITERACIONES = 500;

% Asegurar que el motor está parado:
placaMotores.escribir_voltaje(0);
pause(0.2);


salida_vel = 0;
sum_tims = 0;
for i=1:DURACION_ITERACIONES,
   tic;
   [vel_actual] = placaMotores.escribir_voltaje_y_leer(salida_vel);
   sum_tims = sum_tims + toc;
   
   % Controlador proporcional:
   salida_vel = CONTROLADOR_KP * (VALOR_CONSIGNA_VEL-vel_actual);
   fprintf('Iter=%4i  vel=%+8.03f  actuacion=%+8.02f\n', i, vel_actual, salida_vel);
end

fprintf('Tiempo medio de lectura/escritura en motores: %.03f ms\n', 1e3*sum_tims/DURACION_ITERACIONES);

% Asegurar que el motor está parado:
placaMotores.escribir_voltaje(0);

