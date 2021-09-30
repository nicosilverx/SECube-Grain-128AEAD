/*
 * test_grain.c
 *
 *  Created on: 30 Sep 2021
 *      Author: rasan
 */

#include "test_grain.h"

void print_uart(uint8_t data[]) {
	uint8_t MSG[128] = {'\0'};
	sprintf(MSG, data);
	HAL_UART_Transmit(&huart1, MSG, sizeof(MSG), HAL_MAX_DELAY);
}


void print_uart_hex(uint8_t num) {
	uint8_t hex[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
	uint8_t char_hex = hex[num];
	HAL_UART_Transmit(&huart1, &char_hex, 1, HAL_MAX_DELAY);
}

void print_uart_int(uint8_t num) {
	uint8_t integer[4] = {'0', '0','0','0'};
	uint8_t appo = num;
	uint16_t i=0;
	while(appo != 0 ) {
		integer[3-i] = (appo % 10) + '0';
		appo = appo/10;
	}
	for(i=0;i < 4; i++)
		HAL_UART_Transmit(&huart1, &integer[i], 1, HAL_MAX_DELAY);

}

void print_uart_8(uint8_t num) {
	uint8_t hex[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
	uint8_t char_up = hex[ (num & 0xF0 ) >> 4];
	uint8_t char_dw = hex[ num & 0x0F ];
	HAL_UART_Transmit(&huart1, &char_up, 1, HAL_MAX_DELAY);
	HAL_UART_Transmit(&huart1, &char_dw, 1, HAL_MAX_DELAY);
}

void print_uart_16(uint16_t num) {
	uint8_t hex[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
	uint8_t char_1 = hex[ (num & 0xF000 ) >> 12];
	uint8_t char_2 = hex[ (num & 0x0F00 ) >> 8];
	uint8_t char_3 = hex[ (num & 0x00F0 ) >> 4];
	uint8_t char_4 = hex[ num & 0x000F ];
	HAL_UART_Transmit(&huart1, &char_1, 1, HAL_MAX_DELAY);
	HAL_UART_Transmit(&huart1, &char_2, 1, HAL_MAX_DELAY);
	HAL_UART_Transmit(&huart1, &char_3, 1, HAL_MAX_DELAY);
	HAL_UART_Transmit(&huart1, &char_4, 1, HAL_MAX_DELAY);
}


void generate_rnd_vector(uint8_t *dataout, uint16_t size) {
	srand(HAL_GetTick());
	for (size_t i = 0; i < size; i++) {
		dataout[i] = (uint8_t) rand() ;
	}
}


