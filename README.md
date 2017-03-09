# mars-crimson
Prácticas motores compatibles MATLAB 2016

# STM32: 

  * Programa para microcontrolador: Abrir con Keil el proyecto `firmware/24-STM32F429_USB_VCP/project.uvprojx`
  
  * Frames: uC -> PC
  
  Type = 0x10: Leer ADCs
  
				  --------------------------------------------------------------------------------------------------
	CAMPO:        |   HEADER (=0x69)  |  TYPE (=0x10) |  TIMESTAMP_MILLISECS    |    ADC readings   |   TAIL (0x96 |
	NUM BYTES:    |       1           |         1     |            4            |   2 * int16_t     |     1        |
				  --------------------------------------------------------------------------------------------------
  
  * Frames: PC -> uC
  
  Type = 0x00: Cambiar valores de DACs, y enviar de vuelta un frame tipo 0x10 con lecturas ADCs:
  
				  -------------------------------------------------------------------------
	CAMPO:        |   HEADER (=0x69)  |  TYPE (=0x00) |      DAC values    |   TAIL (0x96 |
	NUM BYTES:    |       1           |         1     |     2 * int16_t    |     1        |
				  -------------------------------------------------------------------------

  Type = 0x01: Cambiar valores de DACs (y no hacer nada más)
  
				  -------------------------------------------------------------------------
	CAMPO:        |   HEADER (=0x69)  |  TYPE (=0x01) |      DAC values    |   TAIL (0x96 |
	NUM BYTES:    |       1           |         1     |     2 * int16_t    |     1        |
				  -------------------------------------------------------------------------

  Type = 0x02: Activa/desactiva modo de medición continuo de alta frecuencia (periodo de muestreo de ADCs configurable a XX millisecs.)
  
				  -----------------------------------------------------------------------
	CAMPO:        |   HEADER (=0x69)  |  TYPE (=0x02) |  ADC period (ms) |   TAIL (0x96 |
	NUM BYTES:    |       1           |         1     |       1          |     1        |
				  -----------------------------------------------------------------------


				  
# Simulink:

  * Opción 1: Usar bloques [SerialReceive](https://es.mathworks.com/help/instrument/serialreceive.html) y [SerialSend](https://es.mathworks.com/help/instrument/serialsend.html) disponibles desde Matlab R2008a en Toolbox `Instrument Control`. **Opción 2:** diseñar código propio en un `.m` aparte (leer abajo motivación). [doc MATLAB](https://es.mathworks.com/videos/incorporating-matlab-algorithms-into-a-simulink-model-69028.html)
  * Tipo de dato para enviar y recibir: diría de usar `int16_t`, escalado en MATLAB al rango `[+5,-5]` para quitarle el trabajo de manejar números flotantes al micro. 
  * Añadir un campo timestamp a cada dato ENVIADO desde el STM32: de esa manera el muestreo tendrá precisión siempre, aunque se formen pequeñas colas al recibir. Es decir, el formato de "trama" enviado desde el STM32 debería ser así: 


  * ¿Qué ocurre? Que es muy fácil que por saturación del bucle de recepción en el PC, o por errores, etc. se pierda la "sincronía", es decir, no podemos DAR POR HECHO que cuando vaya a leer, va a estar esperándome justo el primer byte de una nueva trama, podría ser una uno de **mitad**, y si leemos interpretando como trama, leeremos basura. Solución sencilla que llevo usando casi 20 años: añadir bytes de flags de inicio y de final. Por eso los bytes HEADER y TAIL arriba. 
  * Procesar estas tramas se me hace difícil a base de un dibujo de bloques en Simulink, por eso propongo hacerlo en `.m`, al que se acceda desde un bloque simulink.
    
  


