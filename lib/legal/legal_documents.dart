// Olympus Mont Systems LLC - ControlMiles
// lib/legal/legal_documents.dart
//
// DRAFT LEGAL TEXT -- NOT REVIEWED BY AN ATTORNEY. Do not treat this as a
// finished, publishable Privacy Policy / Terms of Service. It is a working
// first draft, grounded in what the app actually does as of 2026-08-27
// (permissions requested, data actually collected/stored, the premium
// auto-detect feature, fleet/org data sharing), meant to give a real
// attorney a concrete starting point instead of a blank page. Update
// lastUpdated below whenever the text changes, and get real legal review
// before this is linked from the Play Store listing or relied upon.
//
// Deliberately English-only, not routed through appState.tr() -- same
// precedent already established in report_service.dart's IrsPurposeCatalog
// (the PDF's plain-English labels), on the reasoning that translating
// legal text per-locale without a legal/linguistic review of EACH
// translation is its own liability, not a UX nice-to-have. The short
// disclaimer shown inline in Settings (see settings_screen.dart) IS
// translated -- low translation risk, high value for non-English users.

const String legalDocumentsLastUpdated = 'August 27, 2026';

const String privacyPolicyEn = '''
Last updated: $legalDocumentsLastUpdated

This is a draft Privacy Policy, published for transparency while it undergoes legal review. If you have questions, contact privacy@controlmiles.com.

1. WHO WE ARE

ControlMiles is developed by Olympus Mont Systems LLC ("we", "us", "our"). This Privacy Policy explains what information ControlMiles collects, how we use it, and the choices you have.

2. INFORMATION WE COLLECT

Account information: email address and, if you provide them, your first and last name.

Location data: with your permission, ControlMiles records GPS location while you are actively tracking a trip (and briefly in the background to detect trip start/stop). Location is used to calculate mileage and is not collected when no trip is active.

Odometer photos: when you start or end a trip, ControlMiles asks you to photograph your vehicle's odometer. These photos are processed on your device (to read the number automatically) and uploaded to our cloud storage as evidence supporting your mileage records.

Vehicle and trip information: the vehicles you add, trip start/end times, mileage, the gig platform or purpose you associate with a trip, and any notes you choose to add.

Gig-app detection (optional, premium feature): if you enable Automatic Detection, ControlMiles uses Android's Usage Access permission to identify which app is in the foreground on your device, so it can suggest starting a trip. This only reads the name of the app currently on screen -- ControlMiles never accesses the contents, account, trip data, or earnings of any third-party app. This feature can be turned off at any time in Settings.

Device and diagnostic information: basic technical information (device type, OS version, app version) used for troubleshooting.

3. HOW WE USE YOUR INFORMATION

To provide the core service: recording, calculating, and reporting your mileage; generating PDF reports; storing your evidence photos.
To operate premium features you enable, such as automatic trip detection.
To maintain your account, respond to support requests, and secure the app against fraud or abuse.
We do not sell your personal information, and we do not currently use third-party advertising networks.

4. HOW WE SHARE INFORMATION

Fleet/organization accounts: if you join or create an organization (Fleet mode), your assigned vehicle, trip mileage, and vehicle inspection records are visible to that organization's admin(s), consistent with the role you or they set up. Personal Gig-mode accounts are not shared with any organization.

Service providers: we use Supabase (database, authentication, and file storage) to operate ControlMiles. We do not share your data with other third parties except as required by law or to protect the rights, property, or safety of ControlMiles, our users, or others.

5. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

ControlMiles lets you label trips with the name of the gig platform you were working for (for example: Uber, Lyft, DoorDash, Instacart, Amazon Flex, Roadie, Shipt, Veho, Jitsu, Spark Driver, and others), and, if you enable Automatic Detection, can recognize when one of those apps is open on your device.

ControlMiles is an independent, third-party tool. It is not affiliated with, endorsed by, sponsored by, or officially connected to Uber, Lyft, DoorDash, Instacart, Amazon, Walmart, Shipt, Roadie, or any other platform referenced in the app. All product names, logos, and brand names are trademarks of their respective owners, used here only to describe compatibility. ControlMiles does not access, read, or store any data from those platforms' own apps, accounts, or servers -- it only knows the name of whichever app is currently on your screen.

6. DATA RETENTION

We retain your trip, vehicle, and account data for as long as your account is active, or until you delete individual trips or your entire account. Deleting your account permanently removes your data, including uploaded evidence photos, from our systems.

7. YOUR CHOICES

You can delete individual trips at any time from the History screen.
You can delete your account at any time from Settings -- this is permanent and cannot be undone.
You can revoke location, camera, or Usage Access permissions at any time from your device's system settings; doing so will limit or disable the corresponding features.
You can turn Automatic Detection off at any time.

8. CHILDREN'S PRIVACY

ControlMiles is not directed at children and is not intended for use by anyone under the age of 18.

9. SECURITY

We use industry-standard measures to protect your information, including encrypted network connections and access controls. No method of storage or transmission is 100% secure, and we cannot guarantee absolute security.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above.

11. CONTACT US

Questions about this policy: privacy@controlmiles.com
''';

const String termsOfServiceEn = '''
Last updated: $legalDocumentsLastUpdated

This is a draft Terms of Service, published for transparency while it undergoes legal review. If you have questions, contact legal@controlmiles.com.

1. ACCEPTANCE OF TERMS

By creating an account or using ControlMiles, you agree to these Terms of Service. If you do not agree, do not use the app.

2. DESCRIPTION OF SERVICE

ControlMiles is a mileage-tracking tool for gig, rideshare, delivery, and fleet drivers. It records GPS-based trip mileage, captures odometer photos as supporting evidence, and generates reports intended to help you document business mileage, including for tax purposes.

3. NOT TAX OR LEGAL ADVICE

ControlMiles is not affiliated with or endorsed by the IRS or any tax authority. Mileage deduction estimates shown in the app or in generated reports (including any figure based on the IRS standard mileage rate) are informational only, not a guarantee of any deduction amount, and not a substitute for advice from a qualified tax professional. You are solely responsible for the accuracy of your tax filings.

4. ELIGIBILITY AND YOUR ACCOUNT

You must be at least 18 years old to use ControlMiles. You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account. Notify us promptly of any unauthorized use.

5. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

ControlMiles is an independent tool that lets you label your own trips with the name of a gig platform (Uber, Lyft, DoorDash, Instacart, Amazon Flex, Roadie, Shipt, Veho, Jitsu, Spark Driver, and others) and, optionally, detect when one of those apps is open on your device. ControlMiles is not affiliated with, endorsed by, or sponsored by any of these companies, and does not access their apps' data, accounts, or servers. You are responsible for complying with the terms of service of any gig, delivery, or rideshare platform you work with; nothing in ControlMiles is intended to help you violate those terms.

6. PREMIUM FEATURES AND SUBSCRIPTIONS

Some features (such as Automatic Detection) may require a paid subscription or entitlement. Pricing, billing terms, and cancellation policy will be presented at the time of purchase. We reserve the right to change premium feature availability or pricing with reasonable notice.

7. FLEET / ORGANIZATION ACCOUNTS

If you join or create an organization (Fleet mode), you acknowledge that certain data -- assigned vehicle, trip mileage, and vehicle inspection records -- becomes visible to that organization's administrator(s). Organization administrators are responsible for how they use driver data within their organization and for complying with applicable employment and privacy laws.

8. ACCEPTABLE USE

You agree not to: use ControlMiles for any unlawful purpose; attempt to reverse-engineer, decompile, or interfere with the app or its backend; submit fraudulent mileage, odometer, or trip data; or use the app in a way that infringes the rights of any third party, including the trademark rights discussed in Section 5.

9. INTELLECTUAL PROPERTY

ControlMiles, its logo, and its original content are the property of Olympus Mont Systems LLC. Third-party names and logos referenced in the app remain the property of their respective owners.

10. DISCLAIMER OF WARRANTIES

ControlMiles is provided "as is" and "as available," without warranties of any kind, express or implied. We do not guarantee that GPS tracking, mileage calculations, or OCR odometer readings will be error-free or uninterrupted. You are responsible for reviewing your trip data for accuracy before relying on it.

11. LIMITATION OF LIABILITY

To the maximum extent permitted by law, Olympus Mont Systems LLC will not be liable for any indirect, incidental, special, or consequential damages, including lost income or lost tax deductions, arising from your use of ControlMiles.

12. TERMINATION

You may stop using ControlMiles and delete your account at any time. We may suspend or terminate accounts that violate these Terms.

13. GOVERNING LAW

[Placeholder -- to be finalized with counsel: state/jurisdiction whose law governs these Terms.]

14. CHANGES TO THESE TERMS

We may update these Terms from time to time. Continued use of ControlMiles after a change constitutes acceptance of the updated Terms.

15. CONTACT US

Questions about these Terms: legal@controlmiles.com
''';
