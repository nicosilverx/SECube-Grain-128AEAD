#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "grain128aead.c"

int main(){
    unsigned char       key[16] = {0}; //16*8=128
    unsigned char		nonce[12] = {0}; //12*8=96
    unsigned char       msg[MSG_SIZE*MSG_PACKETS] = {0};
    unsigned char		ad[AD_SIZE] = {0};
    unsigned char		ct[(MSG_SIZE + 8)*MSG_PACKETS] = {0};
    unsigned char       msg_decrypted[MSG_SIZE*MSG_PACKETS] = {0};

    const char *key_string = "0123456789abcdef123456789abcdef0", *pos_key = key_string;
    const char *nonce_string = "0123456789abcdef12345678", *pos_nonce = nonce_string;
    const char *msg_string = "6369616f6e6521210123", *pos_msg = msg_string;
    const char *ad_string = "11112222", *pos_ad = ad_string;

                             
    //Key
    for(i=0; i<sizeof(key)/sizeof(*key); i++){
        sscanf(pos_key, "%2hhx", &key[i]);
        pos_key += 2;
    }
    //Nonce
    for(i=0; i<sizeof(nonce)/sizeof(*nonce); i++){
        sscanf(pos_nonce, "%2hhx", &nonce[i]);
        pos_nonce += 2;
    }
    //Msg
    for(i=0; i<MSG_SIZE*MSG_PACKETS; i++){
        sscanf(pos_msg, "%2hhx", &msg[i]);
        pos_msg += 2;
    }
    //Ad
    for(i=0; i<AD_SIZE; i++){
        sscanf(pos_ad, "%2hhx", &ad[i]);
        pos_ad += 2;
    }

    //Debug print
    printf("Encryption\n");
    printf("Key: 0x");
    for(size_t count = 0; count < sizeof key/sizeof *key; count++)
        printf("%02x", key[count]);
    printf("\n");

    printf("Nonce: 0x");
    for(size_t count = 0; count < sizeof nonce/sizeof *nonce; count++)
        printf("%02x", nonce[count]);
    printf("\n");

    printf("Msg: 0x");
    for(size_t count = 0; count < sizeof msg/sizeof *msg; count++)
        printf("%02x", msg[count]);
    printf("\n");

    printf("Ad: 0x");
    for(size_t count = 0; count < sizeof ad/sizeof *ad; count++)
        printf("%02x", ad[count]);
    printf("\n");

    encrypt_message(key, nonce, msg, ad, ct);

    //Ciphertext
   /* printf("Ciphertext: 0x");
    for(size_t count = 0; count < (MSG_SIZE+8); count++)
        printf("%02x", ct[count]);
    printf("\n");
*/
    //decrypt_message(key, nonce, ct, ad, msg_decrypted);

    //Decrypt
    /*printf("\nMessage Decrypted: 0x");
    for(size_t count = 0; count < (MSG_SIZE); count++)
        printf("%02x", msg_decrypted[count]);
    printf("\n"); */

}