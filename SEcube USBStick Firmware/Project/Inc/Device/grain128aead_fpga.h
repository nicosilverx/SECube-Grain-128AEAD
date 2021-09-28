/**
  ******************************************************************************
  * File Name          : sha256_fpga.h
  * Description        : High-level driver for communication between CPU and 
                         SHA256 IP core in an IP-Manager-based environment
  ******************************************************************************
  *
  * Copyright � 2016-present Blu5 Group <https://www.blu5group.com>
  *
  * This library is free software; you can redistribute it and/or
  * modify it under the terms of the GNU Lesser General Public
  * License as published by the Free Software Foundation; either
  * version 3 of the License, or (at your option) any later version.
  *
  * This library is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  * Lesser General Public License for more details.
  *
  * You should have received a copy of the GNU Lesser General Public
  * License along with this library; if not, see <https://www.gnu.org/licenses/>.
  *
  ******************************************************************************
  */

#ifndef GRAIN128AEAD_FPGA_H_
#define GRAIN128AEAD_FPGA_H_

#include <stdint.h>
#include <string.h>
#include "Fpgaipm.h"

// types
#define GRAIN128AEAD_FPGA_RETURN_CODE int8_t

/** \defgroup shaRet256 GRAIN128AEAD_FPGA return values
 * @{
 */
/** \name GRAIN128AEAD_FPGA return values */
///@{
#define GRAIN128AEAD_FPGA_RES_OK				 ( 0)
#define GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT (-1)
///@}
/** @} */


// public function

/**
 * @brief Compute the GRAIN128AEAD algorithm on input data depending on the current status of the GRAIN128AEAD_FPGA context.
 * @param message Pointer to the input data.
 * @param dataLen Bytes to be processed.
 * @param digest Pointer to a blank memory area that can store the computed output digest.
 * @return See \ref shaRet256.
 */
GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_encrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *msg, uint64_t msgLen,
												uint8_t *ciphertext);
GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_decrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *ciphertext, uint64_t cipherLen,
												uint8_t *msg);


#endif /* GRAIN128AEAD_FPGA_H_ */