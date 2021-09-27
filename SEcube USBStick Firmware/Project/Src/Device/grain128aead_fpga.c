/**
  ******************************************************************************
  * File Name          : grain128aead_fpga.c
  * Description        : High-level driver for communication between CPU and 
                         GRAIN128AEAD IP core in an IP-Manager-based environment
  ******************************************************************************
  */

#include <grain128aead_fpga.h>

#define GRAIN128AEAD_FPGA_CORE 0x1

static FPGA_IPM_DATA interrupt_signal = 0x0000;

static GRAIN128AEAD_FPGA_8_to_16(uint8_t dataMSV, uint8_t dataLSV, FPGA_IPM_DATA *merge) {
	merge = ( dataMSV << 8 ) || dataLSV ;
}

static void GRAIN128AEAD_FPGA_init_pack(uint8_t opcode, FPGA_IPM_DATA *key, FPGA_IPM_DATA *iv, FPGA_IPM_DATA *ad, uint8_t adLen, FPGA_IPM_DATA *msg, uint8_t msgLen, FPGA_IPM_DATA *res)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA lengths;
	int i;

	lengths = (msgLen << 8) | ( adLen & 0xFF );
	// open a interrupt transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 1, 0);
	// write the key onto the data buffer
	for(i=0; i<8; i++) {
		FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &key[i]);
		add++;
	}
	// write the iv (nonce) onto the data buffer
	 for(i=0; i<8; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &iv[i]);
	 	add++;
	 }
	 // write length(subMsg) | length(ad) onto the data buffer
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &lengths);
	 // write ad (Associated Data) onto the buffer
	 for(i=0; i<adLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &ad[i]);
	 	add++;
	 }
	 // write msg onto the buffer
	 for(i=0; i<msgLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	 	add++;
	 }
	 // lock the CPU waiting for the interrupt signal
	 while(interrupt_signal != 0x000) ;

	 /////////// TO IMPLEMENT //////////
	 //	read out intermediate digest as the new state
//	add = 0x1;
//	for(i=0; i<16; i++) {
//		FPGA_IPM_read(SHA256_FPGA_CORE, add, &state[i]);
//		add++;
//	}
	// close the polling transaction
	//FPGA_IPM_close(SHA256_FPGA_CORE);

}
static void GRAIN128AEAD_FPGA_next_pack(uint8_t opcode, FPGA_IPM_DATA *msg, uint8_t msgLen, FPGA_IPM_DATA *res)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA submsglength;
	int i;

	submsglength = (msgLen << 8);
	// open a interrupt transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 1, 0);
	 // write length(subMsg) | 0x00 onto the data buffer
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &submsglength);
	 // write ad (Associated Data) onto the buffer
	 for(i=0; i<adLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &ad[i]);
	 	add++;
	 }
	 // write msg onto the buffer
	 for(i=0; i<msgLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	 	add++;
	 }
	 // lock the CPU waiting for the interrupt signal
	 while(interrupt_signal != 0x000) ;

	 /////////// TO IMPLEMENT //////////
	 //	read out intermediate digest as the new state
//	add = 0x1;
//	for(i=0; i<16; i++) {
//		FPGA_IPM_read(SHA256_FPGA_CORE, add, &state[i]);
//		add++;
//	}
	// close the polling transaction
	//FPGA_IPM_close(SHA256_FPGA_CORE);

}

GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_encrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *msg, uint64_t msgLen,
												uint8_t *ciphertext) {

	int i, i_msg = 0;
	FPGA_IPM_DATA msgBlock[60], ADblock[10];
	uint64_t left;
	uint8_t submsgLen, subADlen;
	//FPGA_IPM_DATA res[msgLen+1+8];

	if( (key == NULL) || (IV == NULL) || (AD == NULL) ) return SHA256_FPGA_RES_INVALID_ARGUMENT;

	for(i = 0; i < ADlen/2 ; i++ )
		GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ], ADblock[i]);

	if(ADlen % 2 == 1) {
		GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ], ADblock[i]);
	}
	subADlen = i;

	if (msgLen == 0) {
		GRAIN128AEAD_FPGA_init_pack(0x00, key, iv, ADblock, subADlen, msg, msgLen);
	} else {
		left = msgLen;

		while ( left > 120 ){
			if ( i_msg == 0 ) {
				// INIT PACKET
				for(i = 0; i < 32 ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(msg[i_msg], msg[i_msg + 1], msgblock[i]);
					i_msg += 2;
				}
				submsgLen = 32;
				GRAIN128AEAD_FPGA_init_pack(0x00, key, iv, ADblock, subADlen, msg, submsgLen);
				left -= 64;
			} else {
				// OTHERS PACKET WITH ONLY MESSAGE
				for(i = 0; i < 60 ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(msg[i_msg], msg[i_msg + 1], msgblock[i]);
					i_msg += 2;
				}
				submsgLen = 60;
				GRAIN128AEAD_FPGA_next_pack(0x01, msg, submsgLen);
				left -= 120;
			}
		}
		for(i = 0; i < left/2 ; i++ ){
			GRAIN128AEAD_FPGA_8_to_16(msg[i_msg], msg[i_msg + 1], msgblock[i]);
			i_msg += 2;
		}
		if(left % 2 == 1)
			GRAIN128AEAD_FPGA_8_to_16(msg[i_msg], msg[i_msg + 1], msgblock[i]);

		submsgLen = i;
		GRAIN128AEAD_FPGA_next_pack(0x01, msg, submsgLen);
	}

	return GRAIN128AEAD_FPGA_RES_OK;
}
GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_decrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *ciphertext, uint64_t cipherLen,
												uint8_t *msg){
	int i, i_cipher = 0;
		FPGA_IPM_DATA cipherBlock[60], ADblock[10];
		uint64_t left;
		uint8_t subcipherLen, subADlen;

		if( (key == NULL) || (IV == NULL) || (AD == NULL) || (ciphertext == NULL) || ( cipherLen == 0 ) ) return SHA256_FPGA_RES_INVALID_ARGUMENT;

		for(i = 0; i < ADlen/2 ; i++ )
			GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ], ADblock[i]);

		if(ADlen % 2 == 1) {
			GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ], ADblock[i]);
		}
		subADlen = i;

		left = cipherLen;

		while ( left > 120 ){
			if ( i_cipher == 0 ) {
				// INIT PACKET
				for(i = 0; i < 32 ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(ciphertext[i_cipher], ciphertext[i_cipher + 1], cipherblock[i]);
					i_cipher += 2;
				}
				subcipherLen = 32;
				GRAIN128AEAD_FPGA_init_pack(0x02, key, iv, ADblock, subADlen, ciphertext, subcipherLen);
				left -= 64;
			} else {
				// OTHERS PACKET WITH ONLY MESSAGE
				for(i = 0; i < 60 ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(ciphertext[i_cipher], ciphertext[i_cipher + 1], cipherblock[i]);
					i_cipher += 2;
				}
				subcipherLen = 60;
				GRAIN128AEAD_FPGA_next_pack(0x03, ciphertext, subcipherLen);
				left -= 120;
			}
		}
		for(i = 0; i < left/2 ; i++ ){
			GRAIN128AEAD_FPGA_8_to_16(ciphertext[i_cipher], ciphertext[i_cipher + 1], cipherblock[i]);
			i_cipher += 2;
		}
		if(left % 2 == 1)
			GRAIN128AEAD_FPGA_8_to_16(ciphertext[i_cipher], ciphertext[i_cipher + 1], cipherblock[i]);

		subcipherLen = i;
		GRAIN128AEAD_FPGA_next_pack(0x03, ciphertext, subcipherLen);


		return GRAIN128AEAD_FPGA_RES_OK;
}
