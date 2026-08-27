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

// Explicit user request (2026-08-28): Fleet-mode accounts (an organization
// and its admin(s)/dispatchers, with drivers assigned under them) are a
// meaningfully different relationship than an individual Gig driver using
// ControlMiles for their own records -- an organization is itself
// collecting and directing the use of its drivers' location/mileage/
// inspection data, not just generating a personal report. The individual
// versions above still cover that relationship briefly (Privacy Policy
// section 4, Terms section 7), but only in passing. These Fleet-facing
// versions lead with the organization/company relationship instead,
// since that's what's actually relevant to a Fleet admin or a driver
// operating under one -- shown instead of the individual versions
// whenever AppState.isFleetAccount is true (see settings_screen.dart).
// Same draft/pending-legal-review status as the individual versions.
const String privacyPolicyFleetEn = '''
Last updated: $legalDocumentsLastUpdated

This is a draft Privacy Policy for Fleet/organization accounts, published for transparency while it undergoes legal review. If you have questions, contact privacy@controlmiles.com.

1. WHO THIS APPLIES TO

This Privacy Policy applies to organizations ("Fleet accounts") using ControlMiles to manage drivers and vehicles, and to the drivers operating under them. ControlMiles is developed by Olympus Mont Systems LLC ("we", "us", "our").

2. ROLES: ORGANIZATION AND DRIVER

An organization's administrator(s) create and manage the Fleet account, invite drivers, assign vehicles, and can view the data described in Section 3 for drivers under their organization. Administrators are responsible for how they use that data and for complying with applicable employment, labor, and privacy laws in their jurisdiction -- ControlMiles provides the tool, but the organization controls how it is used within their business. A driver joining an organization's Fleet account acknowledges that their assigned vehicle and trip data becomes visible to that organization's administrator(s), as described below.

3. INFORMATION WE COLLECT AND MAKE VISIBLE TO THE ORGANIZATION

Account and roster information: driver name, email, assigned vehicle, and role within the organization.

Location data: GPS location recorded while a driver is actively tracking a trip under the organization, including live location on the organization's fleet map (if the organization uses that feature) and any geofences the organization has configured.

Trip and mileage data: trip start/end times, mileage, and duration for trips logged under the organization.

Vehicle inspection (DVIR) records: pre-trip/post-trip inspection results, including any reported defects and photos submitted with them.

Odometer photos: photographed at trip start/end, processed on-device and uploaded as evidence supporting the organization's mileage records.

Incident reports: if a driver submits an incident report, its category, description, and any photo attached.

Device and diagnostic information: basic technical information (device type, OS version, app version) used for troubleshooting.

4. HOW THIS INFORMATION IS USED

By the organization: to track vehicle usage and mileage across their fleet, verify inspection compliance, respond to incidents, and manage which drivers are assigned to which vehicles.

By us: to operate the service (recording, calculating, and reporting mileage and inspection data; generating PDF/CSV reports the organization requests; storing evidence photos), to maintain the account, respond to support requests, and secure the app against fraud or abuse. We do not sell this information, and we do not currently use third-party advertising networks.

5. DATA SHARING

Within the organization: the data in Section 3 is visible to the organization's administrator(s) -- that visibility is the core function of a Fleet account, not an incidental data share.

Service providers: we use Supabase (database, authentication, and file storage) to operate ControlMiles. We do not share this data with other third parties except as required by law or to protect the rights, property, or safety of ControlMiles, the organization, its drivers, or others.

Between organizations: a driver's data is only visible to the organization(s) they are actively assigned to. Removing a driver from an organization ends that organization's ongoing visibility into new trips.

6. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

If drivers under an organization also label trips with a gig/delivery platform name (for example: Uber, Lyft, DoorDash, Instacart, Amazon Flex, Roadie, Shipt, Veho, Jitsu, Spark Driver, and others), ControlMiles is not affiliated with, endorsed by, or sponsored by any of those platforms. It does not access, read, or store any data from those platforms' own apps, accounts, or servers.

7. DATA RETENTION

We retain an organization's driver, vehicle, trip, and inspection data for as long as the Fleet account is active, or until the organization or the individual driver deletes specific records, consistent with the organization's own account settings and applicable law. Deleting a Fleet account permanently removes the organization's data, including uploaded evidence photos and inspection records, from our systems.

8. DRIVER CHOICES

A driver can delete individual trips they logged, subject to the organization's own record-keeping policies. A driver can revoke location, camera, or Usage Access permissions at any time from their device's system settings; doing so will limit or disable the corresponding features for trips logged under the organization.

9. CHILDREN'S PRIVACY

ControlMiles is not directed at children and is not intended for use by anyone under the age of 18.

10. SECURITY

We use industry-standard measures to protect this information, including encrypted network connections and access controls. No method of storage or transmission is 100% secure, and we cannot guarantee absolute security.

11. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above.

12. CONTACT US

Questions about this policy: privacy@controlmiles.com
''';

const String termsOfServiceFleetEn = '''
Last updated: $legalDocumentsLastUpdated

This is a draft Terms of Service for Fleet/organization accounts, published for transparency while it undergoes legal review. If you have questions, contact legal@controlmiles.com.

1. ACCEPTANCE OF TERMS

By creating or joining a Fleet account, or by using ControlMiles as a driver assigned to one, you agree to these Terms of Service. If you do not agree, do not use the app in that capacity.

2. DESCRIPTION OF SERVICE

ControlMiles is a fleet mileage-tracking and compliance tool. It lets an organization manage a roster of drivers and vehicles, track GPS-based trip mileage, collect vehicle inspection (DVIR) records, view driver location on a live map, and generate reports across the fleet.

3. THE ORGANIZATION'S RESPONSIBILITIES

An organization creating a Fleet account is responsible for: obtaining any consent or notice required under applicable employment and privacy law before tracking a driver's location or vehicle data; accurately assigning and removing drivers and vehicles; and using driver data collected through ControlMiles only for legitimate business purposes related to fleet management, mileage documentation, and vehicle compliance. ControlMiles is a tool the organization directs -- Olympus Mont Systems LLC does not decide how an organization uses driver data within its own operations.

4. DRIVERS OPERATING UNDER AN ORGANIZATION

By accepting an invitation to join an organization's Fleet account, a driver acknowledges that their assigned vehicle, trip mileage, GPS location while tracking, and vehicle inspection records become visible to that organization's administrator(s), as described in the Fleet Privacy Policy. A driver should direct questions about how their organization specifically uses this data to that organization, not to Olympus Mont Systems LLC.

5. NOT TAX OR LEGAL ADVICE

ControlMiles is not affiliated with or endorsed by the IRS or any tax authority. Mileage figures shown in the app or in generated reports are informational only, not a guarantee of any deduction or reimbursement amount, and not a substitute for advice from a qualified tax or legal professional.

6. ELIGIBILITY AND ACCOUNTS

Anyone using ControlMiles, including under a Fleet account, must be at least 18 years old. The organization and each driver are responsible for maintaining the confidentiality of their own account credentials and for all activity under their account. Notify us promptly of any unauthorized use.

7. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

If drivers under an organization label trips with the name of a gig, delivery, or rideshare platform, ControlMiles is not affiliated with, endorsed by, or sponsored by any of those platforms, and does not access their apps' data, accounts, or servers.

8. SUBSCRIPTIONS AND BILLING

Fleet accounts may require a paid subscription, billed to the organization, covering some number of driver seats. Pricing, billing terms, and cancellation policy will be presented at the time of purchase. We reserve the right to change Fleet plan availability or pricing with reasonable notice.

9. ACCEPTABLE USE

The organization and its drivers agree not to: use ControlMiles for any unlawful purpose, including surveillance beyond what applicable law permits; attempt to reverse-engineer, decompile, or interfere with the app or its backend; submit fraudulent mileage, odometer, inspection, or incident data; or use the app in a way that infringes the rights of any third party.

10. INTELLECTUAL PROPERTY

ControlMiles, its logo, and its original content are the property of Olympus Mont Systems LLC. Third-party names and logos referenced in the app remain the property of their respective owners.

11. DISCLAIMER OF WARRANTIES

ControlMiles is provided "as is" and "as available," without warranties of any kind, express or implied. We do not guarantee that GPS tracking, mileage calculations, live location, or inspection records will be error-free or uninterrupted. The organization is responsible for reviewing fleet data for accuracy before relying on it.

12. LIMITATION OF LIABILITY

To the maximum extent permitted by law, Olympus Mont Systems LLC will not be liable for any indirect, incidental, special, or consequential damages, including lost income, lost tax deductions, or employment-related disputes between an organization and its drivers, arising from use of ControlMiles.

13. TERMINATION

An organization may cancel its Fleet account, and a driver may leave an organization, at any time. We may suspend or terminate a Fleet account that violates these Terms.

14. GOVERNING LAW

[Placeholder -- to be finalized with counsel: state/jurisdiction whose law governs these Terms.]

15. CHANGES TO THESE TERMS

We may update these Terms from time to time. Continued use of ControlMiles after a change constitutes acceptance of the updated Terms.

16. CONTACT US

Questions about these Terms: legal@controlmiles.com
''';
