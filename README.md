# mars-crimson
Prácticas motores compatibles MALAB 2016

# Simulink:

  * Opción 1: Usar bloques [SerialReceive](https://es.mathworks.com/help/instrument/serialreceive.html) y [SerialSend](https://es.mathworks.com/help/instrument/serialsend.html) disponibles desde Matlab R2008a en Toolbox `Instrument Control`. **Opción 2:** diseñar código propio en un `.m` aparte (leer abajo motivación).
  * Tipo de dato para enviar y recibir: diría de usar `int16_t`, escalado en MATLAB al rango `[+5,-5]` para quitarle el trabajo de manejar números flotantes al micro. 
  * Añadir un campo timestamp a cada dato ENVIADO desde el STM32: de esa manera el muestreo tendrá precisión siempre, aunque se formen pequeñas colas al recibir. Es decir, el formato de "trama" enviado desde el STM32 debería ser así: 

                      -------------------------------------------------------------------------------
        CAMPO:        |   HEADER (=0x69)  |  TIMESTAMP    |    LECTURAS              |   TAIL (0x96 |
        NUM BYTES:    |       1           |     2 o 4     |   N * int16_t (2 bytes)  |     1        |
                      -------------------------------------------------------------------------------

  * ¿Qué ocurre? Que es muy fácil que por saturación del bucle de recepción en el PC, o por errores, etc. se pierda la "sincronía", es decir, no podemos DAR POR HECHO que cuando vaya a leer, va a estar esperándome justo el primer byte de una nueva trama, podría ser una uno de **mitad**, y si leemos interpretando como trama, leeremos basura. Solución sencilla que llevo usando casi 20 años: añadir bytes de flags de inicio y de final. Por eso los bytes HEADER y TAIL arriba. 
  * Procesar estas tramas se me hace difícil a base de un dibujo de bloques en Simulink, por eso propongo hacerlo en `.m`, al que se acceda desde un bloque simulink.
    
  
# STM32: 

  * Programa para microcontrolador: ver directorio XXXX


