# Quiz LAB · Daily Rewards & Auto-Generated Coupon Codes

This document contains the master reference of **auto-generated discount coupon codes**, discount tiers, expiration rules, and integration guides for the **Spin & Win Daily Rewards** system.

---

## 🎡 System Overview

1. **Daily Reset**: Every student gets **1 free spin** every calendar day. Quota resets at **12:00 AM IST (midnight)**.
2. **Scratch Card Catch**:
   - When a student wins a discount coupon or free paper, it is presented as a **Scratch Card**.
   - Students drag their mouse or swipe their finger across the scratch surface to reveal the code.
   - Once cleared past 38%, the remaining foil dissolves with a celebration sound and confetti.
3. **7-Day Auto-Disable Rule**:
   - **Active Window**: All coupons are valid for **7 days** counting from the day spun or scratched (whether claimed or unclaimed).
   - **Unscratched**: If a student fails to scratch their card within 7 days, it auto-disables and expires.
   - **Scratched & Expired**: After 7 days, the coupon is marked as **Outdated / Expired**. The code is masked with `••••••••`, copy buttons are disabled, and it can no longer be redeemed.
   - **Active Coupons**: Displayed with a bright green badge and a live countdown timer (*e.g., "Expires in 5d 14h"*).
4. **Redemption & Claim Rules**:
   - **Redemption Venue**: Strictly valid and applicable exclusively on [Genziitian.in/courses](https://genziitian.in/courses).
   - **Minimum Order**: Minimum purchase amount is **₹350**.
   - **Maximum Discount**: Max discount on any percentage coupon (15% or 25% OFF) is capped at **₹100**.
   - **No Payment Required**: Daily spin rewards and scratch cards are 100% free with no payment or subscription needed.
   - **Terms & Conditions**: By continuing, users accept all promotional terms, conditions, and rules (see [Terms Section 07](https://quiz.genziitian.in/terms.html#rewards-promotions)).
5. **30 Days Free Pro Membership (Automatic Claim)**:
   - When the Lucky Wheel lands on **Free Pro**, the student receives a **Claim 30 Days Free Pro** button.
   - Clicking Claim immediately activates **30 days of Quiz LAB Pro** access in the database (`pro_subscriptions` table with `current_period_ends_at = now() + 30 days`) and updates `is_pro: true`.
   - 100% free — no credit card, no recurring charge, and auto-expires after 30 days.
6. **Entry Points**:
   - **Top Navigation Bar**: Prominent `🎁 Spin & Win` button next to the date.
   - **Daily Prompt Modal**: Automatically pops up once per day when students log in if they haven't spun today.
   - **More Tab / Profile**: Dedicated **Daily Rewards · Spin & Win** section on both Web and Mobile app.
   - **Direct URL**: Accessible at `/rewards` and `/spin-rewards`.

---

## 🎟️ Coupons Are Minted On Demand

Coupons are no longer pre-made. When a student wins a coupon, the backend calls the GenZ IITian `POST /api/partner-coupons` API (server-side, `GENZ_API_URL` / `GENZ_API_KEY`). The coupon is locked to the student's email, single use, 7 days, min order ₹350. Nothing needs to be added to the payment gateway.

## 👑 30-Day Free Pro Activation Details

- **Backend Route**: `POST /public/api/student/rewards/claim-pro`
- **Controller**: `App\Http\Controllers\StudentRewardController@claimPro`
- **Database Table**: `pro_subscriptions`
  - `user_id`: Authenticated student ID
  - `provider`: `'reward'`
  - `status`: `'active'`
  - `amount_paise`: `0`
  - `current_period_ends_at`: `now()->addDays(30)`
  - `user.is_pro`: `true`
- **Fallback**: Even if offline, local profile storage sets `user.is_pro = true` for 30 days so the student immediately gets access to all pro features without friction.

---

## 🧪 Testing the Daily Rewards Feature

1. **Top Bar Button**: Click the `🎁 Spin & Win` button in the top navigation bar. It opens `/rewards`.
2. **Wheel Spin**:
   - Click `🎡 SPIN NOW · 1 Free Daily Spin`.
   - Wheel rotates with easing, sound ticks, and lands cleanly on a slice.
   - Confetti bursts upon completion.
3. **Scratch Card**:
   - Drag your mouse or finger across the scratch card.
   - Cleared surface reveals the secret code with a 1-click **Copy Coupon Code** button.
4. **My Rewards Ledger**:
   - Switch to the **🎁 My Rewards** tab.
   - Displays all won prizes, active coupon countdowns, and scratch cards.
5. **Daily Prompt Modal**:
   - On reloading the site as a logged-in user who hasn't spun today, a modal appears prompting you to spin.
