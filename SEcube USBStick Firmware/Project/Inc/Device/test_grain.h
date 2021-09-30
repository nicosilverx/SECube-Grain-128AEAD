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

void print_uart_c(uint8_t num);

void print_uart_int(uint8_t num);

void generate_rnd_vector(uint8_t *dataout, uint16_t size);



#endif /* INC_DEVICE_TEST_GRAIN_H_ */
