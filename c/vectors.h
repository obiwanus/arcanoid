#ifndef _VECTORS_H_
#define _VECTORS_H_

#include <math.h>

typedef struct v2 {
  float x;
  float y;
} v2;

v2 V2(float x, float y);
float Length(const v2 a);
v2 Normalize(const v2 a);
v2 Lerp(const v2 a, const v2 b, float t);
v2 Scale(const v2 a, const float value);
v2 OrthoNormalV2(const v2 a);
v2 Add(const v2 a, const v2 b);
v2 Neg(const v2 a);

#endif // _VECTORS_H_
