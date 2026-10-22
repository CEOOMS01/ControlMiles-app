// Olympus Mont Systems LLC - ControlMiles
// lib/legal/legal_documents.dart
//
// Strengthened 2026-09-09 (explicit user request): removed the user-facing
// "draft, pending legal review" banner and filled in the previously-open
// Governing Law placeholder (Maryland, per the user directly). Added the
// protections real competitor mileage-tracking apps carry that this
// document didn't (researched live: MileIQ's published Terms/Privacy at
// mileiq.com/terms and mileiq.com/privacy, Everlance's at everlance.com/
// terms-of-service and everlance.com/privacy) -- binding arbitration +
// class action waiver (MileIQ has this; this document didn't), an
// indemnification clause, and the standard severability/entire-agreement/
// assignment boilerplate every one of these documents carries and this one
// was missing entirely. Privacy Policy gained a CCPA/CPRA rights section
// (California and comparable-law states) and a brief international-users
// note, matching what Everlance and MileIQ both disclose given a
// multi-language, non-US-only user base.
//
// This was assembled by an AI system against public competitor documents
// and general legal-drafting practice, not drafted or reviewed by a
// licensed attorney -- it is not legal advice. The user has explicitly
// directed that no draft/pending-review notice be shown to end users, but
// having actual counsel review this before a real dispute, a regulatory
// inquiry, or a material product change (new data types, new jurisdictions,
// payment processing changes) remains genuinely advisable, not a formality.
//
// Updated 2026-10-01 (explicit user request: "add everything new that was
// integrated, and the map-use statement"): maps (OpenStreetMap/ODbL,
// Protomaps, Cloudflare, Overpass speed limits), safe-driving/not-a-
// navigation-system clause, route trails, motion activity, Google Sign-In,
// auto-renewal and refunds (Google Play / Stripe), named service providers,
// and on the Fleet side: live map, branches, shifts/schedules/classes,
// owner-operators, fuel purchases + anomaly alerts, IFTA, idle time, safety
// score, messages, people recorded without an account (driving-school
// students), and automated flags are not decisions. Same text is published
// on the website (src/lib/legal-texts.ts there) -- keep them identical.
//
// Deliberately English-only, not routed through appState.tr() -- same
// precedent already established in report_service.dart's IrsPurposeCatalog
// (the PDF's plain-English labels), on the reasoning that translating
// legal text per-locale without a legal/linguistic review of EACH
// translation is its own liability, not a UX nice-to-have. The short
// disclaimer shown inline in Settings (see settings_screen.dart) IS
// translated -- low translation risk, high value for non-English users.

const String legalDocumentsLastUpdated = 'October 1, 2026';

/// Same date, machine form -- what accept_legal_terms() records next to
/// the acceptance timestamp (profiles.legal_terms_version). Bump both
/// together, and the website's copy (src/lib/legal-version.ts).
const String legalTermsVersion = '2026-10-01';

const String privacyPolicyEn = '''
Last updated: $legalDocumentsLastUpdated
© 2026 ControlMiles. All rights reserved.

1. WHO WE ARE

ControlMiles is developed by Olympus Mont Systems LLC ("we", "us", "our"). This Privacy Policy explains what information ControlMiles (the mobile app and the website at controlmiles.com) collects, how we use it, who we share it with, and the choices you have. If you join or create an organization (Fleet account), the Fleet Privacy Policy (controlmiles.com/privacy/fleet) also applies to the data you record under that organization.

2. INFORMATION WE COLLECT

Account information: your email address, your first and last name, and the account type you choose (personal driver, fleet owner/administrator, or fleet driver). If you sign in with Google, we receive your name, email address, and Google account identifier from Google; we never receive your Google password.

Location data: with your permission, ControlMiles records precise GPS location while you are tracking a trip, including in the background while a trip is running. We store the route of each trip (a trail of GPS points) together with its mileage, so the trip can be shown on a map and in your reports. If you use Automatic Detection, the app also uses location in the background to detect when a trip starts or stops. Location is not recorded when no trip is active and Automatic Detection is off.

Motion activity: with your permission, ControlMiles uses your device's physical-activity recognition (for example "in vehicle" vs. "still") to help detect trips and filter out GPS noise. This is processed on your device.

Odometer photos: when you start or end a trip, ControlMiles may ask you to photograph your vehicle's odometer. The number is read on your device (on-device text recognition), and the photo is uploaded to our cloud storage as evidence supporting your mileage records.

Vehicle and trip information: the vehicles you add, trip start/end times, mileage, the gig platform or business purpose you associate with a trip, and any notes you choose to add.

Gig-app detection (optional, premium feature): if you enable Automatic Detection, ControlMiles uses Android's Usage Access permission to identify which app is in the foreground on your device, so it can suggest or start a trip. It only reads the name of the app on screen -- never the contents, account, trip data, or earnings of any third-party app. You can turn this off at any time.

Purchases: if you buy a subscription, the payment is processed by Google Play (in the app) or Stripe (on the website). We receive the subscription status, plan, and transaction identifiers -- never your full card number.

Device and diagnostic information: device type, operating-system version, app version, and crash or error reports (including the screen or step where the error happened), used for troubleshooting and security.

Website data: the website uses cookies that are strictly necessary to keep you signed in and to remember your language. We do not use advertising or cross-site tracking cookies.

3. HOW WE USE YOUR INFORMATION

To provide the service: recording, calculating, and reporting your mileage; drawing your trip routes; generating PDF/CSV reports; storing your evidence photos.
To protect the integrity of mileage records: trips are checked by automated anti-fraud rules (for example impossible speeds or GPS jumps), and a summary of each closed trip may be sent to our own trip-integrity service, which records a tamper-evident cryptographic seal of that trip.
To operate premium features you enable, such as automatic trip detection.
To send service emails (for example account confirmation, password changes, and security notices). We do not send marketing email without your consent.
To maintain your account, respond to support requests, and secure the service against fraud or abuse.
We do not sell your personal information, we do not share it for cross-context behavioral advertising, and we do not use third-party advertising networks.

4. MAPS AND LOCATION SERVICES

Maps in ControlMiles are drawn from map data by OpenStreetMap contributors, packaged by Protomaps and hosted for us on Cloudflare's storage network. To show a map, your device downloads map tiles from that storage and map fonts and icons from Protomaps' public servers (hosted on GitHub Pages). Those requests reveal your device's IP address and the general area being displayed to the hosting provider, as with any website, but they do not include your name, email, or account.

For fleet trips, ControlMiles may look up the posted speed limit near a point where the vehicle appears to be speeding. That lookup sends the coordinates of that point -- and nothing else about you -- to the public OpenStreetMap Overpass API (overpass-api.de), operated by a third party.

Map data © OpenStreetMap contributors, available under the Open Database License (ODbL). Map attribution is shown on every map in the app and on the website.

5. HOW WE SHARE INFORMATION

Fleet/organization accounts: if you join or create an organization (Fleet mode), the data you record under that organization is visible to its administrators as described in the Fleet Privacy Policy. Personal (gig-mode) trips are not shared with any organization.

Service providers that process data on our behalf, only to run ControlMiles: Supabase (database, authentication, file storage, and server functions); Vercel (website hosting); Cloudflare (map tile hosting); Resend (delivery of service emails); Stripe (website payments); Google (Google Play billing and Google Sign-In); and our own trip-integrity and error-monitoring service.

Map services: Protomaps' public servers and the OpenStreetMap Overpass API, as described in Section 4.

We may also disclose information if required by law, or to protect the rights, property, or safety of ControlMiles, our users, or others, and in connection with a merger, acquisition, or sale of assets (subject to this Policy).

6. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

ControlMiles lets you label trips with the name of the gig platform you were working for, and, if you enable Automatic Detection, can recognize when one of those apps is open on your device.

ControlMiles is an independent, third-party tool. It is not affiliated with, endorsed by, sponsored by, or officially connected to any gig, delivery, or rideshare platform referenced in the app. All product names, logos, and brand names are trademarks of their respective owners, used here only to describe compatibility. ControlMiles does not access, read, or store any data from those platforms' own apps, accounts, or servers -- it only knows the name of whichever app is currently on your screen.

7. DATA RETENTION

We retain your trip, route, vehicle, and account data for as long as your account is active, or until you delete individual trips or your entire account. Deleting your account permanently removes your data, including routes and uploaded evidence photos, from our active systems; residual copies in encrypted backups are overwritten on the backup rotation schedule. Cryptographic trip seals contain a short trip summary (trip and vehicle identifiers, miles, duration, and the account email) but no photos or routes, and may be kept to preserve the integrity of the audit chain. Billing records may be kept as long as tax and accounting law requires.

8. YOUR CHOICES

You can delete individual trips at any time from the History screen.
You can delete your account at any time from Settings (in the app) or from the website -- this is permanent and cannot be undone.
You can revoke location, physical-activity, camera, notification, or Usage Access permissions at any time from your device's system settings; doing so will limit or disable the corresponding features.
You can turn Automatic Detection off at any time.

9. YOUR PRIVACY RIGHTS (CALIFORNIA AND OTHER U.S. STATES)

If you are a California resident, the California Consumer Privacy Act (CCPA), as amended by the CPRA, gives you the right to: know what personal information we collect and how we use it; request deletion of your personal information; correct inaccurate personal information; limit the use of sensitive personal information (such as precise location) -- which we only use to provide the service you request; and not be discriminated against for exercising these rights. We do not sell or share your personal information for cross-context behavioral advertising.

Residents of other U.S. states with comparable privacy laws (for example Maryland, Virginia, Colorado, Connecticut, Oregon, Texas, and Utah) have similar rights, including the right to access, correct, delete, and obtain a copy of their data, and to appeal our decision on a request. We honor these rights on the same basis.

To exercise any of these rights, contact privacy@controlmiles.com. We may need to verify your identity before responding.

10. INTERNATIONAL USERS

If you access ControlMiles from outside the United States, your information will be transferred to and processed in the United States. If you are located in the European Economic Area, United Kingdom, or Switzerland, you may have additional rights under the GDPR or UK GDPR, including the right to access, correct, delete, or port your personal data, and the right to object to certain processing. Contact privacy@controlmiles.com to exercise these rights.

11. CHILDREN'S PRIVACY

ControlMiles is not directed at children and is not intended for use by anyone under the age of 18. We do not knowingly collect personal information from children.

12. SECURITY

We use industry-standard measures to protect your information, including encrypted connections, access controls enforced at the database level, and tamper-evident trip records. No method of storage or transmission is 100% secure, and we cannot guarantee absolute security. Report security issues to security@controlmiles.com.

13. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above and, where appropriate, by notice in the app, on the website, or by email.

14. CONTACT US

Privacy questions and data-rights requests: privacy@controlmiles.com. Support: support@controlmiles.com.
''';

const String termsOfServiceEn = '''
Last updated: $legalDocumentsLastUpdated
© 2026 ControlMiles. All rights reserved.

1. ACCEPTANCE OF TERMS

By creating an account or using ControlMiles (the mobile app or the website at controlmiles.com), you agree to these Terms of Service and to our Privacy Policy. If you do not agree, do not use ControlMiles. If you create or join an organization (Fleet account), the Fleet Terms of Service (controlmiles.com/terms/fleet) also apply to that use.

2. DESCRIPTION OF SERVICE

ControlMiles is a mileage-tracking tool for gig, rideshare, delivery, and fleet drivers. It records GPS-based trip mileage and routes, captures odometer photos as supporting evidence, can detect trips automatically, shows your position and trip routes on maps, and generates reports intended to help you document business mileage, including for tax purposes.

3. NOT TAX OR LEGAL ADVICE

ControlMiles is not affiliated with or endorsed by the IRS or any tax authority. Mileage deduction estimates shown in the app or in generated reports (including any figure based on the IRS standard mileage rate) are informational only, not a guarantee of any deduction amount, and not a substitute for advice from a qualified tax professional. You are solely responsible for the accuracy of your tax filings.

4. ELIGIBILITY AND YOUR ACCOUNT

You must be at least 18 years old to use ControlMiles. You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account. Notify us promptly of any unauthorized use at security@controlmiles.com.

5. SAFE DRIVING

Your safety and compliance with traffic laws come first. Do not handle your phone or interact with ControlMiles while the vehicle is moving; set up trips before you drive or when safely stopped, and follow local laws on mobile-device use while driving. ControlMiles is not a navigation system: maps, routes, positions, and speed information are approximate, may be delayed or inaccurate, and must not be used to navigate, to judge road conditions, or to decide how fast to drive.

6. MAPS AND THIRD-PARTY DATA

Maps in ControlMiles use map data © OpenStreetMap contributors, available under the Open Database License (ODbL), packaged by Protomaps, and are rendered with the open-source MapLibre library. OpenStreetMap data is created by volunteers and may be incomplete or out of date, including street names and posted speed limits. You may not remove or obscure the map attribution shown in the app or on the website. The OpenStreetMap Foundation and Protomaps are not affiliated with ControlMiles and do not endorse it.

7. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

ControlMiles is an independent tool that lets you label your own trips with the name of a gig platform and, optionally, detect when one of those apps is open on your device. ControlMiles is not affiliated with, endorsed by, or sponsored by any gig, delivery, or rideshare company, and does not access their apps' data, accounts, or servers. You are responsible for complying with the terms of service of any gig, delivery, or rideshare platform you work with; nothing in ControlMiles is intended to help you violate those terms.

8. SUBSCRIPTIONS, AUTOMATIC RENEWAL, AND REFUNDS

Some features (such as Automatic Detection) require a paid subscription. The price, billing period, and any free trial are shown before you buy. Subscriptions renew automatically at the end of each billing period at the then-current price until you cancel. If a free trial is offered, you will be charged when it ends unless you cancel before then.

Purchases made in the mobile app are processed by Google Play under Google Play's terms; you can cancel at any time in Google Play > Payments & subscriptions, and refunds follow Google Play's refund policy. Purchases made on the website are processed by Stripe; you can cancel at any time from the billing page of your account. Cancellation takes effect at the end of the current billing period, and you keep access until then. Except where required by law, payments are non-refundable and we do not provide refunds or credits for partial billing periods.

We may change prices or premium features with reasonable advance notice; a price change applies from your next billing period after the notice, and you may cancel before it takes effect.

9. FLEET / ORGANIZATION ACCOUNTS

If you join or create an organization (Fleet mode), the data you record under that organization -- including your assigned vehicle, trips, routes, live location while a trip is open, inspections, fuel purchases, and driving-behavior events -- becomes visible to that organization's administrators, as described in the Fleet Terms of Service and the Fleet Privacy Policy. Your personal (gig-mode) trips are not shared with the organization.

10. ACCEPTABLE USE

You agree not to: use ControlMiles for any unlawful purpose; track a person or vehicle without the authorization and notice required by law; attempt to reverse-engineer, decompile, or interfere with the app, the website, or their backend; scrape or bulk-download map data or other content; submit fraudulent mileage, odometer, receipt, or trip data, or spoof GPS location; or use ControlMiles in a way that infringes the rights of any third party, including the trademark rights discussed in Section 7.

11. INTELLECTUAL PROPERTY

ControlMiles, its logo, and its original content are the property of Olympus Mont Systems LLC. Third-party names, logos, and map data referenced in ControlMiles remain the property of their respective owners and are used under their own licenses. Open-source software included in the app is licensed under its own terms, listed in the app.

12. DISCLAIMER OF WARRANTIES

ControlMiles is provided "as is" and "as available," without warranties of any kind, express or implied. We do not guarantee that GPS tracking, routes, maps, automatic trip detection, mileage calculations, or odometer readings will be accurate, complete, error-free, or uninterrupted. You are responsible for reviewing your trip data for accuracy before relying on it.

13. LIMITATION OF LIABILITY

To the maximum extent permitted by law, Olympus Mont Systems LLC will not be liable for any indirect, incidental, special, or consequential damages, including lost income or lost tax deductions, or for any accident, injury, or traffic violation, arising from your use of ControlMiles. Our total liability for any claim relating to ControlMiles will not exceed the amount you paid us for ControlMiles in the 12 months before the claim (or US \$50 if you paid nothing).

14. INDEMNIFICATION

You agree to indemnify, defend, and hold harmless Olympus Mont Systems LLC, its officers, employees, and agents from any claims, damages, losses, liabilities, and expenses (including reasonable attorneys' fees) arising out of or related to: your use of ControlMiles; your violation of these Terms; your violation of any law or the rights of a third party; or any data, mileage, odometer, receipt, or trip information you submit that is inaccurate or fraudulent.

15. DISPUTE RESOLUTION; BINDING ARBITRATION; CLASS ACTION WAIVER

Please read this section carefully. It affects your legal rights.

Informal resolution first. Before filing a claim against ControlMiles, you agree to first contact us at info@controlmiles.com and attempt in good faith to resolve the dispute informally for at least 30 days.

Binding arbitration. If a dispute is not resolved informally, you and Olympus Mont Systems LLC agree that it will be resolved by binding, individual arbitration administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules, rather than in court, except that either party may bring an individual claim in small claims court if it qualifies.

Class action waiver. You and Olympus Mont Systems LLC agree that any arbitration or claim will be conducted on an individual basis only, not as a class, collective, or representative action, and the arbitrator may not consolidate more than one person's claims.

Opt-out. You may opt out of this arbitration agreement by emailing info@controlmiles.com within 30 days of first agreeing to these Terms, stating your name and that you opt out of arbitration.

This section survives termination of your account and these Terms.

16. TERMINATION

You may stop using ControlMiles and delete your account at any time. We may suspend or terminate accounts that violate these Terms, that submit fraudulent data, or whose use puts the service or other users at risk. Sections that by their nature should survive termination (including 3, 12, 13, 14, and 15) survive it.

17. GOVERNING LAW

These Terms are governed by the laws of the State of Maryland, without regard to its conflict-of-laws principles.

18. SEVERABILITY

If any provision of these Terms is found unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary, and the remaining provisions will remain in full force and effect.

19. ENTIRE AGREEMENT

These Terms, together with the Terms of Use, the Privacy Policy (and, for Fleet use, the Fleet Terms of Service and Fleet Privacy Policy), are the entire agreement between you and Olympus Mont Systems LLC regarding ControlMiles, and supersede any prior agreements or understandings, written or oral, regarding that subject matter.

20. ASSIGNMENT

You may not assign or transfer these Terms without our prior written consent. We may assign these Terms without restriction, including in connection with a merger, acquisition, or sale of assets.

21. CHANGES TO THESE TERMS

We may update these Terms from time to time. We will update the "Last updated" date above and, for material changes, give notice in the app, on the website, or by email, and may ask you to accept the updated Terms. Continued use of ControlMiles after the effective date of a change constitutes acceptance of the updated Terms.

22. CONTACT US

Questions about these Terms and general inquiries: info@controlmiles.com. Support: support@controlmiles.com. Security issues: security@controlmiles.com.
''';

// The Fleet versions of the Privacy Policy and Terms of Service live in the
// ControlMiles Fleet app.

// Terms of Use (explicit user request, 2026-10-01). Distinct from the Terms
// of Service on purpose: rules for using the app/website (license, conduct,
// content, maps, security research, copyright) for everyone, including
// visitors without an account. Disclaimers, liability, arbitration and
// governing law are NOT restated -- section 17 points to the Terms of
// Service, so the two documents can never contradict each other.
const String termsOfUseEn = '''
Last updated: $legalDocumentsLastUpdated
© 2026 ControlMiles. All rights reserved.

1. ABOUT THESE TERMS OF USE

These Terms of Use set the rules for accessing and using the ControlMiles website (controlmiles.com), the ControlMiles mobile app, and their content (together, "ControlMiles"), which are operated by Olympus Mont Systems LLC ("we", "us", "our"). They apply to everyone, including visitors who never create an account.

If you have an account, the Terms of Service (controlmiles.com/terms) -- and, for organizations, the Fleet Terms of Service (controlmiles.com/terms/fleet) -- also apply and govern your account, subscriptions, and how disputes are resolved. Our Privacy Policy (controlmiles.com/privacy) explains how we handle personal information. If these Terms of Use conflict with the Terms of Service, the Terms of Service control.

By accessing or using ControlMiles, you agree to these Terms of Use. If you do not agree, do not use ControlMiles.

2. WHO MAY USE CONTROLMILES

You may browse the public website at any age, but you must be at least 18 years old to create an account or use the app. If you use ControlMiles on behalf of a company or organization, you confirm you are authorized to do so, and "you" includes that organization.

3. LICENSE TO USE THE APP AND WEBSITE

Subject to these Terms, we grant you a limited, personal, revocable, non-exclusive, non-transferable license to install the ControlMiles app on devices you own or control, and to access the website, solely for your own use or your organization's internal business use. All rights not expressly granted are reserved.

If you download the app from Google Play, Google Play's terms of service also apply to that download. Google is not a party to these Terms and is not responsible for ControlMiles or for providing support for it.

4. YOUR ACCOUNT AND SECURITY

Keep your password and sign-in methods confidential and do not share your account. Each driver must use their own account or driver ID; a single account may not be shared among several people to avoid paying for additional seats. Tell us immediately at security@controlmiles.com if you suspect unauthorized use. You are responsible for activity under your account.

5. ACCEPTABLE USE

When using ControlMiles, you agree not to:
track any person or vehicle without the authorization, notice, and consent required by law, or use ControlMiles for stalking, harassment, or surveillance;
falsify trip data, including by spoofing GPS location, using mock-location or emulator tools, or editing, staging, or reusing odometer photos, fuel receipts, or inspection photos;
access ControlMiles through bots, scrapers, or other automated means, or bulk-download its content or map data, except through features we provide for that purpose (such as report exports);
bypass, disable, or interfere with security features, plan limits, seat limits, or usage restrictions;
probe, scan, or test the vulnerability of ControlMiles, except as allowed under Section 12;
overload, disrupt, or attempt to gain unauthorized access to ControlMiles, its servers, or other users' accounts or data;
copy, modify, reverse-engineer, decompile, or create derivative works of the app or website, except where the law expressly allows it;
resell, sublicense, rent, or offer ControlMiles to third parties as a service bureau without our written permission;
upload malware, or content that is unlawful, infringing, defamatory, obscene, or that invades someone's privacy;
use in-app messages to harass, threaten, or discriminate against anyone;
impersonate any person or organization, or misrepresent your affiliation with them.

6. YOUR CONTENT

"Your content" means what you submit to ControlMiles: trip notes, odometer and receipt photos, inspection photos, incident reports, messages, vehicle details, and similar material. You keep ownership of your content. You grant us a worldwide, non-exclusive, royalty-free license to host, store, copy, process, and display your content only as needed to operate ControlMiles for you -- including showing it to your organization's administrators when you record it under an organization, as described in the Privacy Policy -- and to keep the service secure.

You are responsible for your content and confirm you have the right to submit it. Photos should show only what is needed (the odometer, the receipt, the vehicle); avoid capturing people, faces, or license plates of other vehicles when you can. We may remove content that violates these Terms or the law.

7. MAPS, LOCATION, AND THIRD-PARTY DATA

Maps in ControlMiles use map data © OpenStreetMap contributors, available under the Open Database License (ODbL), packaged by Protomaps and rendered with MapLibre. You may not remove, hide, or alter the map attribution, and you may not extract or reuse the map data or tiles outside ControlMiles except as the ODbL allows. Locations, routes, speeds, speed limits, and distances shown in ControlMiles are approximate and may be delayed or inaccurate.

ControlMiles also relies on third-party services, such as Google Sign-In, Google Play, Stripe, and the OpenStreetMap Overpass API. Your use of those services is subject to their own terms, and we are not responsible for them.

8. SAFE USE WHILE DRIVING

Do not handle your phone or interact with ControlMiles while the vehicle is moving. Start, pause, or end trips and fill in forms before driving or when safely parked, and follow all traffic laws and local rules on mobile-device use. ControlMiles is not a navigation system and must never be used to decide where to drive or how fast. Organizations must not require drivers to use ControlMiles while driving.

9. OUR CONTENT AND TRADEMARKS

ControlMiles, its name, logo, design, text, graphics, and software are owned by Olympus Mont Systems LLC or its licensors and are protected by intellectual-property laws. You may not use our trademarks or logos without our prior written permission. Names and logos of gig, delivery, rideshare, and other companies shown in ControlMiles belong to their owners and are used only to describe compatibility; their use does not imply any affiliation or endorsement. Open-source components of the app are licensed under their own terms, listed in the app under Settings > Licenses & map data.

10. FEEDBACK

If you send us suggestions or ideas about ControlMiles, you agree we may use them freely, without restriction or compensation to you.

11. COPYRIGHT COMPLAINTS

We respect intellectual-property rights. If you believe content on ControlMiles infringes your copyright, send a notice to info@controlmiles.com with: your contact information; a description of the copyrighted work; where the material appears on ControlMiles; a statement that you have a good-faith belief the use is not authorized by the owner, its agent, or the law; a statement, under penalty of perjury, that your notice is accurate and that you are the owner or authorized to act for the owner; and your physical or electronic signature. We may remove the material and, in appropriate cases, terminate the accounts of repeat infringers.

12. SECURITY RESEARCH

If you find a security vulnerability, report it to security@controlmiles.com (see controlmiles.com/.well-known/security.txt) and give us reasonable time to fix it before disclosing it. Do not access, modify, or delete other users' data, do not degrade the service, and test only against your own accounts. We will not pursue legal action against good-faith research that follows these rules.

13. LINKS TO OTHER SITES

ControlMiles may link to websites or services we do not control. Those links are provided for convenience only; we are not responsible for their content, policies, or practices.

14. AVAILABILITY AND CHANGES TO CONTROLMILES

We work to keep ControlMiles available, but it may be interrupted for maintenance, updates, or reasons beyond our control. We may add, change, or remove features, including features marked as new or beta, and may require you to update the app to keep using it.

15. SUSPENSION AND TERMINATION

We may suspend or end your access to ControlMiles, with or without notice, if you violate these Terms of Use, if required by law, or if your use creates risk or possible legal exposure for us, other users, or third parties. Sections 6, 9, 10, 16, and 17 survive termination.

16. EXPORT AND SANCTIONS

You may not use or download ControlMiles if you are located in a country subject to a U.S. government embargo, or if you are on a U.S. government list of prohibited or restricted parties.

17. DISCLAIMERS, LIABILITY, AND DISPUTES

ControlMiles is provided "as is" and "as available." The disclaimer of warranties, limitation of liability, indemnification, dispute resolution and binding arbitration (including the class action waiver and opt-out), and governing law (State of Maryland) sections of the Terms of Service apply to these Terms of Use and to any use of ControlMiles, including by visitors without an account.

18. CHANGES TO THESE TERMS OF USE

We may update these Terms of Use from time to time. We will update the "Last updated" date above and, for material changes, give notice on the website or in the app. Continued use of ControlMiles after a change takes effect constitutes acceptance of the updated Terms of Use.

19. CONTACT US

Questions about these Terms of Use: info@controlmiles.com. Security: security@controlmiles.com. Privacy: privacy@controlmiles.com. Support: support@controlmiles.com.
''';
