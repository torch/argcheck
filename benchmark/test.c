#include <TH.h>
#include <stdio.h>
#include <time.h>

int main(int argc, char *argv[])
{
  THDoubleTensor *x = THDoubleTensor_new();
  THDoubleTensor *y = THDoubleTensor_new();
  THGenerator *_gen = THGenerator_new();

  if(argc != 3 && argc != 4) {
    printf("usage: SZ N [SCALE]!\n");
    exit(-1);
  }
  long SZ = atoi(argv[1]);
  long N  = atoi(argv[2]);
  double scale  = ((argc == 4) ? atof(argv[3]) : 1.0);
  printf("SZ=%ld\n", SZ);
  printf("N =%ld\n", N);
  printf("scale =%lf\n", scale);

  THLongStorage *size = THLongStorage_newWithSize2(SZ, SZ);

  THRandom_manualSeed(_gen, 1111);

  THDoubleTensor_rand(x, _gen, size);
  THDoubleTensor_rand(y, _gen, size);

  printf("x\t%lf\n", THDoubleTensor_normall(x, 2));
  printf("y\t%lf\n", THDoubleTensor_normall(x, 2));
  clock_t clk = clock();
  if(scale == 1.0) {
    long i;
    for(i = 1; i < N; i++) {
      THDoubleTensor_add(y, x, 5);
      THDoubleTensor_cadd(y, x, 1, y);
    }
  } else {
    long i;
    for(i = 1; i < N; i++) {
      THDoubleTensor_add(y, x, 5);
      THDoubleTensor_cadd(y, x, scale, y);
    }
  }
  printf("time (s) %lf\n", ((double)(clock()-clk))/((double)CLOCKS_PER_SEC));
  printf("x\t%lf\n", THDoubleTensor_normall(x, 2));
  printf("y\t%lf\n", THDoubleTensor_normall(y, 2));

  THLongStorage_free(size);
  THDoubleTensor_free(x);
  THDoubleTensor_free(y);
  return 0;
}
