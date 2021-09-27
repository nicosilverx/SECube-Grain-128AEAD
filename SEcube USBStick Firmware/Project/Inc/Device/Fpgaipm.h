/**
  ******************************************************************************
  * File Name          : Fpgaipm.h
  * Description        : Low-level APIs for CPU-FPGA communication in an 
  						 IP-Manager-based environment
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

#ifndef FPGAIPM_H_
#define FPGAIPM_H_

#include "stm32f4xx_hal.h"
#include "stm32f4xx_hal_sram.h"
#include "stm32f4xx.h"

// class types
#define FPGA_IPM_UINT8   uint8_t
#define FPGA_IPM_UINT16  uint16_t
#define FPGA_IPM_BOOLEAN int
#define FPGA_IPM_SEM     FPGA_IPM_BOOLEAN

// specific types
#define FPGA_IPM_CORE    FPGA_IPM_UINT8
#define FPGA_IPM_ADDRESS FPGA_IPM_UINT8
#define FPGA_IPM_DATA    FPGA_IPM_UINT16
#define FPGA_IPM_OPCODE  FPGA_IPM_UINT8

// masks
#define FPGA_IPM_CORE_MASK    0b1111111u
#define FPGA_IPM_ADDRESS_MASK 0b111111u
#define FPGA_IPM_OPCODE_MASK  0b111111u

// offsets
#define FPGA_IPM_OPCODE_OFFSET 10

// constants
#define FPGA_IPM_BEGIN_TRANSACTION 0b0000000010000000u
#define FPGA_IPM_ACK 			   0b0000000100000000u
#define FPGA_IPM_INTERRUPT_MODE    0b0000001000000000u
#define FPGA_IPM_SRAM_BASE_ADDR    0x60000000U

// public functions

/** \brief Initialise CPU-FPGA communication environment
 *  \return 0 on success
 */
FPGA_IPM_BOOLEAN FPGA_IPM_init(void);

/** \brief Opens a transaction with a given IP core
 *  \param coreID unique identifier/address of the core
 *  \param opcode operative code to be sent to the core
 *  \param interruptMode to be set at 1 if the transaction is in interrupt mode, at 0 if it is in polling mode
 *  \param ack to be set at 1 if the transaction is an acknowledge transaction, at 0 if it is not
 *  \return Returns 0 on success
 */
FPGA_IPM_BOOLEAN FPGA_IPM_open(FPGA_IPM_CORE coreID, FPGA_IPM_OPCODE opcode, FPGA_IPM_BOOLEAN interruptMode, FPGA_IPM_BOOLEAN ack);

/** \brief Reads a 16-bit word from the buffer
 *  \param coreID unique identifier/address of the core
 *  \param address memory offset within the buffer (from 0x01 (1) to 0x3F (63))
 *  \param dataPtr pointer to be filled with the data read
 *  \return Returns 0 on success
 */
FPGA_IPM_BOOLEAN FPGA_IPM_read(FPGA_IPM_CORE coreID, FPGA_IPM_ADDRESS address, FPGA_IPM_DATA *dataPtr);

/** \brief Writes a 16-bit word in the buffer
 *  \param coreID unique identifier/address of the core
 *  \param address memory offset within the buffer (from 0x01 (1) to 0x3F (63))
 *  \param dataPtr pointer to the data to be written
 *  \return Returns 0 on success
 */
FPGA_IPM_BOOLEAN FPGA_IPM_write(FPGA_IPM_CORE coreID, FPGA_IPM_ADDRESS address, FPGA_IPM_DATA *dataPtr);

/** \brief Closes a transaction with a given IP core
 *  \param coreID unique identifier/address of the core
 *  \return Returns 0 on success
 */
FPGA_IPM_BOOLEAN FPGA_IPM_close(FPGA_IPM_CORE coreID);

#endif /* FPGAIPM_H_ */

