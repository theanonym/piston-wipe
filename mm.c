#include <stdio.h>
#include <string.h>

int main(int argc, char** argv) {
   if(argc < 2)
      return -1;
   const char* str = argv[1];

   unsigned int l = strlen(str), h = 2 ^ l, i = 0, k;
   while(l >= 4) {
      k = str[i] | str[i+1] << 8 | str[i+2] << 16 | str[i+3] << 24;
      k = (k & 0xffff) * 1540483477 + (((k >> 16) * 1540483477 & 0xffff) << 16);
      k ^= k >> 24;
      k = (k & 0xffff) * 1540483477 + (((k >> 16) * 1540483477 & 0xffff) << 16);
      h = (h & 0xffff) * 1540483477 + (((h >> 16) * 1540483477 & 0xffff) << 16) ^ k;
      l -= 4;
      i += 4;
   }

   switch(l) {
      case 3:
         h ^= (str[i + 2] & 0xff) << 16;
      case 2:
         h ^= (str[i + 1] & 0xff) << 8;
      case 1:
         h ^= str[i] & 0xff;
         h = (h & 0xffff) * 1540483477 + (((h >> 16) * 1540483477 & 0xffff) << 16);
   }
   h ^= h >> 13;
   h = (h & 0xffff) * 1540483477 + (((h >> 16) * 1540483477 & 0xffff) << 16);
   h ^= h >> 15;

   printf("%u", h >> 0);
   return 0;
}
