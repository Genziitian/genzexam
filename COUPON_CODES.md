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

## 🎟️ Master List of Auto-Generated Coupon Codes

Add these pre-generated codes into your website payment gateway (Razorpay Offers, store backend, or discount coupon table) so students who spin them can redeem them at checkout.

### Tier 1: 5% OFF Starter Coupons (`GENZ5-XXXX`)
- **Discount**: 5% discount on all course packages and bundles
- **Validity**: 7 days from reveal
- **Probability**: 20% on the Lucky Wheel

| # | Coupon Code | Discount | Applicable To | Limit |
|---|-------------|----------|---------------|-------|
| 1 | `GENZ5-2K8P` | 5% OFF | All Courses & Test Series | 1 per user |
| 2 | `GENZ5-3M7Q` | 5% OFF | All Courses & Test Series | 1 per user |
| 3 | `GENZ5-4W9X` | 5% OFF | All Courses & Test Series | 1 per user |
| 4 | `GENZ5-5TRC` | 5% OFF | All Courses & Test Series | 1 per user |
| 5 | `GENZ5-6PLD` | 5% OFF | All Courses & Test Series | 1 per user |
| 6 | `GENZ5-7NBF` | 5% OFF | All Courses & Test Series | 1 per user |
| 7 | `GENZ5-8XKS` | 5% OFF | All Courses & Test Series | 1 per user |
| 8 | `GENZ5-9HMC` | 5% OFF | All Courses & Test Series | 1 per user |
| 9 | `GENZ5-AB7E` | 5% OFF | All Courses & Test Series | 1 per user |
| 10 | `GENZ5-B9KD` | 5% OFF | All Courses & Test Series | 1 per user |
| 11 | `GENZ5-C4QF` | 5% OFF | All Courses & Test Series | 1 per user |
| 12 | `GENZ5-D8WR` | 5% OFF | All Courses & Test Series | 1 per user |
| 13 | `GENZ5-E2NY` | 5% OFF | All Courses & Test Series | 1 per user |
| 14 | `GENZ5-F7PK` | 5% OFF | All Courses & Test Series | 1 per user |
| 15 | `GENZ5-G5TC` | 5% OFF | All Courses & Test Series | 1 per user |
| 16 | `GENZ5-H9XB` | 5% OFF | All Courses & Test Series | 1 per user |
| 17 | `GENZ5-J3MD` | 5% OFF | All Courses & Test Series | 1 per user |
| 18 | `GENZ5-K8SF` | 5% OFF | All Courses & Test Series | 1 per user |
| 19 | `GENZ5-L4NR` | 5% OFF | All Courses & Test Series | 1 per user |
| 20 | `GENZ5-M7TW` | 5% OFF | All Courses & Test Series | 1 per user |
| 21 | `GENZ5-N2BC` | 5% OFF | All Courses & Test Series | 1 per user |
| 22 | `GENZ5-P6QK` | 5% OFF | All Courses & Test Series | 1 per user |
| 23 | `GENZ5-Q9HD` | 5% OFF | All Courses & Test Series | 1 per user |
| 24 | `GENZ5-R3VF` | 5% OFF | All Courses & Test Series | 1 per user |
| 25 | `GENZ5-S8KP` | 5% OFF | All Courses & Test Series | 1 per user |
| 26 | `GENZ5-T5MC` | 5% OFF | All Courses & Test Series | 1 per user |
| 27 | `GENZ5-U2XB` | 5% OFF | All Courses & Test Series | 1 per user |
| 28 | `GENZ5-V7NR` | 5% OFF | All Courses & Test Series | 1 per user |
| 29 | `GENZ5-W4QD` | 5% OFF | All Courses & Test Series | 1 per user |
| 30 | `GENZ5-X9TF` | 5% OFF | All Courses & Test Series | 1 per user |

---

### Tier 2: 25% OFF Mega Discount (`GENZ25-XXXX`)
- **Discount**: 25% discount on Quiz LAB subscriptions & full course packages
- **Validity**: 7 days from reveal

| # | Coupon Code | Discount | Applicable To | Limit |
|---|-------------|----------|---------------|-------|
| 1 | `GENZ25-2K6P` | 25% OFF | Subscriptions & Courses | 1 per user |
| 2 | `GENZ25-2VF4` | 25% OFF | Subscriptions & Courses | 1 per user |
| 3 | `GENZ25-3DKS` | 25% OFF | Subscriptions & Courses | 1 per user |
| 4 | `GENZ25-6G9C` | 25% OFF | Subscriptions & Courses | 1 per user |
| 5 | `GENZ25-6T2D` | 25% OFF | Subscriptions & Courses | 1 per user |
| 6 | `GENZ25-7YL3` | 25% OFF | Subscriptions & Courses | 1 per user |
| 7 | `GENZ25-ABV6` | 25% OFF | Subscriptions & Courses | 1 per user |
| 8 | `GENZ25-AG2C` | 25% OFF | Subscriptions & Courses | 1 per user |
| 9 | `GENZ25-ATSJ` | 25% OFF | Subscriptions & Courses | 1 per user |
| 10 | `GENZ25-B6AK` | 25% OFF | Subscriptions & Courses | 1 per user |
| 11 | `GENZ25-B9NL` | 25% OFF | Subscriptions & Courses | 1 per user |
| 12 | `GENZ25-BLUC` | 25% OFF | Subscriptions & Courses | 1 per user |
| 13 | `GENZ25-DSBQ` | 25% OFF | Subscriptions & Courses | 1 per user |
| 14 | `GENZ25-G233` | 25% OFF | Subscriptions & Courses | 1 per user |
| 15 | `GENZ25-GBZP` | 25% OFF | Subscriptions & Courses | 1 per user |
| 16 | `GENZ25-GMQ3` | 25% OFF | Subscriptions & Courses | 1 per user |
| 17 | `GENZ25-HZMH` | 25% OFF | Subscriptions & Courses | 1 per user |
| 18 | `GENZ25-KDCF` | 25% OFF | Subscriptions & Courses | 1 per user |
| 19 | `GENZ25-KP4Q` | 25% OFF | Subscriptions & Courses | 1 per user |
| 20 | `GENZ25-LTK6` | 25% OFF | Subscriptions & Courses | 1 per user |
| 21 | `GENZ25-MJJB` | 25% OFF | Subscriptions & Courses | 1 per user |
| 22 | `GENZ25-MKP2` | 25% OFF | Subscriptions & Courses | 1 per user |
| 23 | `GENZ25-PJQY` | 25% OFF | Subscriptions & Courses | 1 per user |
| 24 | `GENZ25-SGKU` | 25% OFF | Subscriptions & Courses | 1 per user |
| 25 | `GENZ25-TWV6` | 25% OFF | Subscriptions & Courses | 1 per user |
| 26 | `GENZ25-UKSX` | 25% OFF | Subscriptions & Courses | 1 per user |
| 27 | `GENZ25-VT8A` | 25% OFF | Subscriptions & Courses | 1 per user |
| 28 | `GENZ25-WDLM` | 25% OFF | Subscriptions & Courses | 1 per user |
| 29 | `GENZ25-YVQH` | 25% OFF | Subscriptions & Courses | 1 per user |
| 30 | `GENZ25-ZG65` | 25% OFF | Subscriptions & Courses | 1 per user |

---

### Tier 3: ₹50 Flat OFF (`GENZ50-XXXX`)
- **Discount**: Flat ₹50 discount on any paper or course purchase
- **Validity**: 7 days from reveal

| # | Coupon Code | Discount | Applicable To | Limit |
|---|-------------|----------|---------------|-------|
| 1 | `GENZ50-5MQ6` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 2 | `GENZ50-5XBZ` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 3 | `GENZ50-7T7W` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 4 | `GENZ50-84UK` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 5 | `GENZ50-8ZAG` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 6 | `GENZ50-92WV` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 7 | `GENZ50-AGRF` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 8 | `GENZ50-BAAH` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 9 | `GENZ50-CB42` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 10 | `GENZ50-CEYL` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 11 | `GENZ50-E92Q` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 12 | `GENZ50-FFCA` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 13 | `GENZ50-GR38` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 14 | `GENZ50-J37M` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 15 | `GENZ50-JCLA` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 16 | `GENZ50-NAN6` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 17 | `GENZ50-NJP9` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 18 | `GENZ50-PPKR` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 19 | `GENZ50-QQBP` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 20 | `GENZ50-R6VL` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 21 | `GENZ50-RBEJ` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 22 | `GENZ50-S3WZ` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 23 | `GENZ50-SAEG` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 24 | `GENZ50-T72J` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 25 | `GENZ50-TYA9` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 26 | `GENZ50-W6K6` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 27 | `GENZ50-WCWG` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 28 | `GENZ50-WZVR` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 29 | `GENZ50-XWQ3` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |
| 30 | `GENZ50-ZBMW` | ₹50 Flat OFF | Any Paid Paper / Course | 1 per user |

---

### Tier 4: ₹100 Flat OFF (`GENZ100-XXXX`)
- **Discount**: Flat ₹100 discount on bundles and Pro membership
- **Validity**: 7 days from reveal

| # | Coupon Code | Discount | Applicable To | Limit |
|---|-------------|----------|---------------|-------|
| 1 | `GENZ100-24RF` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 2 | `GENZ100-3AFM` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 3 | `GENZ100-45T2` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 4 | `GENZ100-5D72` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 5 | `GENZ100-7AFD` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 6 | `GENZ100-7ZU7` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 7 | `GENZ100-8Q7G` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 8 | `GENZ100-A4Y7` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 9 | `GENZ100-A89E` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 10 | `GENZ100-AU7D` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 11 | `GENZ100-C669` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 12 | `GENZ100-E3NA` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 13 | `GENZ100-ER5L` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 14 | `GENZ100-EZHA` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 15 | `GENZ100-FH6X` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 16 | `GENZ100-FJSP` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 17 | `GENZ100-FPDK` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 18 | `GENZ100-MKKH` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 19 | `GENZ100-MS23` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 20 | `GENZ100-QHKN` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 21 | `GENZ100-QHV8` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 22 | `GENZ100-TDZZ` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 23 | `GENZ100-UN96` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 24 | `GENZ100-VDP5` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 25 | `GENZ100-VHBL` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 26 | `GENZ100-WPCC` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 27 | `GENZ100-WZVL` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 28 | `GENZ100-XBUS` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 29 | `GENZ100-XVFM` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |
| 30 | `GENZ100-YLZM` | ₹100 Flat OFF | Bundles & Pro Annual | 1 per user |

---

### Tier 5: 1 Free Paid Paper Unlock (`PAPER-XXXX`)
- **Discount**: 100% discount on any 1 single paid paper
- **Validity**: 7 days from reveal

| # | Coupon Code | Discount | Applicable To | Limit |
|---|-------------|----------|---------------|-------|
| 1 | `PAPER-24JR` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 2 | `PAPER-3CAE` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 3 | `PAPER-3JXC` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 4 | `PAPER-3M8W` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 5 | `PAPER-47HM` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 6 | `PAPER-4DD6` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 7 | `PAPER-869Q` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 8 | `PAPER-897W` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 9 | `PAPER-8FAK` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 10 | `PAPER-9MUY` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 11 | `PAPER-ARFP` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 12 | `PAPER-D98N` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 13 | `PAPER-EWR6` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 14 | `PAPER-FMGJ` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 15 | `PAPER-FX5Y` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 16 | `PAPER-G637` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 17 | `PAPER-HLMC` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 18 | `PAPER-K6PN` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 19 | `PAPER-K7AN` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 20 | `PAPER-KLSM` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 21 | `PAPER-NBNU` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 22 | `PAPER-PQCX` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 23 | `PAPER-Q3VN` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 24 | `PAPER-QL3V` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 25 | `PAPER-RKR8` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 26 | `PAPER-TUGY` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 27 | `PAPER-U3J9` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 28 | `PAPER-XL44` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 29 | `PAPER-ZHFV` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |
| 30 | `PAPER-ZK6F` | 100% OFF (1 Paper) | Single Paid Papers | 1 per user |

---

## 🛠️ How to Add Coupons to Your Website

### Option A: In Razorpay Dashboard (Standard Checkout)
1. Go to **Razorpay Dashboard** > **Payment Gateway** > **Offers**.
2. Click **Create Offer**.
3. Set:
   - **Offer Name**: `Spin & Win 15% OFF` (or corresponding tier).
   - **Coupon Codes**: Paste the codes from the tables above (or set prefix matching `GENZ15-`, `GENZ25-`, `GENZ50-`, `GENZ100-`).
   - **Discount Type**: Percentage (e.g. 15%, 25%) or Flat (₹50, ₹100).
   - **Max Usage per Customer**: 1.
4. Save and activate the offer.

### Option B: In Laravel / Custom Database
If your website validates coupons via a SQL table (e.g. `coupons`), you can import with:
```sql
-- Example SQL insertion
INSERT INTO coupons (code, discount_type, discount_value, expires_in_days, max_uses_per_user) VALUES
('GENZ15-2X8K', 'percentage', 15.00, 7, 1),
('GENZ25-9M4L', 'percentage', 25.00, 7, 1),
('GENZ50-3P7Q', 'flat', 50.00, 7, 1),
('GENZ100-8R2W', 'flat', 100.00, 7, 1),
('PAPER-4K9N', 'flat', 100.00, 7, 1);
```

---

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
