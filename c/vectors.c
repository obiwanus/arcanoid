#include "vectors.h"

v2 V2(float x, float y) {
  v2 result = {x, y};
  return result;
}

float Length(const v2 a) {
  return sqrt(a.x * a.x + a.y * a.y);
}

v2 Normalize(const v2 a) {
  float len = Length(a);
  return V2(a.x / len, a.y / len);
}

v2 Lerp(const v2 a, const v2 b, float t) {
  if (t < 0) t = 0;
  if (t > 1.0f) t = 1.0f;
  return V2(
    a.x + t * (b.x - a.x),
    a.y + t * (b.y - a.y)
  );
}

v2 Scale(const v2 a, const float value) {
  return V2(value * a.x, value * a.y);
}
