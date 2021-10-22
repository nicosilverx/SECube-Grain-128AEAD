/**
  ******************************************************************************
  * File Name          : grain128aead_fpga.c
  * Description        : High-level driver for communication between CPU and 
                         GRAIN128AEAD IP core in an IP-Manager-based environment
  ******************************************************************************
  */

#include <grain128aead_fpga.h>

#define GRAIN128AEAD_FPGA_CORE 0x1


static FPGA_IPM_DATA GRAIN128AEAD_FPGA_8_to_16(uint8_t dataMSV, uint8_t dataLSV) {
	return ( dataMSV << 8 ) | dataLSV ;
}

static void GRAIN128AEAD_FPGA_init_pack(FPGA_IPM_DATA *key,
										FPGA_IPM_DATA *iv,
										FPGA_IPM_DATA *ad, uint8_t adLen,
										FPGA_IPM_DATA *msg, uint8_t msgLen,
										FPGA_IPM_DATA *res, uint8_t *i_res, uint8_t readMAC, FPGA_IPM_OPCODE opcode)
{

	FPGA_IPM_ADDRESS add = 1;
	FPGA_IPM_DATA lengths;
	uint8_t index_res = *i_res;
	FPGA_IPM_DATA polling_semaphore = 0x0000;
	int i;
	FPGA_IPM_BOOLEAN ret;

	lengths = ( msgLen << 8) | adLen ;
	// open a polling transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 0, 0);
	// write the key onto the data buffer
	for(i=0; i < GRAIN128AEAD_FPGA_WORDS_KEY; i++) {
		key[i] = GRAIN128AEAD_FPGA_8_to_16(key[i] & 0x00FF, (key[i] & 0xFF00) >> 8);
		ret = FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &key[i]);
		add++;
	}
	// write the iv (nonce) onto the data buffer
	 for(i=0; i < GRAIN128AEAD_FPGA_WORDS_IV; i++) {
		iv[i] = GRAIN128AEAD_FPGA_8_to_16(iv[i] & 0x00FF, (iv[i] & 0xFF00) >> 8);
		ret = FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &iv[i]);
		add++;
	 }
	 //2 words are left unwritten
	 add+=GRAIN128AEAD_FPGA_WORDS_UNUSED;
	 // write length(subMsg) | length(ad) onto the data buffer
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &lengths);
	 add++;
	 // write ad (Associated Data) onto the buffer
	 for(i=0; i < adLen/2; i++) {
		 ret = FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &ad[i]);
 	 	 add++;
	 }
	 // write msg onto the buffer
	 add = 	GRAIN128AEAD_FPGA_WORDS_CW +
			GRAIN128AEAD_FPGA_WORDS_KEY +
			GRAIN128AEAD_FPGA_WORDS_IV +
			GRAIN128AEAD_FPGA_WORDS_UNUSED +
			GRAIN128AEAD_FPGA_WORDS_LENGHTS +
			GRAIN128AEAD_FPGA_WORDS_AD_MAX;

	 for(i=0; i < msgLen/2; i++) {
		 ret = FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	 	 add++;
	 }
	 for(i=0;i<64;i++){
		 FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, i, &polling_semaphore);
	 }
	 // lock the CPU and wait for core unlocking
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	 while(polling_semaphore != 0xFFFF) {
		HAL_Delay(100);
	 	FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	 }

	 //read out results from data buffer
	add = 	GRAIN128AEAD_FPGA_WORDS_CW +
			GRAIN128AEAD_FPGA_WORDS_KEY +
			GRAIN128AEAD_FPGA_WORDS_IV +
			GRAIN128AEAD_FPGA_WORDS_UNUSED +
			GRAIN128AEAD_FPGA_WORDS_LENGHTS +
			GRAIN128AEAD_FPGA_WORDS_AD_MAX;
	// reading data buffer to retrieve IP core response
	for(i=0; i < msgLen/2; i++, index_res++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res]);
		add++;
	}
	if( readMAC ) {
		add = 	GRAIN128AEAD_FPGA_WORDS_CW +
				GRAIN128AEAD_FPGA_WORDS_KEY +
				GRAIN128AEAD_FPGA_WORDS_IV +
				GRAIN128AEAD_FPGA_WORDS_UNUSED +
				GRAIN128AEAD_FPGA_WORDS_LENGHTS +
				GRAIN128AEAD_FPGA_WORDS_AD_MAX +
				GRAIN128AEAD_FPGA_WORDS_INIT_PACK;

		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++, index_res++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res]);
			add++;
		}
	}
	*i_res = index_res;

	// close the interrupt transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);
}

static void GRAIN128AEAD_FPGA_next_pack(FPGA_IPM_DATA *msg, uint8_t msgLen, FPGA_IPM_DATA *res, uint8_t *i_res, uint8_t readMAC, FPGA_IPM_OPCODE opcode)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA submsglength;
	FPGA_IPM_DATA polling_semaphore = 0x0000;
	uint8_t index_res = *i_res;
	int i;

	submsglength = (msgLen << 8);
	// open a polling transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 0, 0);
	//write length
	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &submsglength);
	add++;
	// write msg onto the buffer
	for(i=0; i < msgLen/2; i++) {
		FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
		add++;
	}
	for(i=0;i<64;i++){
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, i, &polling_semaphore);
	}

	// lock the CPU and wait for core unlocking
	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	while(polling_semaphore != 0xFFFF) {
		HAL_Delay(100);
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	}

	//read out results from data buffer
	add = 	GRAIN128AEAD_FPGA_WORDS_CW +
			GRAIN128AEAD_FPGA_WORDS_LENGHTS;
	for(i=0; i < msgLen/2; i++, index_res++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res]);
		add++;
	}

	if( readMAC ) {
		add = 	GRAIN128AEAD_FPGA_WORDS_CW +
				GRAIN128AEAD_FPGA_WORDS_KEY +
				GRAIN128AEAD_FPGA_WORDS_IV +
				GRAIN128AEAD_FPGA_WORDS_UNUSED +
				GRAIN128AEAD_FPGA_WORDS_LENGHTS +
				GRAIN128AEAD_FPGA_WORDS_AD_MAX +
				GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++, index_res++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &res[index_res ]);
			add++;
		}
	}
	*i_res = index_res;
	// close the interrupt transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);
}

static GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_CHIPHER(  uint8_t *key,
															uint8_t *IV,
															uint8_t *AD, uint8_t ADlen,
															const uint8_t *dataIN, uint64_t datainLen,
															uint8_t *dataOUT, FPGA_IPM_OPCODE opcode) {

	int i, i_datain = 0, i_res = 0;

	int t;

	FPGA_IPM_DATA datainBlock[GRAIN128AEAD_FPGA_WORDS_NEXT_PACK], ADblock[GRAIN128AEAD_FPGA_WORDS_AD_MAX], keyBlock[GRAIN128AEAD_FPGA_WORDS_KEY], ivBlock[GRAIN128AEAD_FPGA_WORDS_IV];
	uint64_t left, resLen;
	uint8_t available_dataLen = 2*GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
	uint8_t subdatainLen, subADlen;
	resLen = datainLen + 1 + GRAIN128AEAD_FPGA_WORDS_MAC; // the result length will take into account the MAC and an extra word to manage the odd datainLen size
	FPGA_IPM_DATA res[resLen];

	if( (key == NULL) || (IV == NULL) || (AD == NULL) )
		return GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT;
	else if( (ADlen > 2*GRAIN128AEAD_FPGA_WORDS_AD_MAX) || (sizeof(key) > 2*GRAIN128AEAD_FPGA_WORDS_KEY) || (sizeof(IV) > 2*GRAIN128AEAD_FPGA_WORDS_IV) )
		return GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT;


	// transform KEY in a block of words ready to be written inside the data buffer
	for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_KEY ; i++ ){
		keyBlock[i] = GRAIN128AEAD_FPGA_8_to_16(key[ 2*i ], key[ 2*i + 1 ]);
	}

	for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_IV ; i++ ){
		ivBlock[i] = GRAIN128AEAD_FPGA_8_to_16(IV[ 2*i ], IV[ 2*i + 1 ]);
	}

	// transform AD in a block of words ready to be written inside the data buffer
	for(i = 0; i < ADlen/2 ; i++ ) {
		ADblock[i] = GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], AD[ 2*i + 1 ] );
	}

	// if the total number of AD bytes is odd, the last bytes will be placed on the upper position of a word
	if(ADlen % 2 == 1) {
		ADblock[i] = GRAIN128AEAD_FPGA_8_to_16(AD[ 2*i ], 0);
		i++;
	}

	// save number of words created inside ADblock
	subADlen = i;

	if (datainLen == 0) {
		// In there is no msg, send just the data required for the init packet, waiting only for the MAC as result
		//( 1 tells to the function to save further 4 word starting from address when it is supposed to be the message)
		GRAIN128AEAD_FPGA_init_pack(key, IV, ADblock, ADlen, dataIN, datainLen, res, &i_res, GRAIN128AEAD_FPGA_WRITE_MAC, opcode);
	} else {
		left = datainLen;
		// This loop is in charge of create packet as soon as the remain bytes is enough to create complete packet of 58 words as message/ciphertext
		while ( left > available_dataLen ){ // maggiore di 16 TO MODIFY
			// Create packet init, just at the beginning
			if ( i_datain == 0 ) {
				// INIT PACKET
				// transform dataIN in a block of 30 words ready to be written inside the data buffer
				for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_INIT_PACK ; i++ ){
					datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1] );
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = 2*GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
				// write INIT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_init_pack(key, IV, ADblock, ADlen, datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_NOT_WRITE_MAC, opcode);
				// decrement the remaining datainLen of 30 words ( 60 bytes)
				left -= 2*GRAIN128AEAD_FPGA_WORDS_INIT_PACK;
			} else {
				// OTHERS PACKET WITH ONLY MESSAGE
				// transform dataIN in a block of 58 words ready to be written inside the data buffer
				for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_NEXT_PACK ; i++ ){
					datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1] );
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = 2*GRAIN128AEAD_FPGA_WORDS_NEXT_PACK;
				// write NEXT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_NOT_WRITE_MAC, opcode + 1);
				// decrement the remaining datainLen of 58 words ( 116 bytes)
				left -= 2*GRAIN128AEAD_FPGA_WORDS_NEXT_PACK;
			}
		}
		// Last packet to be sent or it's 
		for(i = 0; i < left/2 ; i++ ){
			datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1] );
			i_datain += 2;
		}
		if(left % 2 == 1) {
			datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(dataIN[i_datain], dataIN[i_datain + 1] );
			i++;
		}
		subdatainLen = 2*i;
		if ( left == datainLen ) {
			GRAIN128AEAD_FPGA_init_pack(key, IV, ADblock, ADlen, datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_WRITE_MAC, opcode);
		} else {
			GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, GRAIN128AEAD_FPGA_WRITE_MAC, opcode + 1);
		}
	}

	for(i=0; i < i_res; i++) {
		dataOUT[2*i] = ( res[i] & 0xFF00 ) >> 8;
		dataOUT[2*i+1] = res[i] & 0x00FF ;
	}


	return GRAIN128AEAD_FPGA_RES_OK;

}

GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_encrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *msg, uint64_t msgLen,
												uint8_t *ciphertext) {

	return GRAIN128AEAD_CHIPHER(key, IV, AD, ADlen, msg, msgLen, ciphertext, GRAIN128AEAD_FPGA_OPCODE_ENCR);


}
GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_FPGA_decrypt (
												uint8_t *key,
												uint8_t *IV,
												uint8_t *AD, uint8_t ADlen,
												const uint8_t *ciphertext, uint64_t cipherLen,
												uint8_t *msg){

	return GRAIN128AEAD_CHIPHER(key, IV, AD, ADlen, ciphertext, cipherLen, msg, GRAIN128AEAD_FPGA_OPCODE_DECR);

}
