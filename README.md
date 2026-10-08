# 💧 DiyaMithuru – Smart Liquid Filling Assistant

> **Technology with Compassion. For a More Inclusive Tomorrow.**

DiyaMithuru is an **ESP32-based smart liquid filling assistant** developed as part of the **Engineering Product Design module at General Sir John Kotelawala Defence University , Sri Lanka**.

The system is designed primarily for **visually impaired users**, with the goal of making everyday liquid filling safer, easier, and more independent.

Developed by:

- **Pasindu**
- **Dinuth**

---
Do you want watch all click  https://drive.google.com/drive/folders/1cJ1TSZ0RsK_wuHSQsSrhiei4Du43ArKO?usp=drive_link 

## 🌟 Project Overview

For many people, filling a cup is a simple daily activity. However, visually impaired users, elderly users, and people who require daily assistance may face challenges such as:

- Difficulty identifying the liquid level
- Accidental spills
- Unnecessary water wastage
- Safety concerns when handling higher-temperature liquids
- Dependence on another person

DiyaMithuru addresses these challenges through an embedded automatic filling system with liquid-level monitoring, temperature sensing, remote status monitoring, and user control.

---

## ✨ Key Features

- Automatic cup detection
- Automatic liquid filling
- Automatic refill when the liquid level becomes low
- Pump stops when the cup reaches the full threshold
- Pump stops immediately when the cup is removed
- Liquid-level monitoring using an ultrasonic sensor
- Temperature monitoring using the **MLX90614 IR temperature sensor**
- Manual **ON / STOP / FILL / TEMP** commands
- Wi-Fi setup using **WiFiManager**
- MQTT communication using **HiveMQ Cloud**
- Live device status on the web application
- Spoken announcements through the user interface
- Pump safety timeout
- Sensor fault handling
- Wi-Fi credential reset function

---

## ⚙️ How the System Works

```text
Place Cup
   ↓
Limit Switch Detects Cup
   ↓
Ultrasonic Sensor Measures Liquid Level
   ↓
ESP32 Processes Sensor Data
   ↓
Pump Starts
   ↓
Cup Fills
   ↓
Full Threshold Reached
   ↓
Pump Stops
   ↓
Wait 2 Seconds
   ↓
MLX90614 Measures Drink Temperature
   ↓
Status Published Through MQTT


