#ifndef GRAIN128AEAD_H
#define GRAIN128AEAD_H


#define MSG_PACKETS 1
#define MSG_SIZE 10
#define AD_SIZE 4



#define KEY_SIZE 16
#define IV_SIZE 12
#define PACKET_MSG_SIZE 24


enum GRAIN_ROUND {INIT, ADDKEY, NORMAL};

typedef struct {
	unsigned char lfsr[128];
	unsigned char nfsr[128];
	unsigned char auth_acc[64];
	unsigned char auth_sr[64];
} grain_state;

typedef struct {
	unsigned char *message;
	unsigned long long msg_len;
} grain_data;

void init_grain(grain_state *grain, const unsigned char *key, const unsigned char *iv);
int my_grain_init(const unsigned char *key_in, const unsigned char *iv_in);
unsigned char next_lfsr_fb();									
unsigned char next_nfsr_fb();
unsigned char next_h();
unsigned char shift(unsigned char *fsr, unsigned char fb);
void auth_shift(unsigned char fb);
void accumulate();
unsigned char next_z(unsigned char keybit);


void encrypt_message(unsigned char *key, unsigned char *iv, 
    unsigned char *message, unsigned char *associated_data,
    unsigned char *ciphertext);

int decrypt_message(unsigned char *key, unsigned char *iv, 
    unsigned char *ciphertext, unsigned char *associated_data,
    unsigned char *message);

#endif
