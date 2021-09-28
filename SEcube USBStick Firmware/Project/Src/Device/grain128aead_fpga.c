/**
  ******************************************************************************
  * File Name          : grain128aead_fpga.c
  * Description        : High-level driver for communication between CPU and 
                         GRAIN128AEAD IP core in an IP-Manager-based environment
  ******************************************************************************
  */

#include <grain128aead_fpga.h>

#define GRAIN128AEAD_FPGA_CORE 0x1

static FPGA_IPM_DATA interrupt_signal;

static void GRAIN128AEAD_FPGA_8_to_16(uint8_t dataMSV, uint8_t dataLSV, FPGA_IPM_DATA *merge) {
	merge = ( dataMSV << 8 ) || dataLSV ;
}

static void GRAIN128AEAD_FPGA_init_pack(FPGA_IPM_DATA *key,
										FPGA_IPM_DATA *iv,
										FPGA_IPM_DATA *ad, uint8_t adLen,
										FPGA_IPM_DATA *msg, uint8_t msgLen,
										FPGA_IPM_DATA *res, uint8_t *i_res, uint8_t readMAC)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA lengths;
	uint8_t index_res = *i_res;
	interrupt_signal = 0x0000;
	int i;

	lengths = (msgLen << 8) | ( adLen & 0xFF );
	// open a interrupt transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, GRAIN128AEAD_FPGA_OPCODE, 1, 0);
	// write the key onto the data buffer
	for(i=0; i < GRAIN128AEAD_FPGA_WORDS_KEY; i++) {
		FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &key[i]);
		add++;
	}
	// write the iv (nonce) onto the data buffer
	 for(i=0; i < GRAIN128AEAD_FPGA_WORDS_IV; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &iv[i]);
	 	add++;
	 }
	 // write length(subMsg) | length(ad) onto the data buffer
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &lengths);
	 // write ad (Associated Data) onto the buffer
	 for(i=0; i < adLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &ad[i]);
	 	add++;
	 }
	 add+=GRAIN128AEAD_FPGA_WORDS_UNUSED; //2 words are left unwritten

	 // write msg onto the buffer
	 for(i=0; i < msgLen; i++) {
	 	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	 	add++;
	 }
	 // lock the CPU waiting for the interrupt signal
	 while(interrupt_signal != 0x000) ;

	 //read out results from data buffer
	add = 	GRAIN128AEAD_FPGA_WORDS_CW +
			GRAIN128AEAD_FPGA_WORDS_KEY +
			GRAIN128AEAD_FPGA_WORDS_IV +
			GRAIN128AEAD_FPGA_WORDS_UNUSED +
			GRAIN128AEAD_FPGA_WORDS_LENGHTS +
			adLen;

	for(i=0; i < msgLen; i++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res + i]);
		add++;
	}
	if( readMAC ) {
		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res + i]);
			add++;
		}
	}
	// close the interrupt transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);

}

// POSSIBLE ERROR WHEN A TRANSACTION IS GONNA BE OPEN -> ACK_BIT = 1
static void GRAIN128AEAD_FPGA_next_pack(FPGA_IPM_DATA *msg, uint8_t msgLen, FPGA_IPM_DATA *res, uint8_t *i_res, uint8_t readMAC)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA submsglength;
	interrupt_signal = 0x0000;
	uint8_t index_res = *i_res;
	int i;

	submsglength = (msgLen << 8);
	// open a interrupt transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, GRAIN128AEAD_FPGA_OPCODE, 1, 0);
	// write msg onto the buffer
	for(i=0; i < msgLen; i++) {
	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	add++;
	}
	// lock the CPU waiting for the interrupt signal
	while(interrupt_signal != 0x000) ;

	 //read out results from data buffer
	add = 	GRAIN128AEAD_FPGA_WORDS_CW +
			GRAIN128AEAD_FPGA_WORDS_LENGHTS;

	for(i=0; i < msgLen; i++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res + i]);
		add++;
	}

	if( readMAC ) {
		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res + i]);
			add++;
		}
	}
	// close the interrupt transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);

}

static GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_CHIPHER(  uint8_t *key,
															uint8_t *IV,
															uint8_t *AD, uint8_t ADlen,
															const uint8_t *dataIN, uint64_t datainLen,
															uint8_t *dataOUT) {

	int i, i_datain = 0, i_res = 0;
	FPGA_IPM_DATA datainBlock[GRAIN128AEAD_FPGA_WORDS_NEXT_PACK], ADblock[GRAIN128AEAD_FPGA_WORDS_AD_MAX];
	uint64_t left, resLen;
	uint8_t available_dataLen = 2*GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
	uint8_t subdatainLen, subADlen;
	resLen = datainLen + 1 + GRAIN128AEAD_FPGA_WORDS_MAC; // the result length will take into account the MAC and an extra word to manage the odd datainLen size
	FPGA_IPM_DATA res[resLen];

	if( (key == NULL) || (IV == NULL) || (AD == NULL) ) return GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT;

	// transform AD in a block of words ready to be written inside the data buffer
	for(i = 0; i < ADlen/2 ; i++ )
		GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ], ADblock[i]);
	// if the total number of AD bytes is odd, the last bytes will be placed on the upper position of a word
	if(ADlen % 2 == 1) {
		GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], 0, ADblock[i]);
		i++;
	}

	// save number of words created inside ADblock
	subADlen = i;

	if (datainLen == 0)
		// In there is no msg, send just the data required for the init packet, waiting only for the MAC as result
		//( 1 tells to the function to save further 4 word starting from address when it is supposed to be the message)
		GRAIN128AEAD_FPGA_init_pack(key, IV, ADblock, subADlen, dataIN, datainLen, res, &i_res, 1);
	else {
		left = datainLen;
		// This loop is in charge of create packet as soon as the remain bytes is enough to create complete packet of 58 words as message/ciphertext
		while ( left > available_dataLen ){
			// Create packet init, just at the beginning
			if ( i_datain == 0 ) {
				// INIT PACKET
				// transform dataIN in a block of 30 words ready to be written inside the data buffer
				for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_INIT_PACK ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1], datainBlock[i]);
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
				// write INIT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_init_pack(key, IV, ADblock, subADlen, datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_NOT_WRITE_MAC);
				// decrement the remaining datainLen of 30 words ( 60 bytes)
				left -= 2*GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
				available_dataLen = 2*GRAIN128AEAD_FPGA_WORDS_NEXT_PACK;
			} else {
				// OTHERS PACKET WITH ONLY MESSAGE
				// transform dataIN in a block of 58 words ready to be written inside the data buffer
				for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_NEXT_PACK ; i++ ){
					GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1], datainBlock[i]);
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = GRAIN128AEAD_FPGA_WORDS_NEXT_PACK;
				// write NEXT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_NOT_WRITE_MAC);
				// decrement the remaining datainLen of 58 words ( 116 bytes)
				left -= 2*GRAIN128AEAD_FPGA_WORDS_NEXT_PACK;
			}
		}
		// Last packet to be sent or it's
		for(i = 0; i < left/2 ; i++ ){
			GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1], datainBlock[i]);
			i_datain += 2;
		}
		if(left % 2 == 1) {
			GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1], datainBlock[i]);
			i++;
		}

		subdatainLen = i;
		GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_WRITE_MAC);
	}

	for(i=0; i < datainLen/2; i++) {
		dataOUT[2*i] = ( res[i] & 0xF0 ) >> 8;
		dataOUT[2*i+1] = res[i] & 0x0F ;
	}
	if(left % 2 == 1)
		dataOUT[2*i] = ( res[i] & 0xF0 ) >> 8;

	i_res = i;
	for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++) {
		dataOUT[2*i_res] = ( res[i_res] & 0xF0 ) >> 8;
		dataOUT[2*i_res+1] = res[i_res] & 0x0F ;
	}

	return GRAIN128AEAD_FPGA_RES_OK;

}

GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_encrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *msg, uint64_t msgLen,
												uint8_t *ciphertext) {

	return GRAIN128AEAD_CHIPHER(key, IV, AD, ADlen, msg, msgLen, ciphertext);


}
GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_decrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *ciphertext, uint64_t cipherLen,
												uint8_t *msg){

	return GRAIN128AEAD_CHIPHER(key, IV, AD, ADlen, ciphertext, cipherLen, msg);

}
