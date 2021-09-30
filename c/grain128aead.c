#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "grain128aead.h"

/*   Examples:
            - Fragmented IP Packet Max Size=1508B => Header=20 B, Payload=1488 B
            - Custom Packet => Header=2 B, Payload=8 B

        Modify the following constants as follows:
            - MSG_SIZE = sizeof(payload)
            - AD_SIZE  = sizeof(header)

*/

#define MSG_PACKETS 1
#define MSG_SIZE 1
#define AD_SIZE 2


#define KEY_SIZE 16
#define IV_SIZE 12

//Grain128 struct
grain_state grain;
unsigned char grain_round;


//Global iterators
unsigned long long i_swapsb = 0, i_shift = 0, i_next_z = 0;
unsigned long long i_init = 0, j_init = 0, i_acc = 0, i_auth = 0;
unsigned long long i = 0, j = 0, k = 0, l = 0;

//swapsb: swaps significant bit
unsigned char swapsb(unsigned char n){
	unsigned char val = 0;
	for (i_swapsb = 0; i_swapsb < 8; i_swapsb++) {
		val |= ((n >> i_swapsb) & 1) << (7-i_swapsb);
	}
	return val;
}

//shift: given an array and a value, it performs the SR
unsigned char shift(unsigned char fsr[128], unsigned char fb){
	unsigned char out = fsr[0];
	for (i_shift = 0; i_shift < 127; i_shift++) {
		fsr[i_shift] = fsr[i_shift+1];
	}
	fsr[127] = fb;

	return out;
}

//next_lfsr_fb: computes the next LFSR value to be shifted in
unsigned char next_lfsr_fb(){
 	/* f(x) = 1 + x^32 + x^47 + x^58 + x^90 + x^121 + x^128 */
	return grain.lfsr[96] ^ grain.lfsr[81] ^ grain.lfsr[70] ^ grain.lfsr[38] ^ grain.lfsr[7] ^ grain.lfsr[0];
}

//next_nfsr_fb: computes the next NFSR value to be shifted in
unsigned char next_nfsr_fb(){
	return grain.nfsr[96] ^ grain.nfsr[91] ^ grain.nfsr[56] ^ grain.nfsr[26] ^ grain.nfsr[0] ^ (grain.nfsr[84] & grain.nfsr[68]) ^
			(grain.nfsr[67] & grain.nfsr[3]) ^ (grain.nfsr[65] & grain.nfsr[61]) ^ (grain.nfsr[59] & grain.nfsr[27]) ^
			(grain.nfsr[48] & grain.nfsr[40]) ^ (grain.nfsr[18] & grain.nfsr[17]) ^ (grain.nfsr[13] & grain.nfsr[11]) ^
			(grain.nfsr[82] & grain.nfsr[78] & grain.nfsr[70]) ^ (grain.nfsr[25] & grain.nfsr[24] & grain.nfsr[22]) ^
			(grain.nfsr[95] & grain.nfsr[93] & grain.nfsr[92] & grain.nfsr[88]);
}

//next_z: given a keybit, computes the keystream
unsigned char next_z(unsigned char keybit){
	unsigned char lfsr_fb = next_lfsr_fb();
	unsigned char nfsr_fb = next_nfsr_fb();
	unsigned char h_out = next_h();

	/* y = h + s_{i+93} + sum(b_{i+j}), j \in A */
	unsigned char A[] = {2, 15, 36, 45, 64, 73, 89};

	unsigned char nfsr_tmp = 0;
	for (i_next_z = 0; i_next_z < 7; i_next_z++) {
		nfsr_tmp ^= grain.nfsr[A[i_next_z]];
	}

	unsigned char y = h_out ^ grain.lfsr[93] ^ nfsr_tmp;
	
	unsigned char lfsr_out;

	/* feedback y if we are in the initialization instance */
	if (grain_round == INIT) {
		lfsr_out = shift(grain.lfsr, lfsr_fb ^ y);
		shift(grain.nfsr, nfsr_fb ^ lfsr_out ^ y);
	} else if (grain_round == ADDKEY) {
		lfsr_out = shift(grain.lfsr, lfsr_fb ^ keybit);
		shift(grain.nfsr, nfsr_fb ^ lfsr_out);
	} else if (grain_round == NORMAL) {
		lfsr_out = shift(grain.lfsr, lfsr_fb);
		shift(grain.nfsr, nfsr_fb ^ lfsr_out);
	}
	return y;
}

//next_h: computes the value of h()
unsigned char next_h(){
	// h(x) = x0x1 + x2x3 + x4x5 + x6x7 + x0x4x8
	#define x0 grain.nfsr[12]	// bi+12
	#define x1 grain.lfsr[8]	// si+8
	#define x2 grain.lfsr[13]	// si+13
	#define x3 grain.lfsr[20]	// si+20
	#define x4 grain.nfsr[95]	// bi+95
	#define x5 grain.lfsr[42]	// si+42
	#define x6 grain.lfsr[60]	// si+60
	#define x7 grain.lfsr[79]	// si+79
	#define x8 grain.lfsr[94]	// si+94

	unsigned char h_out = (x0 & x1) ^ (x2 & x3) ^ (x4 & x5) ^ (x6 & x7) ^ (x0 & x4 & x8);
	return h_out;
}

//accumulate: let the accumulator run
void accumulate(){
	for (i_acc = 0; i_acc < 64; i_acc++) {
		grain.auth_acc[i_acc] ^= grain.auth_sr[i_acc];
	}
}

//auth_shift: given a value, shift the Authentication SR
void auth_shift(unsigned char fb){
	for (i_auth = 0; i_auth < 63; i_auth++) {
		grain.auth_sr[i_auth] = grain.auth_sr[i_auth+1];
	}
	grain.auth_sr[63] = fb;
}

//grain_init: load the (key,iv) and initializes the cipher. 
//Warning: (key,iv) should be swapped by the client (i.e. encrypt/decrypt())
int my_grain_init(const unsigned char key_in[16], const unsigned char iv_in[12]){
	char tmp_nz = 0;

    //Assign IV to LFSR
	for (i_init = 0; i_init < IV_SIZE; i_init++) {
		for (j_init = 0; j_init < 8; j_init++) {
			grain.lfsr[8 * i_init + j_init] = (iv_in[i_init] & (1 << (7-j_init))) >> (7-j_init);
		}
	}

	//Last 31 bits at 1
	for (i_init = 96; i_init < 127; i_init++) {
		grain.lfsr[i_init] = 1;
	}
	//Last bit at 0
	grain.lfsr[127] = 0;

	//Assign Key to NFSR
	for (i_init = 0; i_init < 16; i_init++) {
		for (j_init = 0; j_init < 8; j_init++) {
			grain.nfsr[8 * i_init + j_init] = (key_in[i_init] & (1 << (7-j_init))) >> (7-j_init);
		}
	}

    //Clear Accumulator and Shift Register
	for (i_init = 0; i_init < 64; i_init++) {
		grain.auth_acc[i_init] = 0;
		grain.auth_sr[i_init] = 0;
    }

	printf("----- INIT -----\n");

	printf("\nStarting LFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.lfsr[k]);
	}
	printf("\n");

	printf("\nStarting NFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.nfsr[k]);
	}
	printf("\n\n");

    //Let the pre-output generator run for 256 c.c.
    grain_round = INIT;
	for (i_init = 0; i_init < 256; i_init++) {
		tmp_nz = next_z(0);
	}

	printf("\nAfter 256cc LFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.lfsr[k]);
	}
	printf("\n");

	printf("\nAfter 256cc NFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.nfsr[k]);
	}
	printf("\n\n");


    // inititalize the accumulator and shift reg. using the first 64 bits of the key
    grain_round = ADDKEY;
	unsigned char key_idx = 0;
	for (i_init = 0; i_init < 8; i_init++) {
		for (j_init = 0; j_init < 8; j_init++) {
			unsigned char addkey_fb = (key_in[key_idx] & (1 << (7-j_init))) >> (7-j_init);
			grain.auth_acc[8 * i_init + j_init] = next_z(addkey_fb);
			tmp_nz = grain.auth_acc[8 * i_init + j_init];
		}
		key_idx++;
	}
	for (i_init = 0; i_init < 8; i_init++) {
		for (j_init = 0; j_init < 8; j_init++) {
			unsigned char addkey_fb = (key_in[key_idx] & (1 << (7-j_init))) >> (7-j_init);
			grain.auth_sr[8 * i_init + j_init] = next_z(addkey_fb);
			tmp_nz = grain.auth_sr[8 * i_init + j_init];
		}
		key_idx++;
	}

    //End of the initialization
    grain_round = NORMAL;

	printf("\nAfter init LFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.lfsr[k]);
	}
	printf("\n");

	printf("\nAfter init NFSR: ");
	for(k=0; k<128; k++){
		printf("%d", grain.nfsr[k]);
	}
	printf("\n");

	//SR 
	printf("\nAfter Init SR: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_sr[k]);
	}
	printf("\n");

	printf("\nAfter Init acc: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_acc[k]);
	}
	printf("\n\n");

}

void encrypt_message(unsigned char key[16], unsigned char iv[12], 
    unsigned char message[MSG_SIZE], unsigned char associated_data[AD_SIZE],
    unsigned char ciphertext[MSG_SIZE+8]){

	//Swapped arrays
    unsigned char key_swb[16] = {0};
    unsigned char iv_swb[12] = {0};
    unsigned char msg_swb[MSG_SIZE] = {0};
    unsigned char ad_swb[AD_SIZE] = {0};

    unsigned char message_bit[(8*MSG_SIZE) + 1] = {0};
    unsigned long long message_bit_len = (8*MSG_SIZE) + 1 ;

    unsigned char final_associated_data[AD_SIZE + 1] = {0};

    //Swap the bytes
    for (i = 0; i < 16; i++) {
		key_swb[i] = swapsb(key[i]);	
	}
	for (i = 0; i < 12; i++) {
		iv_swb[i] = swapsb(iv[i]);
	}
	for (i = 0; i < AD_SIZE; i++) {
		ad_swb[i] = swapsb(associated_data[i]);
	}

    //Initialize the cipher
    my_grain_init(key_swb, iv_swb);

    //Encoding of AD_SIZE (if <128 always 1 byte)
    unsigned char associated_data_length_encoded = swapsb((unsigned char)AD_SIZE); 

    //enc(AD_SIZE) || AD
    final_associated_data[0] = associated_data_length_encoded;
	for(k = 1; k<AD_SIZE+1; k++){
		final_associated_data[k] = ad_swb[k-1];	
	}

    //accumulate tag for associated data only 
	printf("----- ACCUMULATING TAG FOR AD ONLY-----\n");
    unsigned long long ad_cnt = 0;
	unsigned char adval = 0;
	unsigned int counter = 0, acc_counter = 0;
    for ( k = 0; k < (1 + AD_SIZE); k++) {
		/* every second bit(odd) is used for keystream, the others(even) for MAC */
		for ( j = 0; j < 16; j++) {
			unsigned char z_next = next_z(0);
			if (j % 2 == 0) {
				// do not accumulate
			} else {
				adval = final_associated_data[ad_cnt / 8] & (1 << (7 - (ad_cnt % 8)));
				if (adval) {
					accumulate();
					acc_counter++;
				}
				auth_shift(z_next);
				ad_cnt++;
			}
		}
	}

	//SR after ammulation of the tag
	printf("\nAfter Accumulation for AD only SR: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_sr[k]);
	}
	printf("\n");

	printf("\nAfter Accumulation for AD only ACC: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_acc[k]);
	}
	printf("\n\n");


	for(int packets = 0; packets < MSG_PACKETS; packets++){
		
		memset(msg_swb, 0, sizeof(msg_swb));
		memset(message_bit, 0, sizeof(message_bit));
		memset(ciphertext, 0, MSG_SIZE+8);

		for (i = 0; i < MSG_SIZE; i++) {
			msg_swb[i] = swapsb(message[i + MSG_SIZE*packets]);
			printf("%02x ", msg_swb[i]);
		}
		

		//Byte => bits
		for ( k = 0; k < MSG_SIZE; k++) {
			for ( l = 0; l < 8; l++) {
				message_bit[8 * k + l ] = (msg_swb[k] & (1 << (7-l))) >> (7-l);
			}
		}
		//Last bit should be 1
		message_bit[message_bit_len-1] = 1;

		//Encrypt the message
		printf("----- ENCRYPTION -----\n");
		unsigned long long ac_cnt = 0;
		unsigned long long m_cnt = 0;
		unsigned long long c_cnt = 0;
		unsigned char cc = 0;

		for (k = 0; k < MSG_SIZE; k++) {
			// every second bit is used for keystream, the others for MAC
			cc = 0;
			for (j = 0; j < 16; j++) {
				unsigned char z_next = next_z(0);
				if (j % 2 == 0) {
					//generate_keystream
					// transform it back to 8 bits per byte
					cc |= (message_bit[m_cnt] ^ z_next) << (7 - (c_cnt % 8));
					printf("msg_bit[%d]: %d\n", m_cnt, message_bit[m_cnt]);
					m_cnt++;
					c_cnt++;
				} else {
					if (message_bit[ac_cnt] == 1) {
						accumulate();
					}
					ac_cnt ++;
					auth_shift(z_next);
				}
			}
			printf("\n");
			ciphertext[k] = swapsb(cc);
			
		}

		//SR 
		printf("\n\nAfter encryption SR: ");
		for(int yy=0; yy<64; yy++){
			printf("%d", grain.auth_sr[yy]);
		}
		printf("\n");

		printf("\nAfter encryption acc: ");
		for(int yy=0; yy<64; yy++){
			printf("%d", grain.auth_acc[yy]);
		}
		printf("\n\n");

		// generate unused keystream bit
		next_z(0);
		// the 1 in the padding means accumulation
		accumulate();

		//SR 
		printf("\n\nAfter padding accumulation SR: ");
		for(int yy=0; yy<64; yy++){
			printf("%d", grain.auth_sr[yy]);
		}
		printf("\n");

		printf("\nAfter padding accumulation ACC: ");
		for(int yy=0; yy<64; yy++){
			printf("%d", grain.auth_acc[yy]);
		}
		printf("\n\n");

		// append MAC to ciphertext 
		unsigned long long acc_idx = 0;

		printf("MAC: ");
		for (i = MSG_SIZE; i < MSG_SIZE + 8; i++) {
			unsigned char acc = 0;
			// transform back to 8 bits per byte
			for (j = 0; j < 8; j++) {
				acc |= grain.auth_acc[8 * acc_idx + j] << (7 - j);
			}
			ciphertext[i] = swapsb(acc);
			printf("%02x", ciphertext[i]);
			acc_idx++;
		}
		printf("\n");

		printf("Ciphertext: 0x");
		for(size_t count = 0; count < (MSG_SIZE+8); count++)
			printf("%02x ", ciphertext[count]);
		printf("\n");

		
	}

}

int decrypt_message(unsigned char key[16], unsigned char iv[12], 
    unsigned char ciphertext[MSG_SIZE+8], unsigned char associated_data[AD_SIZE],
    unsigned char message[MSG_SIZE]){
	
	//Swapped arrays
	unsigned char key_swb[16] = {0};
    unsigned char iv_swb[12] = {0};
    unsigned char ct_swb[MSG_SIZE+8] = {0};
    unsigned char ad_swb[AD_SIZE] = {0};

    unsigned char ciphertext_bit[(8*(MSG_SIZE+8)) + 1] = {0};
    unsigned long long ciphertext_bit_len = (8*(MSG_SIZE+8)) + 1 ;

    unsigned char final_associated_data[AD_SIZE + 1] = {0};

    //Swap the bytes
    for (i = 0; i < 16; i++) {
		key_swb[i] = swapsb(key[i]);	
	}
	for (i = 0; i < 12; i++) {
		iv_swb[i] = swapsb(iv[i]);
	}
    for (i = 0; i < MSG_SIZE+8; i++) {
		ct_swb[i] = swapsb(ciphertext[i]);	
	}
	for (i = 0; i < AD_SIZE; i++) {
		ad_swb[i] = swapsb(associated_data[i]);
	}

    //Initialize the cipher
    my_grain_init(key_swb, iv_swb);

    //Byte => bits
    for ( k = 0; k < (MSG_SIZE+8); k++) {
		for ( l = 0; l < 8; l++) {
			ciphertext_bit[8 * k + l] = (ct_swb[k] & (1 << (7-l))) >> (7-l);
		}
	}
	ciphertext_bit[ciphertext_bit_len - 1] = 1;

	//Encoding of AD_SIZE (if <128 always 1 byte)
    unsigned char associated_data_length_encoded = swapsb((unsigned char)AD_SIZE);

    //enc(AD_SIZE) || AD
    final_associated_data[0] = associated_data_length_encoded;
	for(k = 1; k<AD_SIZE+1; k++){
		final_associated_data[k] = ad_swb[k-1];	
	}

	unsigned long long ad_cnt = 0;
	unsigned char adval = 0;

	printf("----- ACCUMULATING TAG FOR AD ONLY-----\n");
	/* accumulate tag for associated data only */
	for ( k = 0; k < (AD_SIZE + 1); k++) {
		/* every second bit is used for keystream, the others for MAC */
		for (j = 0; j < 16; j++) {
			unsigned char z_next = next_z(0);
			if (j % 2 == 0) {
				// do not encrypt
			} else {
				adval = final_associated_data[ad_cnt / 8] & (1 << (7 - (ad_cnt % 8)));
				if (adval) {
					accumulate();
				}
				auth_shift(z_next);
				ad_cnt++;
			}
		}
	}

	//SR after ammulation of the tag
	printf("\nAfter Accumulation for AD only SR: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_sr[k]);
	}
	printf("\n");

	printf("\nAfter Accumulation for AD only ACC: ");
	for(k=0; k<64; k++){
		printf("%d", grain.auth_acc[k]);
	}
	printf("\n\n");

	//Decrypt the message
	printf("----- DECRYPTION -----\n");
	unsigned long long ac_cnt = 0;
	unsigned long long c_cnt = 0;
	unsigned char msgbyte = 0;
	unsigned char msgbit = 0;

	// generate keystream for message, skipping tag
	for ( k = 0; k < MSG_SIZE; k++) {
		// every second bit is used for keystream, the others for MAC
		msgbyte = 0;
		for (j = 0; j < 8; j++) {
			unsigned char z_next = next_z(0);
			// decrypt ciphertext
			msgbit = ciphertext_bit[c_cnt] ^ z_next;
			// transform it back to 8 bits per byte
			msgbyte |= msgbit << (7 - (c_cnt % 8));

			// generate accumulator bit
			z_next = next_z(0);
			// use the decrypted message bit to control accumulator
			if (msgbit == 1) {
				accumulate();
			}
			auth_shift(z_next);

			c_cnt++;
			ac_cnt++;
		}
		message[k] = swapsb(msgbyte);
	}

	//SR 
	printf("\n\nAfter decryption SR: ");
	for(int yy=0; yy<64; yy++){
		printf("%d", grain.auth_sr[yy]);
	}
	printf("\n");

	printf("\nAfter decryption acc: ");
	for(int yy=0; yy<64; yy++){
		printf("%d", grain.auth_acc[yy]);
	}
	printf("\n\n");

	// generate unused keystream bit
	next_z(0);
	// the 1 in the padding means accumulation
	accumulate();

	//SR 
	printf("\n\nAfter padding accumulation SR: ");
	for(int yy=0; yy<64; yy++){
		printf("%d", grain.auth_sr[yy]);
	}
	printf("\n");

	printf("\nAfter padding accumulation ACC: ");
	for(int yy=0; yy<64; yy++){
		printf("%d", grain.auth_acc[yy]);
	}
	printf("\n\n");

	printf("----- AUTHENTICATION -----\n");
	// check MAC
	for(k=0; k<64; k++){
		if(grain.auth_acc[k] != ciphertext_bit[8*(MSG_SIZE) + k]){
			printf("NOT AUTHENTICATED!\n");
			memset(message, 0, MSG_SIZE);
			return -1;
		}
	}
	return 0;
}
