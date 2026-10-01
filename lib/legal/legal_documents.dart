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
// Strengthened alongside the individual versions above, same date/reasons.
const String privacyPolicyFleetEn = '''
Last updated: $legalDocumentsLastUpdated
© 2026 ControlMiles. All rights reserved.

1. WHO THIS APPLIES TO

This Fleet Privacy Policy applies to organizations ("Fleet accounts") that use ControlMiles to manage drivers and vehicles, and to the drivers operating under them. ControlMiles is developed by Olympus Mont Systems LLC ("we", "us", "our"). It supplements the general ControlMiles Privacy Policy, (controlmiles.com/privacy), which still applies to everything not covered here (account data, maps, service providers, website cookies, and so on).

2. ROLES: ORGANIZATION AND DRIVER

An organization's owner and administrators create and manage the Fleet account, invite drivers, assign vehicles, set schedules, and can view the data described in Section 3 for drivers under their organization. For this data, the organization decides why and how it is used, and we process it on the organization's behalf to provide the service. Administrators are responsible for how they use that data and for complying with applicable employment, labor, and privacy laws. A driver joining an organization's Fleet account acknowledges that the data they record under that organization becomes visible to its administrators, as described below.

If the organization uses branches (locations), an administrator limited to a branch only sees the drivers, vehicles, and records of that branch; the owner sees all of them.

3. INFORMATION WE COLLECT AND MAKE VISIBLE TO THE ORGANIZATION

Account and roster information: driver name, email, driver ID, role, branch, assigned vehicle, and invitation status.

Live location: while a driver has a trip open under the organization, the driver's current position is shared with the organization's live fleet map, including periodic position updates while the vehicle is stopped, and the vehicle's status (on trip, parked, or no signal). Live sharing stops when the trip ends; the organization can still see the recorded trip, including its route and last reported position.

Trip, route, and mileage data: trip start/end times, mileage, duration, the GPS route of each trip, miles by state or province (used for IFTA and state-mileage reports), and geofence entries and exits if the organization has configured geofences.

Idle time: periods when the engine is presumed running while the vehicle is stationary during a trip, derived from GPS.

Driving behavior: harsh braking, hard acceleration, and speeding events detected from GPS during trips under the organization, the location and time of each event, and a driver safety score calculated from them. To reduce false speeding alerts, the posted speed limit near the event may be looked up in OpenStreetMap (see the general Privacy Policy, Section 4).

Schedules and shifts: assigned shifts, schedules, hourly class blocks (for example in driving schools), and whether each trip started within them.

Vehicles: the organization's vehicles, and -- for owner-operators who use their own vehicle -- the vehicle details the driver registers for business use.

Vehicle inspection (DVIR) records: pre-trip and post-trip inspection results, defects reported, and photos submitted with them.

Odometer photos: photographed at trip start/end, read on the driver's device, and uploaded as evidence supporting the organization's mileage records.

Fuel purchases: date, location, gallons or liters, price, odometer, and receipt photos the driver submits (the receipt can be read on the driver's device), plus automated fuel-anomaly flags (for example a purchase larger than the tank, a duplicate receipt, or consumption out of the vehicle's normal range).

Incident reports and messages: incident reports (category, description, photo), and messages and feedback exchanged between administrators and drivers in the app.

Device and diagnostic information: basic technical information (device type, OS version, app version) and error reports, used for troubleshooting.

4. HOW THIS INFORMATION IS USED

By the organization: to track vehicle usage, mileage, and fuel across its fleet; coordinate shifts and schedules; see where its vehicles are during active trips; prepare IFTA and state-mileage reports; review fuel anomalies, idle time, and driving behavior; verify inspection compliance; respond to incidents; coach drivers; and manage driver and vehicle assignments.

By us: to operate the service (recording, calculating, and reporting the data above; generating the PDF/CSV exports the organization requests; sending the email alerts the organization receives, such as fuel-anomaly digests; storing evidence photos), to maintain the account, respond to support requests, and secure the service against fraud or abuse. We do not sell this information, and we do not use third-party advertising networks.

Automated flags are not decisions: safety scores, driving events, fuel anomalies, and idle time are produced automatically from GPS and submitted data and can be wrong (for example because of GPS errors, tunnels, or missing map data). ControlMiles does not make employment, pay, or disciplinary decisions; any such decision is made by the organization, which should review the underlying facts and give the driver a chance to respond.

5. DATA SHARING

Within the organization: the data in Section 3 is visible to the organization's owner and administrators (and branch administrators for their branch) -- that visibility is the core function of a Fleet account, not an incidental data share.

Service providers and map services: the same providers listed in the general Privacy Policy (Supabase, Vercel, Cloudflare, Resend, Stripe, Google, our own trip-integrity and error-monitoring service, Protomaps, and the OpenStreetMap Overpass API), only to run ControlMiles.

Between organizations: a driver's data is only visible to the organization(s) they are actively assigned to. Removing a driver from an organization ends that organization's visibility into the driver's new trips; records already created under the organization remain part of its records.

Personal trips: trips a driver records in personal (gig) mode are never shared with an organization.

We may also disclose information if required by law or to protect the rights, property, or safety of ControlMiles, the organization, its drivers, or others.

6. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

If drivers label trips with a gig, delivery, or rideshare platform name, ControlMiles is not affiliated with, endorsed by, or sponsored by any of those platforms. It does not access, read, or store any data from those platforms' own apps, accounts, or servers.

7. PEOPLE WITHOUT A CONTROLMILES ACCOUNT

Some organizations record driving by people who do not have their own ControlMiles account -- for example, a student driving with an instructor in a driving school, where the trip and safety score are recorded under the instructor. The organization is responsible for informing those people, obtaining any consent required by law (including a parent's or guardian's consent for a minor), and responding to their requests. We will assist the organization with such requests at privacy@controlmiles.com.

8. DATA RETENTION

We retain an organization's driver, vehicle, trip, route, fuel, inspection, and message data for as long as the Fleet account is active, or until the organization deletes specific records, consistent with applicable law and the organization's own record-keeping obligations (for example IFTA records, which carriers generally must keep for four years). Deleting a Fleet account permanently removes the organization's data, including evidence photos and inspection records, from our active systems; residual copies in encrypted backups are overwritten on the backup rotation schedule.

9. DRIVER CHOICES

A driver can see their own trips, routes, and safety score in the app. A driver can revoke location, physical-activity, camera, or notification permissions at any time from their device settings; doing so will limit or disable tracking for trips under the organization. Requests to access, correct, or delete fleet records should be sent to the organization first, since it controls them; we will help the organization respond, and drivers can also write to privacy@controlmiles.com.

10. PRIVACY RIGHTS (CALIFORNIA AND OTHER U.S. STATES)

If a driver is a California resident, the CCPA, as amended by the CPRA, gives them the right to know what personal information is collected and how it is used, to request deletion or correction, to limit the use of sensitive personal information such as precise location, and not to be discriminated against for exercising these rights, subject to the organization's own record-keeping obligations for business records. Residents of other U.S. states with comparable privacy laws (for example Maryland, Virginia, Colorado, Connecticut, Oregon, Texas, and Utah) have similar rights, honored on the same basis. We do not sell or share personal information for cross-context behavioral advertising. Contact privacy@controlmiles.com to exercise these rights.

11. INTERNATIONAL USERS

If an organization or driver accesses ControlMiles from outside the United States, their information will be transferred to and processed in the United States. Organizations or drivers located in the European Economic Area, United Kingdom, or Switzerland may have additional rights under the GDPR or UK GDPR. Contact privacy@controlmiles.com to exercise these rights.

12. CHILDREN'S PRIVACY

ControlMiles accounts are not available to anyone under the age of 18. See Section 7 for people recorded under an organization who do not have an account.

13. SECURITY

We use industry-standard measures to protect this information, including encrypted connections, organization- and branch-level access controls enforced at the database level, and tamper-evident trip records. No method of storage or transmission is 100% secure, and we cannot guarantee absolute security. Report security issues to security@controlmiles.com.

14. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above and, where appropriate, by notice in the app, on the website, or by email.

15. CONTACT US

Privacy questions and data-rights requests: privacy@controlmiles.com. Support: support@controlmiles.com.
''';

const String termsOfServiceFleetEn = '''
Last updated: $legalDocumentsLastUpdated
© 2026 ControlMiles. All rights reserved.

1. ACCEPTANCE OF TERMS

By creating or joining a Fleet account, or by using ControlMiles as a driver or administrator under one, you agree to these Fleet Terms of Service, the general ControlMiles Terms of Service (controlmiles.com/terms), and the Fleet Privacy Policy (controlmiles.com/privacy/fleet). If these Fleet Terms conflict with the general Terms, these Fleet Terms control for Fleet use. If you accept on behalf of an organization, you confirm you are authorized to bind it.

2. DESCRIPTION OF SERVICE

ControlMiles is a fleet mileage-tracking and compliance tool. It lets an organization manage drivers, vehicles, and branches; coordinate shifts, schedules, and hourly classes; track GPS-based trip mileage and routes; see vehicles on a live map during active trips; collect vehicle inspection (DVIR) records, odometer photos, and fuel purchases; flag fuel anomalies, idle time, and driving-behavior events; calculate driver safety scores; prepare IFTA and state-mileage reports; exchange messages with drivers; and export reports.

Which of these features are available depends on the organization's fleet type and plan.

3. THE ORGANIZATION'S RESPONSIBILITIES

An organization creating a Fleet account is responsible for:
obtaining any notice or consent required by applicable law before tracking a driver's location, driving behavior, or vehicle data -- including state laws that require written notice of electronic monitoring of employees;
informing people who are recorded without their own ControlMiles account (for example driving-school students) and obtaining any consent required, including a parent's or guardian's consent for minors;
accurately assigning and removing drivers, vehicles, branches, and administrator roles, and limiting administrator access to people who need it;
using driver data only for legitimate business purposes related to fleet management, mileage and tax documentation, safety coaching, and vehicle compliance -- not to track drivers outside their work or after their trips end;
reviewing automated flags (safety scores, driving events, fuel anomalies, idle time) before acting on them, and not relying on them as the sole basis for discipline, termination, or pay decisions.

ControlMiles is a tool the organization directs -- Olympus Mont Systems LLC does not decide how an organization uses driver data within its own operations.

4. DRIVERS OPERATING UNDER AN ORGANIZATION

By accepting an invitation to join an organization's Fleet account, a driver acknowledges that the data they record under that organization -- including their live location while a trip is open, trip routes and mileage, inspections, fuel purchases, driving-behavior events, and safety score -- becomes visible to that organization's administrators, as described in the Fleet Privacy Policy. Trips recorded in personal (gig) mode are not shared. A driver should direct questions about how their organization uses this data to that organization.

5. IFTA, TAX, AND COMPLIANCE REPORTS

IFTA, state-mileage, and fuel reports are calculated from GPS data and from the fuel purchases drivers submit, using tax rates published by IFTA, Inc. They are aids for preparing your filings, not filings themselves. GPS gaps, missing receipts, or incorrect entries can make them inaccurate. The organization (the licensed carrier) remains solely responsible for reviewing the figures, keeping the records the law requires, and filing accurate returns. ControlMiles is not affiliated with or endorsed by IFTA, Inc., the IRS, or any tax or transportation authority, and does not provide tax, legal, or regulatory advice. ControlMiles is not an electronic logging device (ELD) and does not record hours of service.

6. SAFETY SCORES AND AUTOMATED FLAGS

Driving events and safety scores are estimates based on phone GPS and, where available, OpenStreetMap speed-limit data, which can be missing or out of date. Fuel anomalies are automated checks that can produce false positives. They are provided for coaching and review, and are not a determination that a driver drove unsafely or committed fraud.

7. ELIGIBILITY AND ACCOUNTS

Anyone with a ControlMiles account, including under a Fleet account, must be at least 18 years old. The organization and each user are responsible for keeping their own credentials confidential and for all activity under their accounts. Notify us promptly of any unauthorized use at security@controlmiles.com.

8. SAFE DRIVING AND MAPS

Drivers must not handle their phone or interact with ControlMiles while the vehicle is moving, and the organization must not require them to. ControlMiles is not a navigation system; maps, positions, routes, and speed information are approximate. Map data © OpenStreetMap contributors (ODbL), packaged by Protomaps. The map terms in the general Terms of Service apply.

9. THIRD-PARTY GIG PLATFORMS -- NO AFFILIATION

If drivers under an organization label trips with the name of a gig, delivery, or rideshare platform, ControlMiles is not affiliated with, endorsed by, or sponsored by any of those platforms, and does not access their apps' data, accounts, or servers.

10. SUBSCRIPTIONS AND BILLING

Fleet plans are billed to the organization, generally per active driver or vehicle as shown at purchase, through Stripe. Plans renew automatically at the end of each billing period at the then-current price until cancelled from the billing page of the organization's account; cancellation takes effect at the end of the current period. Seat changes may be prorated as shown at checkout. Except where required by law, payments are non-refundable. We may change Fleet plan prices or features with reasonable advance notice, effective from the next billing period after the notice.

11. ACCEPTABLE USE

The organization and its users agree not to: use ControlMiles for any unlawful purpose, including surveillance beyond what applicable law permits or tracking anyone without the notice and consent the law requires; attempt to reverse-engineer, decompile, or interfere with the app, the website, or their backend; scrape or bulk-download map data; submit fraudulent mileage, odometer, inspection, fuel, receipt, or incident data, or spoof GPS location; or use the app in a way that infringes the rights of any third party.

12. INTELLECTUAL PROPERTY

ControlMiles, its logo, and its original content are the property of Olympus Mont Systems LLC. Third-party names, logos, and map data referenced in ControlMiles remain the property of their respective owners and are used under their own licenses. The organization keeps ownership of the data it enters into ControlMiles and gives us the rights needed to host and process it to provide the service.

13. DISCLAIMER OF WARRANTIES

ControlMiles is provided "as is" and "as available," without warranties of any kind, express or implied. We do not guarantee that GPS tracking, live location, routes, maps, mileage and IFTA calculations, safety scores, fuel-anomaly detection, alerts, or inspection records will be accurate, complete, timely, error-free, or uninterrupted. The organization is responsible for reviewing fleet data for accuracy before relying on it.

14. LIMITATION OF LIABILITY

To the maximum extent permitted by law, Olympus Mont Systems LLC will not be liable for any indirect, incidental, special, or consequential damages, including lost income, lost tax deductions, tax penalties or interest, accidents, or employment-related disputes between an organization and its drivers, arising from use of ControlMiles. Our total liability for any claim relating to ControlMiles will not exceed the amounts the organization paid us for ControlMiles in the 12 months before the claim.

15. INDEMNIFICATION

The organization agrees to indemnify, defend, and hold harmless Olympus Mont Systems LLC, its officers, employees, and agents from any claims, damages, losses, liabilities, and expenses (including reasonable attorneys' fees) arising out of or related to: the organization's or its users' use of ControlMiles; violation of these Terms; violation of any law, including employment, monitoring, or privacy law, in how the organization collects or uses driver data; claims by drivers, students, or other people recorded under the organization; or any data submitted through the Fleet account that is inaccurate or fraudulent.

16. DISPUTE RESOLUTION; BINDING ARBITRATION; CLASS ACTION WAIVER

Please read this section carefully. It affects your legal rights.

Informal resolution first. Before filing a claim against ControlMiles, the organization or driver agrees to first contact us at info@controlmiles.com and attempt in good faith to resolve the dispute informally for at least 30 days.

Binding arbitration. If a dispute is not resolved informally, the parties agree that it will be resolved by binding, individual arbitration administered by the American Arbitration Association (AAA) under its Commercial Arbitration Rules (for organizations) or Consumer Arbitration Rules (for individual drivers), rather than in court, except that either party may bring an individual claim in small claims court if it qualifies.

Class action waiver. The parties agree that any arbitration or claim will be conducted on an individual or single-organization basis only, not as a class, collective, or representative action, and the arbitrator may not consolidate more than one party's claims.

This section does not apply to, and does not limit, disputes between an organization and its own drivers regarding employment matters -- those remain governed by applicable employment law, not these Terms.

This section survives termination of the Fleet account and these Terms.

17. TERMINATION

An organization may cancel its Fleet account, and a driver may leave an organization, at any time. We may suspend or terminate a Fleet account that violates these Terms. Export any records you must keep (for example for IFTA) before deleting the Fleet account, because deletion is permanent.

18. GOVERNING LAW

These Terms are governed by the laws of the State of Maryland, without regard to its conflict-of-laws principles.

19. SEVERABILITY

If any provision of these Terms is found unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary, and the remaining provisions will remain in full force and effect.

20. ENTIRE AGREEMENT

These Fleet Terms, together with the general Terms of Service and the Fleet Privacy Policy, are the entire agreement between the organization and Olympus Mont Systems LLC regarding ControlMiles, and supersede any prior agreements or understandings, written or oral, regarding that subject matter.

21. ASSIGNMENT

An organization may not assign or transfer these Terms without our prior written consent. We may assign these Terms without restriction, including in connection with a merger, acquisition, or sale of assets.

22. CHANGES TO THESE TERMS

We may update these Terms from time to time. We will update the "Last updated" date above and, for material changes, notify the organization's owner in the app, on the website, or by email, and may ask for acceptance of the updated Terms. Continued use of ControlMiles after the effective date of a change constitutes acceptance of the updated Terms.

23. CONTACT US

Questions about these Terms: info@controlmiles.com. Support: support@controlmiles.com. Privacy: privacy@controlmiles.com. Security: security@controlmiles.com.
''';

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
