int data = 0;

void setup() {
  Serial.begin(115200);
}

void loop() {
  uint16_t value = analogRead(A0);
  if (data == 0 && Serial.available() > 0) {
    data = Serial.read();
    if (data == 1) {
      Serial.write((uint8_t*)&value, sizeof(value));
      data = 0;
    }
  }
}