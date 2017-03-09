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


#pragma pack(push, 1)

// Answer to PC:
struct OutFrame_ADC_Readings
{
	uint8_t header, type; // Type: 0x10
	uint32_t timestamp_ms;
	uint16_t adcs[2];
	uint8_t tail;
};

// CMD from PC: Set two DAC values and answer with a 0x10 msg
struct InFrame_DAC_and_Read
{
	uint8_t header, type; // type = 0
	uint16_t dacs[2];
	uint8_t tail;
};
// CMD from PC: Set two DAC values
struct InFrame_DAC
{
	uint8_t header, type; // type = 1
	uint16_t dacs[2];
	uint8_t tail;
};
// CMD from PC: Start/stop auto ADC sampling mode (high-freq)
struct InFrame_ADC_AutoSampling
{
	uint8_t header, type; // type = 2
	uint8_t sampling_period_ms;
	uint8_t tail;
};
const uint8_t NUMBER_IN_FRAME_DEFINED = 3;

#pragma pack(pop)

const uint8_t in_frame_expected_lengths[NUMBER_IN_FRAME_DEFINED] = 
{
	sizeof(struct InFrame_DAC_and_Read),   // Type 0
	sizeof(struct InFrame_DAC),   // Type 1
	sizeof(struct InFrame_ADC_AutoSampling),   // Type 2
};

static void parse_rx_buffer(const uint8_t *buf, uint8_t type, uint8_t len);
static void send_adc_readings(void);

uint8_t   ADC_autosampling_period_ms = 0;   // =0 means disabled.
uint32_t  ADC_autosampling_last_tim = 0;

int main(void) 
{
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
	TM_DAC_SetValue(TM_DAC2, 0);

	/* Initialize LED's. Make sure to check settings for your board in tm_stm32f4_disco.h file */
	TM_DISCO_LedInit();
	
	/* Initialize USB VCP */    
	TM_USB_VCP_Init();

	char usb_ok_led_is_on = 0;
	uint32_t running_led_last_toggle = 0;   // used to make the BLUE LED to blink
	const uint32_t LED_BLINK_PERIOD_MS = 500;

	uint8_t rx_buffer[200]; // Buffer for incoming data from the USB VCP. We accumulate data here until it builds up a full message, then it's parsed and interpreted.
	uint8_t rx_buffer_count = 0;
	uint32_t rx_buffer_last_rx_tim = 0;

	while (1) 
	{
		if ( TM_Time - running_led_last_toggle > LED_BLINK_PERIOD_MS) 
		{
			running_led_last_toggle = TM_Time;
			TM_DISCO_LedToggle(LED_BLUE);
		}

		/* USB configured OK, drivers OK */
		if (TM_USB_VCP_GetStatus() != TM_USB_VCP_CONNECTED) 
		{
			/* USB not OK */
			TM_DISCO_LedOff(LED_GREEN);
			usb_ok_led_is_on = 0;
			continue; // keep waiting
		}

		// OK, we have USB connection: 
		if (!usb_ok_led_is_on)  // don't waste time calling the LED function more than once.
		{
			/* Turn on GREEN led */
			TM_DISCO_LedOn(LED_GREEN);
			usb_ok_led_is_on = 1;
		}
		
		// ADC autosampling mode?
		if (ADC_autosampling_period_ms>0)
		{
			if (TM_Time-ADC_autosampling_last_tim>=ADC_autosampling_period_ms)
			{
				ADC_autosampling_last_tim = TM_Time;
				send_adc_readings();
			}
		}

		// New data from the VCP?
		uint8_t c;
		if (TM_USB_VCP_Getc(&c) != TM_USB_VCP_DATA_OK)
		{
			continue; // nothing else to do
		}
		
		// If last byte is too old, discard old data:
		if (TM_Time - rx_buffer_last_rx_tim > 1000) 
		{
			rx_buffer_count = 0; // Reset buffer
		}
		rx_buffer_last_rx_tim = TM_Time;

		// Add new char to buffer:
		rx_buffer[rx_buffer_count++] = c;
		
		// Out of space?
		if (rx_buffer_count>=sizeof(rx_buffer)-1)
		{
			// something must be wrong: we don't work with such large messages!
			rx_buffer_count= 0;
		}

		// Expected frame format: see README.md

		// Sanity check: start flag:
		if (rx_buffer_count>=1 && rx_buffer[0]!=0x69)
		{
			rx_buffer_count = 0; // Reset buffer
		}

		if (rx_buffer_count>=2)
		{
			const uint8_t in_type = rx_buffer[1];
			if (in_type>=NUMBER_IN_FRAME_DEFINED) 
			{
				// Out of range: ignore, corrupted frame or need to upgrade the firmware:
				rx_buffer_count = 0;
			}
			else
			{
				const uint8_t expected_len = in_frame_expected_lengths[in_type];
				if (rx_buffer_count>=expected_len)
				{
					parse_rx_buffer(&rx_buffer[0], in_type, rx_buffer_count);
					// processed or not, we are done with this frame: start over:
					rx_buffer_count = 0;
				}
			}
		}
		
	}  // end while(1)
}  // end main()



void parse_rx_buffer(const uint8_t *buf, uint8_t type, uint8_t len)
{
#if 0
	char str[200];
	sprintf(str,"parse with len=%u type=0x%02X: ", len, type);
	TM_USB_VCP_Puts(str);
	for (int i=0;i<len;i++) 
	{
		sprintf(str,"0x%02X ", buf[i]);
		TM_USB_VCP_Puts(str);
	}
	TM_USB_VCP_Puts("\r\n");
#endif
	
	// Sanity checks:
	if (buf[0]!=0x69) return;
	if (buf[in_frame_expected_lengths[type]-1]!=0x96) return;

	switch (type)
	{
		case 0x00:
		{
			const struct InFrame_DAC_and_Read* frame = (const struct InFrame_DAC_and_Read*)buf;
			/* Set 12bit analog value of X/4096 * 3.3V */
			TM_DAC_SetValue(TM_DAC1, frame->dacs[0]);
			TM_DAC_SetValue(TM_DAC2, frame->dacs[1]);
			send_adc_readings();
		}
		break;

		case 0x01:
		{
			const struct InFrame_DAC* frame = (const struct InFrame_DAC*)buf;
			/* Set 12bit analog value of X/4096 * 3.3V */
			TM_DAC_SetValue(TM_DAC1, frame->dacs[0]);
			TM_DAC_SetValue(TM_DAC2, frame->dacs[1]);
		}
		break;

		case 0x02:
		{
			const struct InFrame_ADC_AutoSampling* frame = (const struct InFrame_ADC_AutoSampling*)buf;
			ADC_autosampling_period_ms = frame->sampling_period_ms;
		}
		break;
	};
}

void send_adc_readings()
{
	// Read from ADC:
	struct OutFrame_ADC_Readings  out_frame;
	out_frame.timestamp_ms = TM_Time;
	out_frame.adcs[0] = TM_ADC_Read(ADC1, ADC_Channel_2);
	out_frame.adcs[1] = TM_ADC_Read(ADC1, ADC_Channel_3);
	out_frame.header = 0x69;
	out_frame.type   = 0x10;
	out_frame.tail = 0x96;

	// Send as a binary block:
	TM_USB_VCP_Send((uint8_t*)&out_frame, sizeof(out_frame));
}


