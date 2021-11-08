/**
  ******************************************************************************
  * File Name          : grain128aead_fpga.c
  * Description        : High-level driver for communication between CPU and 
                         GRAIN128AEAD IP core in an IP-Manager-based environment
  ******************************************************************************
  */

#include <grain128aead_fpga.h>

#define GRAIN128AEAD_FPGA_CORE 0x1

static FPGA_CLEAR_DATA_BUFFER(){
	//CLEAR DATABUFFER
	FPGA_IPM_DATA add = 0x0;
	FPGA_IPM_DATA zero = 0x0;
	FPGA_IPM_open(0x1, 0x0, 0, 0);
	for(int i=0; i<64; i++){
		FPGA_IPM_write(0x0, add, &zero);
	}
	FPGA_IPM_close(0x0);
}


static FPGA_IPM_DATA GRAIN128AEAD_FPGA_8_to_16(uint8_t dataMSV, uint8_t dataLSV) {
	return ( dataMSV << 8 ) | dataLSV ;
}

static void GRAIN128AEAD_FPGA_init_pack(FPGA_IPM_DATA *key,
										FPGA_IPM_DATA *iv,
										FPGA_IPM_DATA *ad, uint8_t adLen,
										FPGA_IPM_DATA *msg, uint8_t msgLen,
										FPGA_IPM_DATA *res, uint8_t *i_res, FPGA_IPM_OPCODE opcode)
{

	FPGA_IPM_ADDRESS add = 1;
	FPGA_IPM_DATA lengths;
	uint8_t index_res = *i_res;
	FPGA_IPM_DATA polling_semaphore;
	int i;
	FPGA_IPM_BOOLEAN ret;
	FPGA_IPM_DATA data_bytes;
	FPGA_IPM_DATA words_data_res[msgLen/2];
	FPGA_IPM_DATA words_mac_res[4];
	FPGA_IPM_DATA words_mac_inv[4] = {0};
	FPGA_IPM_DATA words_ct_inv[msgLen/2];

	//Inversion
	if ( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR ){
		data_bytes = msgLen;
		for(size_t j=0; j<data_bytes/2 ; j++){
			words_ct_inv[(data_bytes/2 - 1) - j] =  msg[j];
		}
		memcpy(msg, words_ct_inv, sizeof(FPGA_IPM_DATA)*data_bytes/2);
		for(size_t j=0; j<data_bytes/2 ; j++){
		}
	}else{
		//post encryption , init decryption
		data_bytes = msgLen - 8;

		FPGA_IPM_DATA datain_mac[4];
		FPGA_IPM_DATA datain_mac_inv[4] = {0};
		FPGA_IPM_DATA datain_ct[data_bytes/2];
		FPGA_IPM_DATA datain_ct_inv[data_bytes/2];

		memcpy(datain_mac, msg + (data_bytes/2), sizeof(FPGA_IPM_DATA)*4);

		memcpy(datain_ct, msg, sizeof(FPGA_IPM_DATA)*(data_bytes/2));

		//MAC inversion
		for(size_t j=0; j<4 ; j++){
			datain_mac_inv[(4-1) - j] =  datain_mac[j];
		}

		//CT inversion
		for(size_t j=0; j<data_bytes/2 ; j++){
			datain_ct_inv[(data_bytes/2 - 1) - j] =  datain_ct[j];
		}

		memcpy(msg, datain_ct_inv, sizeof(FPGA_IPM_DATA)*(data_bytes/2));
		memcpy(msg + (data_bytes/2), datain_mac_inv, sizeof(FPGA_IPM_DATA)*4);

	}

	// open a polling transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 0, 0);

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

	 //2 words are left unwritten
	 add+=GRAIN128AEAD_FPGA_WORDS_UNUSED;

	 // write length(subMsg) | length(ad) onto the data buffer
	 lengths = ( data_bytes << 8) | adLen ;
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &lengths);
	 add++;

	 // write ad (Associated Data) onto the buffer
	 for(i=0; i < adLen/2; i++) {
		 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &ad[i]);
 	 	 add++;
	 }
	 // write msg onto the buffer
	 add = GRAIN128AEAD_FPGA_ADDR_MSG_INIT_PACK;

	 for(i=0; i < msgLen/2; i++) {
		 ret = FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
	 	 add++;
	 }
	 FPGA_IPM_DATA tmp = 0x0;
	 FPGA_IPM_DATA unlock_polling = 0;

	 // Printing data buffer

	 tmp = 0x0;

	 tmp = 0x0;
	 FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &tmp);

	 if(tmp == 0xFFFF)
		 unlock_polling = 1;
	 else
		 unlock_polling = 0;

	// HAL_Delay(1000);
	 // Polling

	 if(unlock_polling == 0){
		 polling_semaphore = 0x0000;
		 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);

		 while(polling_semaphore != (FPGA_IPM_DATA)0xFFFF) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
		 }
	 }


	 //Clean the polling word
	 polling_semaphore = 0x0000;
     FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	 // Printing data buffer
	 tmp = 0x0;

	//read out results from data buffer
	add = GRAIN128AEAD_FPGA_ADDR_MSG_INIT_PACK;

//////////////NEW INVERSION OUTPUT////////////////////////////////
	for(i=0; i < data_bytes/2; i++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &words_data_res[i]);
		add++;
	}

	// Reading MAC only during enryption
	if( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR ) {
		add = GRAIN128AEAD_FPGA_ADDR_MAC;

		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &words_mac_res[i]);
			add++;
		}
		uint8_t ct_words, mac_words;
		ct_words = data_bytes/2;
		mac_words = 4;
		//MAC invertion
		for(size_t j=0; j<mac_words ; j++){
			words_mac_inv[(mac_words-1) - j] =  words_mac_res[j];
		}
		//CT invertion
		for(size_t j=0; j<ct_words ; j++){
			words_ct_inv[(ct_words - 1) - j] =  words_data_res[j];
		}
		for(size_t i=0;i<ct_words;i++, index_res++)
			res[index_res] = words_ct_inv[i];
		for(size_t i=0;i<mac_words;i++, index_res++)
			res[index_res] = words_mac_inv[i];

	} else {

		for(size_t j=0; j<data_bytes/2 ; j++){
			words_ct_inv[((data_bytes/2) - 1) - j] =  words_data_res[j];
		}
		for(size_t i=0;i<data_bytes/2;i++, index_res++)
			res[index_res] = words_ct_inv[i];
	}


	*i_res = index_res;
	// close the polling transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);
	//FPGA_CLEAR_DATA_BUFFER();
}

static void GRAIN128AEAD_FPGA_next_pack(FPGA_IPM_DATA *msg, uint8_t msgLen, FPGA_IPM_DATA *res, uint8_t *i_res, FPGA_IPM_OPCODE opcode)
{

	FPGA_IPM_ADDRESS add = 0x1;
	FPGA_IPM_DATA submsglength;
	FPGA_IPM_DATA polling_semaphore;
	uint8_t index_res = *i_res;
	int i;
	FPGA_IPM_DATA data_bytes;
	FPGA_IPM_DATA words_data_res[msgLen/2];
	FPGA_IPM_DATA words_mac_res[4];
	FPGA_IPM_DATA words_mac_inv[4] = {0};
	FPGA_IPM_DATA words_ct_inv[msgLen/2];

////////////////////NEW INVERSION////////////////////////////////////////////////////////////////////
	//Inversion
		if ( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR+1){
			data_bytes = msgLen;
			for(size_t j=0; j<data_bytes/2 ; j++){
				words_ct_inv[(data_bytes/2 - 1) - j] =  msg[j];
			}
			memcpy(msg, words_ct_inv, sizeof(FPGA_IPM_DATA)*data_bytes/2);

		}else{
			//post encryption , init decryption
			data_bytes = msgLen - 8;

			FPGA_IPM_DATA datain_mac[4];
			FPGA_IPM_DATA datain_mac_inv[4] = {0};
			FPGA_IPM_DATA datain_ct[data_bytes/2];
			FPGA_IPM_DATA datain_ct_inv[data_bytes/2];

			memcpy(datain_mac, msg + (data_bytes/2), sizeof(FPGA_IPM_DATA)*4);

			memcpy(datain_ct, msg, sizeof(FPGA_IPM_DATA)*(data_bytes/2));

			//MAC inversion
			for(size_t j=0; j<4 ; j++){
				datain_mac_inv[(4-1) - j] =  datain_mac[j];
			}

			//CT inversion
			for(size_t j=0; j<data_bytes/2 ; j++){
				datain_ct_inv[(data_bytes/2 - 1) - j] =  datain_ct[j];
			}

			memcpy(msg, datain_ct_inv, sizeof(FPGA_IPM_DATA)*(data_bytes/2));
			memcpy(msg + (data_bytes/2), datain_mac_inv, sizeof(FPGA_IPM_DATA)*4);
		}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// open a polling transaction
	FPGA_IPM_open(GRAIN128AEAD_FPGA_CORE, opcode, 0, 0);

	//write length
	submsglength = (data_bytes << 8);
	FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &submsglength);
	add++;

	// write message onto the buffer
	for(i=0; i < msgLen/2; i++) {
		FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, add, &msg[i]);
		add++;
	}

	FPGA_IPM_DATA tmp = 0x0;
	FPGA_IPM_DATA unlock_polling = 0;

	 // Printing data buffer
	 tmp = 0x0;

	 FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &tmp);

	 if(tmp == 0xFFFF)
		 unlock_polling = 1;
	 else
		 unlock_polling = 0;

	 // Polling

	 if(unlock_polling == 0){
		 polling_semaphore = 0x0000;
		 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);

		 while(polling_semaphore != (FPGA_IPM_DATA)0xFFFF) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
		 }
	 }


	 //Clean the polling word
	 polling_semaphore = 0x0000;
	 FPGA_IPM_write(GRAIN128AEAD_FPGA_CORE, 0x3F, &polling_semaphore);
	 // Printing data buffer
	 tmp = 0x0;
	//read out results from data buffer
	add = GRAIN128AEAD_FPGA_ADDR_MSG_NEXT_PACK;


//////////NEW INVERSION ///////////////////////////////////////////
	for(i=0; i < data_bytes/2; i++) {
		FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &words_data_res[i]);
		add++;
	}

	// Reading MAC only during enryption
	if( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR+1) {
		add = GRAIN128AEAD_FPGA_ADDR_MAC;

		for(i=0; i < GRAIN128AEAD_FPGA_WORDS_MAC; i++) {
			FPGA_IPM_read(GRAIN128AEAD_FPGA_CORE, add, &words_mac_res[i]);
			add++;
		}
		uint8_t ct_words, mac_words;
		ct_words = data_bytes/2;
		mac_words = 4;
		//MAC invertion
		for(size_t j=0; j<mac_words ; j++){
			words_mac_inv[(mac_words-1) - j] =  words_mac_res[j];
		}
		//CT invertion
		for(size_t j=0; j<ct_words ; j++){
			words_ct_inv[(ct_words - 1) - j] =  words_data_res[j];
		}
		for(size_t i=0;i<ct_words;i++, index_res++)
			res[index_res] = words_ct_inv[i];

		for(size_t i=0;i<mac_words;i++, index_res++)
			res[index_res] = words_mac_inv[i];

	} else {

		for(size_t j=0; j<data_bytes/2 ; j++){
			words_ct_inv[((data_bytes/2) - 1) - j] =  words_data_res[j];
	}
		for(size_t i=0;i<data_bytes/2;i++, index_res++)
			res[index_res] = words_ct_inv[i];
	}

	*i_res = index_res;

	// close the polling transaction
	FPGA_IPM_close(GRAIN128AEAD_FPGA_CORE);

}

static GRAIN128AEAD_FPGA_RETURN_CODE GRAIN128AEAD_CHIPHER(  uint8_t *key,
															uint8_t *IV,
															uint8_t *AD, uint8_t ADlen,
															const uint8_t *dataIN, uint64_t datainLen,
															uint8_t *res_hex, FPGA_IPM_OPCODE opcode) {

	int i, i_datain;
	uint8_t i_res = 0;

	uint8_t mac_count = (datainLen/24);

	if( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR){
		(datainLen%24)!=0 ? mac_count++ : mac_count;
	}else{
		mac_count = 0;
	}

	uint8_t key_vhdl[32], *pos_key_vhdl = key_vhdl;
	uint8_t iv_vhdl[24], *pos_iv_vhdl = iv_vhdl;
	uint8_t datain_vhdl[datainLen*2], *pos_datain_vhdl = datain_vhdl;
	uint8_t ad_vhdl[ADlen*2], *pos_ad_vhdl = ad_vhdl;
	uint8_t res_vhdl[(datainLen + mac_count*8)*2];
	uint8_t dataOUT[(datainLen + mac_count*8)*2];



	FPGA_IPM_DATA key_to_fpga[16];
	FPGA_IPM_DATA iv_to_fpga[12];
	FPGA_IPM_DATA datain_to_fpga[datainLen];
	FPGA_IPM_DATA ad_to_fpga[ADlen];


	FPGA_IPM_DATA datainBlock[GRAIN128AEAD_FPGA_WORDS_NEXT_PACK], ADblock[GRAIN128AEAD_FPGA_WORDS_AD_MAX], keyBlock[GRAIN128AEAD_FPGA_WORDS_KEY], ivBlock[GRAIN128AEAD_FPGA_WORDS_IV];
	uint64_t left, resLen;
	uint8_t available_dataLen;
	uint8_t words_init_pack, words_next_pack;
	uint8_t subdatainLen;

	resLen = datainLen/2 + 1 + mac_count*GRAIN128AEAD_FPGA_WORDS_MAC; // the result length will take into account the MAC and an extra word to manage the odd datainLen size
	FPGA_IPM_DATA res[resLen];

	if( (key == NULL) || (IV == NULL) || (AD == NULL) )
		return GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT;
	else if( (ADlen > 2*GRAIN128AEAD_FPGA_WORDS_AD_MAX) || (sizeof(key) > 2*GRAIN128AEAD_FPGA_WORDS_KEY) || (sizeof(IV) > 2*GRAIN128AEAD_FPGA_WORDS_IV) )
		return GRAIN128AEAD_FPGA_RES_INVALID_ARGUMENT;

	// *** Data format - do not modify - BEGIN
	// **************************************************************
	// **************************************************************
	// **************************************************************

	//Swapping data 2 bytes at a time
	for(size_t i=0;i<32; i+=4){
		for(size_t j=0; j<4; j++){
			key_vhdl[31 - (3-j + i)] =  key[i+j];
		}
	}

	for(size_t i=0;i<24; i+=4){
		for(size_t j=0; j<4; j++){
			iv_vhdl[23 - (3-j + i)] =  IV[i+j];
		}
	}

	for(size_t i=0;i<ADlen*2; i+=4){
		for(size_t j=0; j<4; j++){
			ad_vhdl[(ADlen*2)-1 - (3-j + i)] =  AD[i+j];

		}
	}

	//2-to-1 byte
	print_uart("\r\nKEY: ");
	for (size_t i = 0; i < 16 ; i++) {
		key_to_fpga[i] = ( to_hex(pos_key_vhdl[2*i]) & 0x0F ) << 4 | ( to_hex(pos_key_vhdl[2*i+1]) & 0x0F );
		print_uart_8(key_to_fpga[i]);
	}
	print_uart("\r\nIV: ");
	for (size_t i = 0; i < 12 ; i++) {
		iv_to_fpga[i] = ( to_hex(pos_iv_vhdl[2*i]) & 0x0F ) << 4 | ( to_hex(pos_iv_vhdl[2*i+1]) & 0x0F );
		print_uart_8(iv_to_fpga[i]);
	}

	print_uart("\r\nAD: ");
	for (size_t i = 0; i < ADlen ; i++) {
		ad_to_fpga[i] = ( to_hex(pos_ad_vhdl[2*i]) & 0x0F ) << 4 | ( to_hex(pos_ad_vhdl[2*i+1]) & 0x0F );
		print_uart_8(ad_to_fpga[i]);
	}

	if( opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR){
		print_uart("\r\nMSG: ");
	}else{
		print_uart("\r\nCT+MAC: ");
	}

	for (size_t i = 0; i < datainLen ; i++) {
		datain_to_fpga[i] = ( to_hex(dataIN[2*i]) & 0x0F ) << 4 | ( to_hex(dataIN[2*i+1]) & 0x0F );
		print_uart_8(datain_to_fpga[i]);
	}



	// transform KEY in a block of words ready to be written inside the data buffer
	for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_KEY ; i++ ){
		keyBlock[i] = GRAIN128AEAD_FPGA_8_to_16((key_to_fpga[ 2*i ]), (key_to_fpga[ 2*i + 1 ]));
	}
	for(i = 0; i < GRAIN128AEAD_FPGA_WORDS_IV ; i++ ){
		ivBlock[i] = GRAIN128AEAD_FPGA_8_to_16(iv_to_fpga[ 2*i ], iv_to_fpga[ 2*i + 1 ]);
	}

	// transform AD in a block of words ready to be written inside the data buffer
	for(i = 0; i < ADlen/2 ; i++ ) {
		ADblock[i] = GRAIN128AEAD_FPGA_8_to_16(ad_to_fpga[ 2*i ], ad_to_fpga[ 2*i + 1 ] );
	}

	// if the total number of AD bytes is odd, the last bytes will be placed on the upper position of a word
	if(ADlen % 2 == 1) {
		ADblock[i] = GRAIN128AEAD_FPGA_8_to_16(ad_to_fpga[ 2*i ], 0);
		i++;
	}

	// save number of words created inside ADblock
	//subADlen = i;

	// **************************************************************
	// **************************************************************
	// **************************************************************
	// *** Data format - do not modify - END

	if (opcode == GRAIN128AEAD_FPGA_OPCODE_ENCR ) {
		available_dataLen = 2*GRAIN128AEAD_FPGA_AVAILABLE_WORDS_ENCR;
		words_init_pack = GRAIN128AEAD_FPGA_AVAILABLE_WORDS_ENCR;
		words_next_pack = GRAIN128AEAD_FPGA_AVAILABLE_WORDS_ENCR;
	} else {
		available_dataLen = 2*GRAIN128AEAD_FPGA_AVAILABLE_WORDS_DECR;
		words_init_pack = GRAIN128AEAD_FPGA_AVAILABLE_WORDS_DECR;
		words_next_pack = GRAIN128AEAD_FPGA_AVAILABLE_WORDS_DECR;
	}

	if (datainLen == 0) {
		// In there is no msg, send just the data required for the init packet, waiting only for the MAC as result
		//( 1 tells to the function to save further 4 word starting from address when it is supposed to be the message)
		GRAIN128AEAD_FPGA_init_pack(keyBlock, ivBlock, ADblock, ADlen, NULL, datainLen, res, &i_res, opcode);
	} else {

		i_datain = 0;
		left = datainLen;
		// This loop is in charge of create packet as soon as the remain bytes is enough to create complete packet of 58 words as message/ciphertext
		while ( left > available_dataLen ){
			// Create packet init, just at the beginning
			if ( i_datain == 0 ) {
				// INIT PACKET
				// transform dataIN in a block of words ready to be written inside the data buffer
				for(i = 0; i < words_init_pack ; i++ ){
					datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(datain_to_fpga[i_datain], datain_to_fpga[i_datain + 1] );
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = 2*words_init_pack;
				// decrement the remaining datainLen of max msg words size
				left = left - 2*words_init_pack;
				// write INIT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_init_pack(keyBlock, ivBlock, ADblock, ADlen, datainBlock, subdatainLen, res, &i_res, opcode);
			} else {
				// NEXT PACKET
				// transform dataIN in a block of words ready to be written inside the data buffer
				for(i = 0; i < words_next_pack ; i++ ){
					datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(datain_to_fpga[i_datain], datain_to_fpga[i_datain + 1] );
					i_datain += 2;
				}
				// save number of words created
				subdatainLen = 2*words_next_pack;
				// decrement the remaining datainLen of max msg words size
				left = left - 2*words_next_pack;
				// write NEXT PACKET inside data buffer without getting MAC data
				GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, opcode + 1);

			}
		}
		// Packet that does not fit a full init/next packet
		for(i = 0; i < left/2 ; i++ ) {
			datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(datain_to_fpga[i_datain], datain_to_fpga[i_datain + 1] );
			i_datain += 2;
		}

		subdatainLen = left;

		if(left % 2 == 1) {
			datainBlock[i] = GRAIN128AEAD_FPGA_8_to_16(datain_to_fpga[i_datain], 0);
			subdatainLen++;
		}

		if ( left == datainLen )
			GRAIN128AEAD_FPGA_init_pack(keyBlock, ivBlock, ADblock, ADlen, datainBlock, subdatainLen, res, &i_res, opcode);
		else
			GRAIN128AEAD_FPGA_next_pack(datainBlock, subdatainLen, res, &i_res, opcode + 1);

	}

	// *** Data format - do not modify - BEGIN
	// **************************************************************
	// **************************************************************
	// **************************************************************

	for(i=0; i < i_res; i++) {
		dataOUT[2*i] = ( res[i] & 0xFF00 ) >> 8;
		dataOUT[2*i+1] = res[i] & 0x00FF ;
	}

	//Byte to hex
	for (size_t i = 0; i < (datainLen + mac_count*8) ; i++) {
		res_hex[2*i] = (( dataOUT[i] & 0xF0 ) >> 4);
		res_hex[2*i+1] = ( dataOUT[i] & 0x0F );
	}



	// **************************************************************
	// **************************************************************
	// **************************************************************
	// *** Data format - do not modify - END

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
