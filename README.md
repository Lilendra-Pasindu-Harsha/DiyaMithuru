<h1 align="center">💧 DiyaMithuru</h1>

<p align="center">
  Smart Liquid Filling Assistant
</p>

<p align="center">
  Technology with Compassion. For a More Inclusive Tomorrow.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white" alt="ESP32">
  <img src="https://img.shields.io/badge/Arduino-00878F?style=for-the-badge&logo=arduino&logoColor=white" alt="Arduino">
  <img src="https://img.shields.io/badge/MQTT-660066?style=for-the-badge&logo=mqtt&logoColor=white" alt="MQTT">
  <img src="https://img.shields.io/badge/HiveMQ_Cloud-FFC000?style=for-the-badge&logo=hivemq&logoColor=black" alt="HiveMQ Cloud">
</p>

<p align="center">
  <a href="https://drive.google.com/drive/folders/1cJ1TSZ0RsK_wuHSQsSrhiei4Du43ArKO?usp=drive_link">
    📂   Explore Project Photos & Videos
  </a>
</p>

---

## 📌 Overview

An ESP32-based liquid filling assistant designed primarily for visually impaired users, supporting safer and more independent everyday use.

Developed for the Engineering Product Design module at General Sir John Kotelawala Defence University, Sri Lanka.

## ✨ Features

| Automatic Filling | Monitoring & Control |
|---|---|
| Cup detection | Live web status |
| Liquid-level sensing | MQTT communication |
| Automatic low-level refill | Spoken announcements |
| Stop when full or cup removed | ON / STOP / FILL / TEMP commands |
| Pump safety timeout | Contactless temperature monitoring |

## ⚙️ How It Works

```text
Place Cup
    ↓
Limit Switch Detects Cup
    ↓
Ultrasonic Sensor Checks Level
    ↓
ESP32 Starts Pump
    ↓
Full Threshold Reached → Pump Stops
    ↓
Wait 2 Seconds
    ↓
Measure Drink Temperature
    ↓
Publish Status via MQTT
```

## 🧰 Technology Stack

<p>
  <img src="https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white" alt="ESP32">
  <img src="https://img.shields.io/badge/Arduino-00878F?style=for-the-badge&logo=arduino&logoColor=white" alt="Arduino">
  <img src="https://img.shields.io/badge/MQTT-660066?style=for-the-badge&logo=mqtt&logoColor=white" alt="MQTT">
  <img src="https://img.shields.io/badge/HiveMQ_Cloud-FFC000?style=for-the-badge&logo=hivemq&logoColor=black" alt="HiveMQ Cloud">
  <img src="https://img.shields.io/badge/WiFiManager-0078D4?style=for-the-badge&logo=wifi&logoColor=white" alt="WiFiManager">
</p>

## 🔌 Hardware

| Component | Purpose |
|---|---|
| ESP32 | Main controller and Wi-Fi |
| Limit Switch | Cup detection |
| Ultrasonic Sensor | Liquid-level monitoring |
| MLX90614 | IR temperature sensing |
| Pump | Automatic liquid dispensing |

## 🌐 Connectivity

```text
Sensors → ESP32 ↔ HiveMQ Cloud ↔ Web Application
             ↓
         Pump Control
```

- WiFiManager setup
- Remote commands and live status
- Wi-Fi credential reset

## 🛡️ Safety Features

- Stops filling when the cup is removed
- Stops at the full threshold
- Pump timeout protection
- Sensor fault handling
- Manual STOP command

## 👨‍💻 Team

- Pasindu
- Dinuth

Engineering Product Design  
General Sir John Kotelawala Defence University  
Sri Lanka 🇱🇰

---

<p align="center">
  💧 DiyaMithuru · Supporting Independence Through Technology
</p>
