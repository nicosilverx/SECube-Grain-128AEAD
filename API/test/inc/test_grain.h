/*
 * test_grain.h
 *
 *  Created on: 30 Sep 2021
 *      Author: rasan
 */

#ifndef INC_DEVICE_TEST_GRAIN_H_
#define INC_DEVICE_TEST_GRAIN_H_

#include "../usart.h"
#include <stdint.h>

void print_uart(uint8_t data[]);

void print_uart_hex(uint8_t num);

void print_uart_8(uint8_t num);

void print_uart_int(uint8_t num);

void generate_rnd_vector(uint8_t *dataout, uint16_t size);

uint8_t to_hex(uint8_t num);


#endif /* INC_DEVICE_TEST_GRAIN_H_ */
