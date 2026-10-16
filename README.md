<div align="center">

# 💧 DiyaMithuru

### Smart Liquid Filling Assistant

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=20&duration=2800&pause=1000&color=06B6D4&center=true&vCenter=true&width=650&lines=Technology+with+Compassion;Accessible+Automatic+Liquid+Filling;ESP32+%2B+Sensors+%2B+MQTT;Supporting+Everyday+Independence" alt="Animated DiyaMithuru highlights">

<p>
  An assistive embedded prototype designed to make liquid filling<br>
  easier and more independent for visually impaired users.
</p>

<img src="https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white" alt="ESP32">
<img src="https://img.shields.io/badge/Arduino-00878F?style=for-the-badge&logo=arduino&logoColor=white" alt="Arduino">
<img src="https://img.shields.io/badge/MQTT-660066?style=for-the-badge&logo=mqtt&logoColor=white" alt="MQTT">
<img src="https://img.shields.io/badge/HiveMQ_Cloud-FFC000?style=for-the-badge&logo=hivemq&logoColor=black" alt="HiveMQ Cloud">
<img src="https://img.shields.io/badge/WiFiManager-0078D4?style=for-the-badge&logo=wifi&logoColor=white" alt="WiFiManager">

<br><br>

<a href="https://drive.google.com/drive/folders/1cJ1TSZ0RsK_wuHSQsSrhiei4Du43ArKO?usp=drive_link">
  <img src="https://img.shields.io/badge/Explore_Project-06B6D4?style=for-the-badge&logo=googledrive&logoColor=white" alt="Explore Project">
</a>

<p>Engineering Product Design · General Sir John Kotelawala Defence University</p>

</div>

---

## 🎯 The Problem

Judging liquid levels can be difficult without visual feedback.

DiyaMithuru combines automatic filling, temperature monitoring, and spoken interface announcements to support everyday independence.

## ⚡ At a Glance

| Area | Implementation |
|---|---|
| Detection | Limit-switch cup detection |
| Filling | Level-based pump control and automatic refill |
| Temperature | MLX90614 contactless sensing |
| Connectivity | ESP32 Wi-Fi and HiveMQ Cloud |
| Interface | Live web status and spoken announcements |
| Protection | Cup-removal stop, timeout, and sensor-fault handling |

## 🏗️ System Architecture

```text
 Limit Switch · Ultrasonic Sensor · MLX90614
                     │
                     ▼
                   ESP32
                     │
           ┌─────────┴─────────┐
           ▼                   ▼
      Pump Control        HiveMQ Cloud
                               │
                               ▼
                         Web Interface
                               │
                    Status · Commands · Speech
```

## ⚙️ Filling Workflow

```text
Place Cup → Detect Cup → Check Liquid Level
                                  │
                                  ▼
                              Start Pump
                                  │
                                  ▼
                       Full Level → Stop Pump
                                  │
                                  ▼
                           Wait 2 Seconds
                                  │
                                  ▼
                       Measure Temperature
                                  │
                                  ▼
                         Publish MQTT Status
```

Removing the cup stops the pump immediately.

## 🛠️ Engineering Highlights

- Integrated cup detection, level sensing, and pump control.
- Added automatic refill when liquid falls below the configured level.
- Connected the device to a web interface through MQTT.
- Implemented spoken status announcements in the interface.
- Added WiFiManager provisioning and credential reset.

## 🎛️ User Controls

| Command | Function |
|---|---|
| `ON` | Enable operation |
| `STOP` | Stop filling |
| `FILL` | Request filling |
| `TEMP` | Request temperature reading |

## 🛡️ Protection Features

`Cup-Removal Stop` · `Full-Level Stop` · `Pump Timeout`  
`Sensor-Fault Handling` · `Manual STOP`

<details>
<summary>🔌 Hardware Components</summary>

<br>

| Component | Role |
|---|---|
| ESP32 | Controller and Wi-Fi connectivity |
| Limit Switch | Cup detection |
| Ultrasonic Sensor | Liquid-level measurement |
| MLX90614 | IR temperature measurement |
| Pump | Liquid dispensing |

</details>

<details>
<summary>🌐 Connectivity & Interface</summary>

<br>

- Wi-Fi setup through WiFiManager
- MQTT messaging through HiveMQ Cloud
- Live device status on the web application
- Remote ON / STOP / FILL / TEMP commands
- Spoken announcements through the interface
- Wi-Fi credential reset

</details>

## 👨‍💻 Team

Pasindu · Dinuth

Engineering Product Design  
General Sir John Kotelawala Defence University  
Sri Lanka 🇱🇰

---

<div align="center">

### Technology with Compassion

Accessible Design · Embedded Control · Connected Assistance

</div>
