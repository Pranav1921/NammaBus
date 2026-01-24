
# 🚌 Namma Bus

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)

**Namma Bus** is a real-time bus tracking and management mobile application built using **Flutter**. It utilizes **Google Cloud** services and **Cloud Firestore** to provide seamless, live updates for commuters.

---

## 🌟 Features

* **Real-time Tracking:** Live bus location updates using Cloud Firestore's real-time capabilities.
* **Live Database:** Instant synchronization of bus schedules, routes, and driver availability.
* **Interactive Maps:** Visual tracking of buses on Google Maps.
* **User Authentication:** Secure login and registration via Firebase Auth.
* **Cross-Platform:** Runs smoothly on both Android and iOS.

---

## 🛠️ Tech Stack

**Frontend (Mobile):**
* **Framework:** [Flutter](https://flutter.dev/)
* **Language:** Dart

**Backend & Database:**
* **BaaS (Backend-as-a-Service):** [Firebase](https://firebase.google.com/)
* **Database:** Cloud Firestore (NoSQL Real-time Database)
* **Authentication:** Firebase Authentication

**Cloud Services:**
* **Platform:** Google Cloud Platform (GCP)
* **Maps:** Google Maps SDK for Mobile

---

## ⚙️ Prerequisites

Before you begin, ensure you have met the following requirements:

* **Flutter SDK:** Installed and configured ([Guide](https://flutter.dev/docs/get-started/install)).
* **Dart SDK:** Included with Flutter.
* **IDE:** VS Code or Android Studio.
* **Firebase Account:** A project set up in the Firebase Console.
* **Google Cloud Console:** API Keys enabled for Maps SDK (if using maps).

---

## 🚀 Installation & Setup

Follow these steps to get the project running on your local machine.

### 1. Clone the Repository
```bash
git clone [https://github.com/](https://github.com/)[YOUR_USERNAME]/namma-bus.git
cd namma-bus
```
### 2. Install Dependencies
```bash
flutter pub get
```
### 3. Firebase Configuration
Important: You must add your own Firebase configuration files for the app to work.

Android:

Go to your Firebase Console > Project Settings.

Download
```bash
google-services.json.
```
Place it in 
```bash
android/app/google-services.json.
```
### 4. Configure Google Cloud (Maps)
Create a .env file (or update your AndroidManifest.xml / AppDelegate.swift) with your Google Maps API Key:

Android (```bash android/app/src/main/AndroidManifest.xml```):
```bash 
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
  ```
  ### 5. Run the App
Connect your physical device or start an emulator/simulator:

```bash
flutter run
```

### 📂 Project Structure
```bash
lib/
├── main.dart           # Entry point of the application
├── screens/            # UI screens (Home, Map, Profile, etc.)
├── services/           # Firebase service logic (Firestore, Auth)
├── models/             # Data models (Bus, User, Route)
├── widgets/            # Reusable UI components
└── utils/              # Constants and helper functions
```
