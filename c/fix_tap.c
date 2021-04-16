#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int32_t pointer;
uint16_t offset;
uint8_t h_byte, h_byte_store;
uint8_t l_byte, l_byte_store;
off_t size;

FILE *fp;

int main(int argc, char *argv[]) {

	fp = fopen(argv[1], "r+");
	if (fp == NULL) {
		printf("Cannot fopen file to write. Exiting..\n");
		return 1;
	}

	fread(&l_byte, sizeof(l_byte), 1, fp);
	fread(&h_byte, sizeof(h_byte), 1, fp);

	if (l_byte != 0x00 || h_byte != 0x00) {					// at least one of these bytes shld not eq x00
		printf("Has nothing to do, the file looks like already fixed TAP\n");
		return 2;							// the TAP-file has already been fixed
	}

	if (fseeko(fp, 0, SEEK_END) != 0) {
		printf("Cannot fseeko. Exiting..\n");
		return 1;
	}

	size = ftello(fp);							// real size + 2 trailing bytes
	printf("Size: %d\n", size);
	pointer = size - 2;
	offset = 0;
	l_byte = 0xFF;
	h_byte = 0xFF;

	while (pointer >= 0) {
		fseeko(fp, pointer, SEEK_SET);
		fread(&l_byte_store, sizeof(l_byte_store), 1, fp);
		fread(&h_byte_store, sizeof(h_byte_store), 1, fp);

		fseeko(fp, pointer, SEEK_SET);
		fwrite(&l_byte, sizeof(l_byte), 1, fp);
		fwrite(&h_byte, sizeof(h_byte), 1, fp);

		l_byte = l_byte_store;
		h_byte = h_byte_store;

		offset = h_byte;
		offset = (offset << 8) + l_byte;

		pointer = pointer - offset - 2;
		printf("l_byte: h%X\th_byte: h%X\toffset: %d\tpointer: %d\n", l_byte, h_byte, offset, pointer);		// DEBUG
	}

	ftruncate(fileno(fp), size - 2);					// cut 2 trailing bytes off

	fclose(fp);
	return 0;
}
