<p align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/7cc178ce4839c6cf2b142f1802aa08c1a4c3155a/agriyukt%20logo.jpeg" alt="AgriYukt Logo" width="120">
</p>

<h1 align="center">🌱 AgriYukt</h1>

<p align="center">
  <b>Digitizing the Agricultural Supply Chain</b><br>
  <i>From farmer’s field to market — on time, every time.</i>
</p>

<p align="center">
  <b>The Smart Agriculture Marketplace Powered by AI & Trust</b>
</p>

<br>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.agriyukt.app">
    <img src="https://cdn-icons-png.flaticon.com/512/888/888857.png" width="20"> Download on Play Store
  </a>
  &nbsp; • &nbsp;
  
  <a href="https://youtu.be/yFVWkAY0X8E?si=iuzUhN9CJ6WCvwXN">
    <img src="https://cdn-icons-png.flaticon.com/512/1384/1384060.png" width="20"> Watch Demo Video
  </a>
  &nbsp; • &nbsp;
  
  <a href="https://drive.google.com/file/d/1sxEJLTuhajXE7WNf1HzaknexGLmOAOT7/view?usp=drive_link">
    <img src="https://cdn-icons-png.flaticon.com/512/2991/2991148.png" width="20"> Demo (Drive)
  </a>
</p>

## 🚀 Overview

**AgriYukt** is a next-generation, real-time digital platform designed to bridge the gap between farmers and bulk buyers. By eliminating predatory middlemen and leveraging cutting-edge Artificial Intelligence, AgriYukt ensures transparent pricing, verified quality, and seamless agricultural trade.

### 💡 The Problem

In traditional agricultural supply chains, farmers lack direct access to bulk buyers and market intelligence. This information asymmetry forces them to rely on multiple layers of middlemen, resulting in drastically reduced profit margins and massive post-harvest losses.

### 🎯 The AgriYukt Solution

AgriYukt democratizes the agricultural supply chain by providing a direct, verified, and AI-assisted communication and trading platform.

-----

## ✨ Key Features

  - 🤖 **Smart Auto-Fill (AI Crop Appraiser):** Powered by Google's **Gemini 1.5 Flash** Vision model. Farmers simply take a photo of their produce, and the AI automatically detects the crop category, Indian variety, quality grade, and estimates the weight.
  - 🔐 **DigiLocker KYC Integration:** Enterprise-grade trust. Farmers and Inspectors are verified via the official government DigiLocker OAuth 2.0 flow using their Aadhaar/PAN.
  - 📍 **Precision Geo-Tagging:** Integrates reverse-geocoding to fetch highly specific farm locations (Street, Village, Zip Code) to prove the origin of the produce.
  - 📈 **AI Market Intelligence:** Real-time predictive pricing algorithms analyze current Mandi averages and output actionable insights (e.g., "Prices dropping by 2% - sell competitively").
  - 🏢 **Direct Bulk Buyer Access:** A transparent trade system ensuring farmers get the best possible margins.

-----

## 📸 App Interface & Mockups

<p align="center"><b>App Screens Preview</b></p>

<div align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/4defeea1e3fce8e2c67bb2f26778a8234af02733/ai%20scan.jpeg" alt="AI Scan" width="24%">

  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/4defeea1e3fce8e2c67bb2f26778a8234af02733/buyer%20market%20tab.jpeg" alt="Buyer Market Tab" width="24%">

  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/4defeea1e3fce8e2c67bb2f26778a8234af02733/farmer%20crop.jpeg" alt="Farmer Crop Screen" width="24%">

  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/4defeea1e3fce8e2c67bb2f26778a8234af02733/inspector%20farmer%20list.jpeg" alt="Inspector Farmer List" width="24%">
</div>

<br>

<div align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/4defeea1e3fce8e2c67bb2f26778a8234af02733/market%20intelligence.jpeg" alt="Market Intelligence AI Prediction" width="30%">
</div>
<br>

<p align="center"><b>All Screens Overview</b></p>

<div align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/7e1219cf8682cb0ef9529e26b04eaef57886f4d9/all%20mockups.jpeg" alt="All App Screens Mockup" width="80%">
</div>
-----

## 🛠️ Technology Stack

**Frontend Architecture:**

  - Framework: Flutter (Dart)
  - State Management: Provider
  - UI Components: Google Fonts, DropdownButton2, TypeAhead

**Backend & Infrastructure:**

  - Database & Auth: Supabase (PostgreSQL)
  - Storage: Supabase Storage (Crop images & avatars)
  - Authentication: DigiLocker OAuth 2.0 APIs

**AI & Hardware APIs:**

  - Vision & LLM: `google_generative_ai` (Gemini 1.5 Flash)
  - Location Services: `geolocator` & `geocoding`
  - Image Processing: `image_cropper` & `flutter_image_compress`

-----

## 🧪 Pilot Testing & Field Validation
<p align="center"><b>We didn't just build this in a lab—we took it to the farmers.</b></p>

<div align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/e11f5ae581c3238114b72ca3dc0e981a99bb6502/apmc%20vashi.png" alt="APMC Vashi" width="48%">
  
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/e11f5ae581c3238114b72ca3dc0e981a99bb6502/bhiwandi.jpg" alt="Bhiwandi Market" width="48%">
</div>

<br>

<div align="center">
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/e11f5ae581c3238114b72ca3dc0e981a99bb6502/dhanu.jpg" alt="Dhanu Farmer Interaction" width="48%">
  
  <img src="https://raw.githubusercontent.com/Aanchal749/Argiyukt-app/e11f5ae581c3238114b72ca3dc0e981a99bb6502/nashik.jpg" alt="Nashik Mandi Visit" width="48%">
</div>

<br>

<p align="center">
  <i>
  "AgriYukt's AI scanner saved us 10 minutes per listing. The DigiLocker verification immediately made buyers trust our produce."
  <br>— Local Farmer Feedback
  </i>
</p>

## 🎥 Video Demonstration

<p align="center">
  <b>Click the image below to watch the full product demonstration, showcasing the AI crop scanner and live verification flows.</b>
</p>

<p align="center">
  <a href="https://youtu.be/yFVWkAY0X8E?si=iuzUhN9CJ6WCvwXN">
    <img src="https://img.youtube.com/vi/yFVWkAY0X8E/0.jpg" alt="Watch Demo Video" width="70%">
  </a>
</p>
-----

## ⚠️ Intellectual Property & Usage Note

> **Copyright (c) 2026 AgriYukt Team. All Rights Reserved.**
>
> This public repository is provided strictly for evaluation, demonstration, and hackathon judging purposes. To protect our proprietary backend logic, AI instruction sets, and API credentials, some configuration files and backend deployment scripts have been explicitly omitted from this public build via `.gitignore`.
>
> **No permission is granted to copy, distribute, modify, or commercially utilize this source code without explicit written consent from the author.**

-----

## 👩‍💻 Authors

**Aanchal Chauhan**  
*Lead Developer & System Architect*

- 💼 [LinkedIn](https://www.linkedin.com/in/aanchal-c-b34a262b2/)
- 🐙 [GitHub](https://github.com/Aanchal749)
- 📧 Email: aanchalsingh5627448@gmail.com

---

<p align="center">
  <i>Built with ❤️ for Indian Agriculture.</i>
</p>
