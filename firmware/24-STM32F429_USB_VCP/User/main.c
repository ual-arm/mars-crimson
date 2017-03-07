/**
 *	USB VCP for STM32F4xx example.
 *    
 *	@author		Tilen Majerle
 *	@email		tilen@majerle.eu
 *	@website	http://stm32f4-discovery.com
 *	@ide		Keil uVision
 *	@packs		STM32F4xx Keil packs version 2.2.0 or greater required
 *	@stdperiph	STM32F4xx Standard peripheral drivers version 1.4.0 or greater required
 *
 * Add line below to use this example with F429 Discovery board (in defines.h file)
 *
 * #define USE_USB_OTG_HS
 *
 * Before compile in Keil, select your target, I made some settings for different targets
 */
#include "tm_stm32f4_usb_vcp.h"
#include "tm_stm32f4_disco.h"
#include "tm_stm32f4_dac.h"
#include "tm_stm32f4_adc.h"
#include "tm_stm32f4_delay.h"
#include "defines.h"
 
int main(void) 
{
	uint8_t c;
	/* System Init */
	SystemInit();

	/* Initialize Delay library */
	TM_DELAY_Init();

	TM_DAC_Init(TM_DAC1);  // Initialize DAC channel 1, pin PA4
	TM_DAC_Init(TM_DAC2);  // Initialize DAC channel 2, pin PA5

	TM_ADC_Init(ADC1, ADC_Channel_2); // Initialize ADC1 on channel 2, this is pin PA2
	TM_ADC_Init(ADC1, ADC_Channel_3); // Initialize ADC1 on channel 3, this is pin PA3

	/* Set 12bit analog value of 1500/4096 * 3.3V */
	TM_DAC_SetValue(TM_DAC1, 0);
	/* Set 12bit analog value of 2047/4096 * 3.3V */
	TM_DAC_SetValue(TM_DAC2, 1500);

	/* Initialize LED's. Make sure to check settings for your board in tm_stm32f4_disco.h file */
	TM_DISCO_LedInit();
	
	/* Initialize USB VCP */    
	TM_USB_VCP_Init();
	
	while (1) 
	{
		/* USB configured OK, drivers OK */
		if (TM_USB_VCP_GetStatus() == TM_USB_VCP_CONNECTED) 
		{
			/* Turn on GREEN led */
			TM_DISCO_LedOn(LED_GREEN);
			/* If something arrived at VCP */
			if (TM_USB_VCP_Getc(&c) == TM_USB_VCP_DATA_OK) 
			{
				/* Return data back */
				TM_USB_VCP_Putc(c);

				TM_DISCO_LedToggle(LED_BLUE);
			}

			// Read from ADC:
			const uint16_t adc0 = TM_ADC_Read(ADC1, ADC_Channel_2);
			const uint16_t adc1 = TM_ADC_Read(ADC1, ADC_Channel_3);
			
		} 
		else 
		{
			/* USB not OK */
			TM_DISCO_LedOff(LED_GREEN);
		}
	}
}
